-- ============================================================================
-- 27_shuttle_battery_and_wording.sql
--
-- Two defects in migration 26, found while wiring up the shuttle route.
--
-- 1. The battery check disappeared.
--    On the hub route the drone landed, became 'available', and
--    dispatch_next_queued_delivery() refused to send it out again below 15%.
--    The shuttle never makes the drone available between trips, so nothing
--    checked the battery and a nearly flat drone would fly the next trip.
--    The gate is now enforced here, at the point the next trip is authorised.
--
-- 2. The vendor notification asked for a step that does not exist.
--    It said "Confirm the handover when the remaining items are ready", but
--    nothing in the app lets a vendor confirm a pickup -- the simulation calls
--    confirm_package_pickup() itself, for every trip. The notification is now
--    purely informational.
--
-- Only those two things change; the rest is the migration 26 definition.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.arrive_at_vendor_for_next_trip(p_delivery_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order_id        uuid;
    v_drone_id        uuid;
    v_status          text;
    v_trips_required  integer;
    v_trips_completed integer;
    v_order_user_id   uuid;
    v_order_vendor_id uuid;
    v_user_role       text;
    v_drone_state     text;
    v_drone_battery   double precision;
    v_min_battery     constant double precision := 15.0;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT d.order_id,
           d.drone_id,
           d.status,
           coalesce(d.trips_required, 1),
           coalesce(d.trips_completed, 0),
           o.user_id,
           o.vendor_id
    INTO v_order_id,
         v_drone_id,
         v_status,
         v_trips_required,
         v_trips_completed,
         v_order_user_id,
         v_order_vendor_id
    FROM public.deliveries d
    JOIN public.orders o ON o.id = d.order_id
    WHERE d.id = p_delivery_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Delivery not found';
    END IF;

    SELECT role INTO v_user_role FROM public.users WHERE id = auth.uid();
    IF v_user_role <> 'admin'
       AND auth.uid() <> v_order_vendor_id
       AND auth.uid() <> v_order_user_id THEN
        RAISE EXCEPTION 'Unauthorized: caller cannot act on this delivery';
    END IF;

    -- Idempotent: another client may have reported the same landing first.
    IF v_status = 'assigning' THEN
        RETURN json_build_object(
            'success', true,
            'delivery_id', p_delivery_id,
            'order_id', v_order_id,
            'status', 'assigning',
            'trips_completed', v_trips_completed,
            'trips_required', v_trips_required,
            'already_processed', true
        );
    END IF;

    IF v_status <> 'in_transit' THEN
        RAISE EXCEPTION 'Delivery is not between trips (current status: %)', v_status;
    END IF;

    IF v_trips_completed >= v_trips_required THEN
        RAISE EXCEPTION 'Delivery owes no further trips (% of % completed)',
            v_trips_completed, v_trips_required;
    END IF;

    IF v_drone_id IS NULL THEN
        RAISE EXCEPTION 'Delivery has no drone assigned';
    END IF;

    SELECT status, battery_level
    INTO v_drone_state, v_drone_battery
    FROM public.drones
    WHERE id = v_drone_id
    FOR UPDATE;

    IF v_drone_state <> 'returning' THEN
        RAISE EXCEPTION 'Drone is not on a return flight (current status: %)', v_drone_state;
    END IF;

    -- Battery gate (migration 27).
    -- On the old hub route this came free: the drone landed, went 'available',
    -- and dispatch_next_queued_delivery() refused to send it out again under
    -- 15%. The shuttle never makes the drone available, so that check was
    -- silently lost and a nearly flat drone would fly the next trip.
    --
    -- Raising here is deliberate. The caller falls back to
    -- complete_drone_return(), so the drone goes home, becomes available, and
    -- is refused a new dispatch by the same 15% rule -- at which point
    -- resume_stalled_multi_trip_orders() alerts the admins. The order stalls
    -- visibly and at base, rather than invisibly at the vendor.
    IF v_drone_battery IS NOT NULL AND v_drone_battery < v_min_battery THEN
        RAISE EXCEPTION
            'Drone battery too low for the next trip (% percent, minimum % percent)',
            round(v_drone_battery::numeric, 1), v_min_battery;
    END IF;

    -- Park the drone at the vendor, ready for the next pickup.
    UPDATE public.deliveries
    SET status = 'assigning',
        progress = 1.0,
        delivery_started_at = NULL,
        updated_at = now()
    WHERE id = p_delivery_id;

    UPDATE public.drones
    SET status = 'assigned',
        returning_started_at = NULL,
        sim_lease_holder = NULL,
        sim_lease_until = NULL,
        updated_at = now()
    WHERE id = v_drone_id;

    INSERT INTO public.delivery_status_logs (
        delivery_id, status, message, changed_by, created_at
    ) VALUES (
        p_delivery_id,
        'assigning',
        'Drone returned to the vendor for trip ' || (v_trips_completed + 1) ||
        ' of ' || v_trips_required || '. Awaiting package handover.',
        auth.uid(),
        now()
    );

    IF v_order_vendor_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            id, user_id, title, message, notification_type, is_read,
            related_delivery_id, created_at
        ) VALUES (
            gen_random_uuid(),
            v_order_vendor_id,
            'Drone back for the next load',
            'The drone has returned to your shop and is collecting the load for trip ' ||
            (v_trips_completed + 1) || ' of ' || v_trips_required || '.',
            'drone_dispatched',
            false,
            p_delivery_id,
            now()
        );
    END IF;

    RETURN json_build_object(
        'success', true,
        'delivery_id', p_delivery_id,
        'order_id', v_order_id,
        'status', 'assigning',
        'trips_completed', v_trips_completed,
        'trips_required', v_trips_required,
        'next_trip', v_trips_completed + 1
    );
END;
$$;

REVOKE ALL ON FUNCTION public.arrive_at_vendor_for_next_trip(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.arrive_at_vendor_for_next_trip(uuid) TO authenticated;
