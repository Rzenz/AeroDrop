-- ============================================================================
-- 46_real_drone_telemetry.sql
--
-- Telemetry from the real drone, written by the ground-station bridge
-- (python_script/aio.py) while it flies a delivery.
--
-- WHY
-- The app and the website no longer simulate the flight. The only writer of
-- drone_telemetry is now the bridge on the operator's laptop, which reads the
-- flight controller through Mission Planner and signs in as an administrator.
-- record_simulated_telemetry lets the customer and the vendor write too,
-- because any of their devices used to run the simulator. The real drone has
-- one writer, so this function is admin-only.
--
-- WHAT IT DOES
-- Same row as record_simulated_telemetry, plus the heading, and it keeps the
-- drone's battery level current. Progress is only stored while the delivery is
-- active, so the return leg never overwrites the delivery's 100%.
--
-- The status changes are the existing RPCs, called by the bridge in order:
--   confirm_package_pickup   after takeoff        assigning  -> in_transit
--   complete_delivery_order  after the drop        in_transit -> delivered,
--                                                  drone -> returning
--   complete_drone_return    after landing at base drone -> available
-- All three already accept an administrator.
--
-- record_simulated_telemetry and claim_drone_sim_lease are left in place, so
-- an older app build still installed on a phone fails softly rather than
-- with "function does not exist".
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-45:
--   public.drone_telemetry (01, heading added by 06)
--   public.is_admin()      (10)
-- ============================================================================

ALTER TABLE public.drone_telemetry
    ADD COLUMN IF NOT EXISTS heading double precision;

CREATE OR REPLACE FUNCTION public.record_drone_telemetry(
    p_delivery_id     uuid,
    p_latitude        double precision,
    p_longitude       double precision,
    p_altitude        double precision,
    p_speed           double precision,
    p_battery_level   double precision,
    p_signal_strength double precision,
    p_heading         double precision DEFAULT 0.0,
    p_event_type      text DEFAULT 'in_flight',
    p_progress        double precision DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_drone_id uuid;
    v_status   text;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: only the ground station (an administrator) records drone telemetry';
    END IF;
    IF p_latitude IS NULL OR p_longitude IS NULL THEN
        RAISE EXCEPTION 'Latitude and longitude are required';
    END IF;

    SELECT d.drone_id, d.status INTO v_drone_id, v_status
    FROM public.deliveries d
    WHERE d.id = p_delivery_id;

    IF v_drone_id IS NULL THEN
        RAISE EXCEPTION 'Delivery does not exist or has no drone assigned';
    END IF;

    -- The return leg is flown after the delivery is delivered (or cancelled
    -- in the air), so it is the one event allowed past the active states.
    IF p_event_type = 'returning_to_base' THEN
        IF v_status NOT IN ('assigning', 'in_transit', 'delivered', 'cancelled') THEN
            RAISE EXCEPTION 'Delivery state invalid for return telemetry (status: %)', v_status;
        END IF;
    ELSIF v_status NOT IN ('assigning', 'in_transit') THEN
        RAISE EXCEPTION 'Delivery is not currently active (status: %)', v_status;
    END IF;

    INSERT INTO public.drone_telemetry (
        id, drone_id, delivery_id, latitude, longitude, altitude, speed,
        battery_level, signal_strength, heading, event_type, recorded_at
    ) VALUES (
        gen_random_uuid(), v_drone_id, p_delivery_id, p_latitude, p_longitude,
        p_altitude, p_speed, p_battery_level, p_signal_strength,
        coalesce(p_heading, 0.0), coalesce(p_event_type, 'in_flight'), now()
    );

    IF p_battery_level IS NOT NULL THEN
        UPDATE public.drones
        SET battery_level = p_battery_level, updated_at = now()
        WHERE id = v_drone_id;
    END IF;

    IF p_progress IS NOT NULL AND v_status IN ('assigning', 'in_transit') THEN
        UPDATE public.deliveries
        SET progress = least(greatest(p_progress, 0.0), 1.0), updated_at = now()
        WHERE id = p_delivery_id;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.record_drone_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, double precision, double precision, text, double precision) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.record_drone_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, double precision, double precision, text, double precision) TO authenticated;
