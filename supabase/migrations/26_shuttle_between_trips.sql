-- ============================================================================
-- 26_shuttle_between_trips.sql
--
-- Changes the multi-trip flight path from
--     Hub -> Vendor -> Customer -> Hub,  Hub -> Vendor -> Customer -> Hub
-- to
--     Hub -> Vendor -> Customer -> Vendor -> Customer -> Hub
--
-- Migration 23 reused the existing cycle for every trip, which sent the drone
-- all the way home between trips. It works, but flying past the vendor to the
-- hub and straight back out again is not what a real operator would do.
--
-- WHAT CHANGES
-- Nothing about how a trip completes: complete_delivery_order() still sets the
-- drone to 'returning' after a non-final trip, because the empty leg back to
-- the vendor is still a return flight. What changes is where it is returning
-- TO, and that decision belongs to the client's flight simulation, which
-- already knows whether trips remain.
--
-- This migration adds the arrival half: a drone that lands at the vendor
-- between trips is parked ready for the next pickup, rather than being marked
-- available at the hub.
--
--   status   = 'assigning'   the phase the vendor confirms pickup from
--   progress = 1.0           leg 1 (hub -> vendor) is already behind us; the
--                            drone is AT the vendor, so the simulation draws
--                            it parked instead of flying the approach again
--
-- confirm_package_pickup() then runs unchanged: it requires 'assigning', and
-- resets progress to 0 for the loaded leg.
--
-- THE SAFETY NETS STILL APPLY
-- dispatch_next_queued_delivery() (migration 23) and
-- resume_stalled_multi_trip_orders() (24, 25) both look for a drone sitting
-- 'available' with trips owed. The shuttle never leaves the drone available
-- between trips, so they do not fire on the happy path -- but if a shuttle
-- flight is abandoned mid-air (the app is closed, say),
-- recover_stale_returning_drone() still frees the drone, and those two then
-- resume the order by the old hub route. Degraded, but never stuck.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-25.
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

    SELECT status INTO v_drone_state
    FROM public.drones
    WHERE id = v_drone_id
    FOR UPDATE;

    IF v_drone_state <> 'returning' THEN
        RAISE EXCEPTION 'Drone is not on a return flight (current status: %)', v_drone_state;
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
            'The drone has returned to your shop for trip ' ||
            (v_trips_completed + 1) || ' of ' || v_trips_required ||
            '. Confirm the handover when the remaining items are ready.',
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
