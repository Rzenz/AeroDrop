-- ============================================================================
-- 38_order_flight_plan.sql
--
-- Gives the drone side one call that returns everything needed to fly an
-- order, instead of asking it to join four tables itself.
--
-- WHY THIS IS NEEDED
-- An order does not carry coordinates. It carries delivery_location_id, a
-- pointer into campus_locations, and the vendor's end comes from
-- deliveries.pickup_location_id (set when the vendor marks the order ready)
-- or, before that, from the vendor's own campus_location_id. Resolving that
-- is the app's job, not the drone team's.
--
-- ALTITUDE
-- AeroDrop has never stored one. This migration adds drones.cruise_altitude_m
-- so it is a real, configurable field rather than a number invented by
-- whoever exports the data. The DEFAULT of 20 metres is a placeholder: the
-- drone team must set the real value before any flight.
--
--   UPDATE public.drones SET cruise_altitude_m = <their number> WHERE drone_code = 'DRN-001';
--
-- WHAT THIS DOES NOT DO
-- It does not clear a flight. There is no obstacle data, the no_fly_zones
-- table is empty, and the coordinates are map estimates rather than surveyed
-- points. This returns what the system knows; judgement stays with the pilot.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-37.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. A cruise altitude that lives somewhere, instead of nowhere
-- ----------------------------------------------------------------------------
ALTER TABLE public.drones
    ADD COLUMN IF NOT EXISTS cruise_altitude_m numeric NOT NULL DEFAULT 20;

COMMENT ON COLUMN public.drones.cruise_altitude_m IS
    'Cruise altitude in metres above ground for this aircraft. The default of '
    '20 is a placeholder, not an engineering decision. Set it from the drone '
    'team''s figure before any real flight.';

-- ----------------------------------------------------------------------------
-- 2. The flight plan
--
-- Returns jsonb. Readable by an administrator, the order's vendor, or the
-- customer who placed it.
--
-- The role check uses IS DISTINCT FROM rather than <>, because a caller with
-- no public.users row yields NULL from the role lookup, and `NULL <> 'admin'`
-- is NULL -- which an IF treats as false, letting the caller through. That
-- pattern exists in older functions here and is not repeated.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_order_flight_plan(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_role  text;
    v_order      record;
    v_hub        record;
    v_pickup     record;
    v_dropoff    record;
    v_alt        numeric;
    v_grams      integer;
    v_items      jsonb;
    v_trips      integer;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT o.id, o.user_id, o.vendor_id, o.order_status, o.payment_status,
           o.created_at, o.delivery_location_id,
           v.full_name        AS vendor_name,
           v.campus_location_id AS vendor_location_id,
           c.full_name        AS customer_name,
           d.id               AS delivery_id,
           d.status           AS delivery_status,
           d.drone_id,
           d.progress,
           coalesce(d.trips_required, 1)  AS trips_required,
           coalesce(d.trips_completed, 0) AS trips_completed,
           d.pickup_location_id,
           d.dropoff_location_id
    INTO v_order
    FROM public.orders o
    LEFT JOIN public.users      v ON v.id = o.vendor_id
    LEFT JOIN public.users      c ON c.id = o.user_id
    LEFT JOIN public.deliveries d ON d.order_id = o.id
    WHERE o.id = p_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    SELECT role INTO v_user_role FROM public.users WHERE id = auth.uid();

    IF v_user_role IS DISTINCT FROM 'admin'
       AND auth.uid() IS DISTINCT FROM v_order.vendor_id
       AND auth.uid() IS DISTINCT FROM v_order.user_id THEN
        RAISE EXCEPTION 'Unauthorized: caller cannot read this order';
    END IF;

    SELECT * INTO v_hub
    FROM public.campus_locations WHERE location_code = 'BASE-HUB';

    SELECT * INTO v_pickup
    FROM public.campus_locations
    WHERE id = coalesce(v_order.pickup_location_id, v_order.vendor_location_id);

    SELECT * INTO v_dropoff
    FROM public.campus_locations
    WHERE id = coalesce(v_order.dropoff_location_id, v_order.delivery_location_id);

    SELECT coalesce(cruise_altitude_m, 20) INTO v_alt
    FROM public.drones
    WHERE id = v_order.drone_id;

    IF v_alt IS NULL THEN
        SELECT coalesce(min(cruise_altitude_m), 20) INTO v_alt FROM public.drones;
    END IF;

    SELECT sum(oi.weight_grams * oi.quantity),
           jsonb_agg(jsonb_build_object(
               'product_name', oi.product_name,
               'quantity',     oi.quantity,
               'weight_grams', oi.weight_grams
           ) ORDER BY oi.product_name)
    INTO v_grams, v_items
    FROM public.order_items oi
    WHERE oi.order_id = p_order_id;

    v_trips := v_order.trips_required;

    RETURN jsonb_build_object(
        'order_id',       v_order.id,
        'order_status',   v_order.order_status,
        'payment_status', v_order.payment_status,
        'placed_at',      v_order.created_at,

        'vendor', jsonb_build_object(
            'name',          v_order.vendor_name,
            'location_code', v_pickup.location_code,
            'building',      v_pickup.name
        ),
        'customer', jsonb_build_object(
            'name',          v_order.customer_name,
            'location_code', v_dropoff.location_code,
            'building',      v_dropoff.name
        ),

        'payload', jsonb_build_object(
            'total_weight_grams', coalesce(v_grams, 0),
            'total_weight_kg',    round(coalesce(v_grams, 0) / 1000.0, 3),
            'max_payload_kg',     0.5,
            'trips_required',     v_trips,
            'items',              coalesce(v_items, '[]'::jsonb)
        ),

        'altitude_m_agl', v_alt,

        'waypoints', CASE
            WHEN v_trips > 1 THEN jsonb_build_array(
                jsonb_build_object('seq', 1, 'role', 'launch',    'location_code', v_hub.location_code,     'name', v_hub.name,     'latitude', v_hub.latitude,     'longitude', v_hub.longitude,     'altitude_m_agl', 0),
                jsonb_build_object('seq', 2, 'role', 'pickup',    'location_code', v_pickup.location_code,  'name', v_pickup.name,  'latitude', v_pickup.latitude,  'longitude', v_pickup.longitude,  'altitude_m_agl', v_alt),
                jsonb_build_object('seq', 3, 'role', 'dropoff',   'location_code', v_dropoff.location_code, 'name', v_dropoff.name, 'latitude', v_dropoff.latitude, 'longitude', v_dropoff.longitude, 'altitude_m_agl', v_alt),
                jsonb_build_object('seq', 4, 'role', 'pickup_2',  'location_code', v_pickup.location_code,  'name', v_pickup.name,  'latitude', v_pickup.latitude,  'longitude', v_pickup.longitude,  'altitude_m_agl', v_alt),
                jsonb_build_object('seq', 5, 'role', 'dropoff_2', 'location_code', v_dropoff.location_code, 'name', v_dropoff.name, 'latitude', v_dropoff.latitude, 'longitude', v_dropoff.longitude, 'altitude_m_agl', v_alt),
                jsonb_build_object('seq', 6, 'role', 'return',    'location_code', v_hub.location_code,     'name', v_hub.name,     'latitude', v_hub.latitude,     'longitude', v_hub.longitude,     'altitude_m_agl', 0)
            )
            ELSE jsonb_build_array(
                jsonb_build_object('seq', 1, 'role', 'launch',  'location_code', v_hub.location_code,     'name', v_hub.name,     'latitude', v_hub.latitude,     'longitude', v_hub.longitude,     'altitude_m_agl', 0),
                jsonb_build_object('seq', 2, 'role', 'pickup',  'location_code', v_pickup.location_code,  'name', v_pickup.name,  'latitude', v_pickup.latitude,  'longitude', v_pickup.longitude,  'altitude_m_agl', v_alt),
                jsonb_build_object('seq', 3, 'role', 'dropoff', 'location_code', v_dropoff.location_code, 'name', v_dropoff.name, 'latitude', v_dropoff.latitude, 'longitude', v_dropoff.longitude, 'altitude_m_agl', v_alt),
                jsonb_build_object('seq', 4, 'role', 'return',  'location_code', v_hub.location_code,     'name', v_hub.name,     'latitude', v_hub.latitude,     'longitude', v_hub.longitude,     'altitude_m_agl', 0)
            )
        END,

        'distance_km', jsonb_build_object(
            'hub_to_pickup',     public.campus_distance_km(v_hub.id,     v_pickup.id),
            'pickup_to_dropoff', public.campus_distance_km(v_pickup.id,  v_dropoff.id),
            'dropoff_to_hub',    public.campus_distance_km(v_dropoff.id, v_hub.id)
        ),

        'delivery', jsonb_build_object(
            'delivery_id',     v_order.delivery_id,
            'status',          v_order.delivery_status,
            'drone_id',        v_order.drone_id,
            'trips_completed', v_order.trips_completed,
            'progress',        v_order.progress
        ),

        '_notes', jsonb_build_array(
            'Coordinates are map estimates, not surveyed points. Not accurate enough to land on.',
            'altitude_m_agl comes from drones.cruise_altitude_m, whose default of 20 is a placeholder.',
            'No obstacle data exists and public.no_fly_zones is empty. Nothing here clears a flight.',
            'pickup and dropoff fall back to the vendor and order locations until the vendor marks the order ready.'
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_order_flight_plan(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_order_flight_plan(uuid) TO authenticated;
