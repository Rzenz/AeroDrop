-- ============================================================================
-- 24_multi_trip_safeguards.sql
--
-- Two defects in migration 23, found while building the Flutter side.
--
-- 1. complete_delivery_order() stopped being safe to call twice.
--    Before multi-trip it was idempotent: a second call hit the
--    "IF v_status = 'delivered'" early-return. Between trips the delivery
--    deliberately stays 'in_transit', so that guard never fires. The row is
--    locked FOR UPDATE, which serialises concurrent callers rather than
--    rejecting them, so the second caller reads the already-incremented
--    trips_completed, concludes no trips remain, and completes the FINAL trip
--    without the drone flying it. Two devices watching the same landing --
--    the customer's app and the vendor's -- is enough to trigger it.
--
--    Fixed below with a drone-status guard: the drone is 'assigned' while
--    carrying a load and 'returning' the instant a trip completes, so a
--    duplicate call is recognised and returns already_processed.
--
-- 2. A part-flown order could stall forever.
--    dispatch_next_queued_delivery() refuses to dispatch when the weather is
--    grounded or the battery is under 15%. If either is true at the moment
--    the drone lands between trips, the order is left half-delivered and
--    nothing ever retries. Fixed with a scheduled sweep that re-attempts the
--    dispatch once a minute, and tells the admins if an order stays stuck.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-23. The function below is its
-- migration 23 definition with only the idempotency guard added.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. complete_delivery_order - reject duplicate trip completions
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_delivery_order(p_delivery_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order_id uuid;
    v_drone_id uuid;
    v_status text;
    v_order_user_id uuid;
    v_order_vendor_id uuid;
    v_user_role text;
    v_trips_required integer := 1;
    v_trips_completed integer := 0;
    v_drone_state text;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT
        d.order_id,
        d.drone_id,
        d.status,
        o.user_id,
        o.vendor_id
    INTO
        v_order_id,
        v_drone_id,
        v_status,
        v_order_user_id,
        v_order_vendor_id
    FROM public.deliveries d
    JOIN public.orders o ON d.order_id = o.id
    WHERE d.id = p_delivery_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Delivery not found';
    END IF;

    SELECT role INTO v_user_role FROM public.users WHERE id = auth.uid();
    IF v_user_role != 'admin' AND auth.uid() != v_order_vendor_id AND auth.uid() != v_order_user_id THEN
        RAISE EXCEPTION 'Unauthorized: Caller cannot complete this delivery';
    END IF;

    IF v_status = 'delivered' THEN
        -- Defensive update: ensure progress is 1.0 even if already marked delivered
        UPDATE public.deliveries
        SET progress = 1.0, updated_at = now()
        WHERE id = p_delivery_id AND (progress IS NULL OR progress < 1.0);

        RETURN json_build_object(
            'success', true,
            'delivery_id', p_delivery_id,
            'status', 'delivered',
            'already_processed', true
        );
    END IF;

    -- ------------------------------------------------------------------
    -- MULTI-TRIP: an order heavier than one drone load arrives in stages.
    -- This arrival finishes the CURRENT trip; only the last one finishes the
    -- order. The delivery deliberately stays 'in_transit' between trips, so
    -- every existing query that treats the order as active (weather
    -- grounding, drone self-healing, the admin radar) keeps working unchanged.
    -- ------------------------------------------------------------------
    SELECT coalesce(trips_required, 1), coalesce(trips_completed, 0)
    INTO v_trips_required, v_trips_completed
    FROM public.deliveries
    WHERE id = p_delivery_id;

    -- ------------------------------------------------------------------
    -- IDEMPOTENCY GUARD (migration 24)
    -- Between trips the delivery stays 'in_transit', so the 'delivered'
    -- early-return above cannot catch a duplicate call. Two clients watching
    -- the same flight (the customer's app and the vendor's, say) can both
    -- report trip 1 landing. The row lock serialises them, so the second call
    -- would read the already-incremented count, decide no trips remain, and
    -- complete the final trip without the drone ever flying it.
    --
    -- The drone's own status is the discriminator: it is 'assigned' while
    -- carrying a load and 'returning' the instant a trip completes.
    -- ------------------------------------------------------------------
    IF v_drone_id IS NOT NULL THEN
        SELECT status INTO v_drone_state
        FROM public.drones
        WHERE id = v_drone_id;

        IF v_drone_state = 'returning' THEN
            RETURN json_build_object(
                'success', true,
                'delivery_id', p_delivery_id,
                'order_id', v_order_id,
                'status', 'in_transit',
                'trips_completed', v_trips_completed,
                'trips_required', v_trips_required,
                'more_trips', v_trips_completed < v_trips_required,
                'already_processed', true
            );
        END IF;
    END IF;

    v_trips_completed := v_trips_completed + 1;

    IF v_trips_completed < v_trips_required THEN
        UPDATE public.deliveries
        SET trips_completed = v_trips_completed,
            progress = 0,
            updated_at = now()
        WHERE id = p_delivery_id;

        -- handle_delivery_drone_release() only fires on terminal statuses, so
        -- the drone is sent home explicitly here.
        IF v_drone_id IS NOT NULL THEN
            UPDATE public.drones
            SET status = 'returning',
                returning_started_at = now(),
                sim_lease_holder = NULL,
                sim_lease_until = NULL,
                updated_at = now()
            WHERE id = v_drone_id;
        END IF;

        INSERT INTO public.delivery_status_logs (
            delivery_id, status, message, changed_by, created_at
        ) VALUES (
            p_delivery_id,
            'in_transit',
            'Trip ' || v_trips_completed || ' of ' || v_trips_required ||
            ' delivered. Drone returning to base to collect the remaining items.',
            auth.uid(),
            now()
        );

        IF v_order_user_id IS NOT NULL THEN
            INSERT INTO public.notifications (
                id, user_id, title, message, notification_type, is_read,
                related_delivery_id, created_at
            ) VALUES (
                gen_random_uuid(),
                v_order_user_id,
                'Part ' || v_trips_completed || ' of ' || v_trips_required || ' delivered',
                'Your order needs ' || v_trips_required ||
                ' drone trips. Part ' || v_trips_completed ||
                ' has arrived; the drone is returning to base to collect the rest.',
                'delivery_trip_completed',
                false,
                p_delivery_id,
                now()
            );
        END IF;

        RETURN json_build_object(
            'success', true,
            'delivery_id', p_delivery_id,
            'order_id', v_order_id,
            'status', 'in_transit',
            'trips_completed', v_trips_completed,
            'trips_required', v_trips_required,
            'more_trips', true
        );
    END IF;

    -- Final trip: record it, then complete the order normally.
    UPDATE public.deliveries
    SET trips_completed = v_trips_completed, updated_at = now()
    WHERE id = p_delivery_id;

    -- Update delivery to delivered with exact progress 1.0
    UPDATE public.deliveries
    SET
        status = 'delivered',
        delivery_completed_at = now(),
        progress = 1.0,
        updated_at = now()
    WHERE id = p_delivery_id;

    -- Update order to delivered
    UPDATE public.orders
    SET
        order_status = 'delivered',
        updated_at = now()
    WHERE id = v_order_id;

    -- Log transition
    INSERT INTO public.delivery_status_logs (
        delivery_id,
        status,
        message,
        changed_by,
        created_at
    ) VALUES (
        p_delivery_id,
        'delivered',
        'Order delivered safely at dropoff point.',
        auth.uid(),
        now()
    );

    RETURN json_build_object(
        'success', true,
        'delivery_id', p_delivery_id,
        'order_id', v_order_id,
        'status', 'delivered'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.complete_delivery_order(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_delivery_order(uuid) TO authenticated;


-- ----------------------------------------------------------------------------
-- 2. Scheduled resume for stalled multi-trip orders
--
-- dispatch_next_queued_delivery() already does the weather, battery and
-- priority checks, and already prefers a part-flown order over the queue, so
-- this only has to find the stalled ones and poke it.
--
-- A delivery qualifies when it still owes trips, its drone is sitting
-- 'available' (it got home and was never sent back out), and it has been that
-- way for at least a minute -- long enough that the normal path has had its
-- chance.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.resume_stalled_multi_trip_orders()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_row     RECORD;
    v_resumed integer := 0;
BEGIN
    FOR v_row IN
        SELECT d.id AS delivery_id,
               d.order_id,
               d.drone_id,
               d.updated_at,
               coalesce(d.trips_completed, 0) AS trips_done,
               coalesce(d.trips_required, 1)  AS trips_total
        FROM public.deliveries d
        JOIN public.drones dr ON dr.id = d.drone_id
        WHERE d.status = 'in_transit'
          AND coalesce(d.trips_completed, 0) < coalesce(d.trips_required, 1)
          AND dr.status = 'available'
          AND d.updated_at < now() - interval '1 minute'
    LOOP
        IF public.dispatch_next_queued_delivery(v_row.drone_id) THEN
            v_resumed := v_resumed + 1;
        ELSE
            -- Still blocked (grounded weather, or a flat battery). Tell the
            -- admins once per stalled delivery rather than every minute.
            IF v_row.updated_at < now() - interval '15 minutes'
               AND NOT EXISTS (
                   SELECT 1
                   FROM public.notifications n
                   JOIN public.users u ON u.id = n.user_id AND u.role = 'admin'
                   WHERE n.notification_type = 'multi_trip_stalled'
                     AND n.is_read = false
                     AND n.metadata->>'delivery_id' = v_row.delivery_id::text
               )
            THEN
                PERFORM public.notify_all_admins(
                    'Multi-trip order stalled',
                    'Order #' || substring(v_row.order_id::text, 1, 8) ||
                    ' has completed ' || v_row.trips_done || ' of ' ||
                    v_row.trips_total || ' drone trips and cannot continue. ' ||
                    'Check the weather status and the drone battery.',
                    'multi_trip_stalled',
                    v_row.delivery_id,
                    jsonb_build_object(
                        'delivery_id',     v_row.delivery_id,
                        'order_id',        v_row.order_id,
                        'trips_completed', v_row.trips_done,
                        'trips_required',  v_row.trips_total
                    )
                );
            END IF;
        END IF;
    END LOOP;

    RETURN v_resumed;
END;
$$;

REVOKE ALL ON FUNCTION public.resume_stalled_multi_trip_orders() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.resume_stalled_multi_trip_orders() TO postgres, service_role;

-- ----------------------------------------------------------------------------
-- 3. Schedule it (same pattern as sync-campus-weather in migration 15)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'resume-multi-trip-orders') THEN
        PERFORM cron.unschedule('resume-multi-trip-orders');
    END IF;
END $$;

SELECT cron.schedule(
    'resume-multi-trip-orders',
    '* * * * *',
    $$SELECT public.resume_stalled_multi_trip_orders();$$
);
