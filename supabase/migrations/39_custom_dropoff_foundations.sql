-- ============================================================================
-- 39_custom_dropoff_foundations.sql
--
-- Part 1 of 2 for customer-chosen drop-off points.
--
-- Today a delivery address is always one of five rows in campus_locations,
-- referenced by id. This adds the option of a free-form point: the customer
-- drops a pin, and the order carries raw coordinates instead of a location id.
-- The five fixed points are untouched and remain the default.
--
-- THIS MIGRATION adds the parts nothing depends on yet: the zone that bounds
-- where a pin may go, the columns that hold a pin, the distance helpers, and
-- the two pricing functions. After it, a client can ASK what a custom point
-- would cost. It cannot yet place such an order.
--
-- MIGRATION 40 does the write path: place_order, vendor_mark_order_ready and
-- get_order_flight_plan. It is separate so this half can be verified first.
--
-- NOTHING EXISTING CHANGES BEHAVIOUR. compute_order_pricing gains two
-- parameters that default to NULL, and with them NULL it computes exactly
-- what it computes today. place_order calls it with three arguments and keeps
-- working untouched. The website is unaffected.
--
-- WHY THE FUNCTIONS ARE DROPPED AND RECREATED RATHER THAN REPLACED
-- CREATE OR REPLACE cannot add a parameter; it would create a second,
-- overloaded function. PostgREST resolves RPC calls by argument name, and with
-- defaults in play a three-argument call would match both -- an ambiguity
-- error on a path the website uses. One function must exist, so the old one
-- goes first.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-38.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. The delivery zone
--
-- A circle around the drone hub. A pin outside it is refused. Stored rather
-- than hardcoded so it can be widened or narrowed without an app release.
--
-- 300 m is a starting value, not a survey: the five known buildings sit within
-- 228 m of the hub, so 300 covers them with a margin. Change it once someone
-- has walked the campus boundary.
--
-- Single row, enforced by the primary key being a boolean that must be true.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.delivery_zone (
    id                   boolean PRIMARY KEY DEFAULT true CHECK (id),
    center_location_code text    NOT NULL DEFAULT 'BASE-HUB',
    radius_meters        numeric NOT NULL DEFAULT 300
                         CHECK (radius_meters > 0 AND radius_meters <= 2000),
    updated_at           timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.delivery_zone (id) VALUES (true) ON CONFLICT (id) DO NOTHING;

COMMENT ON TABLE public.delivery_zone IS
    'Single row. Bounds where a customer may drop a custom delivery pin. '
    'radius_meters is measured from the campus location whose code is '
    'center_location_code. The default 300 is a placeholder, not a surveyed '
    'campus boundary.';

ALTER TABLE public.delivery_zone ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS delivery_zone_select ON public.delivery_zone;
CREATE POLICY delivery_zone_select ON public.delivery_zone
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS delivery_zone_update ON public.delivery_zone;
CREATE POLICY delivery_zone_update ON public.delivery_zone
    FOR UPDATE TO authenticated
    USING (public.is_admin()) WITH CHECK (public.is_admin());

GRANT SELECT, UPDATE ON public.delivery_zone TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. Where a pin is stored
--
-- On the order, because that is where the customer's choice belongs, and on
-- the delivery, because the app's flight simulation reads the delivery and
-- would otherwise have to join back to the order on every tick.
--
-- The label is what the customer typed to describe the spot -- "by the side
-- gate", "2nd floor balcony". It is for the vendor and the pilot to read; the
-- system never parses it.
-- ----------------------------------------------------------------------------
ALTER TABLE public.orders
    ADD COLUMN IF NOT EXISTS custom_dropoff_lat   numeric,
    ADD COLUMN IF NOT EXISTS custom_dropoff_lng   numeric,
    ADD COLUMN IF NOT EXISTS custom_dropoff_label text;

ALTER TABLE public.deliveries
    ADD COLUMN IF NOT EXISTS custom_dropoff_lat numeric,
    ADD COLUMN IF NOT EXISTS custom_dropoff_lng numeric;

-- Latitude and longitude arrive together or not at all. Existing rows have
-- both NULL, so this validates immediately.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'orders_custom_dropoff_pair') THEN
        ALTER TABLE public.orders ADD CONSTRAINT orders_custom_dropoff_pair
            CHECK ((custom_dropoff_lat IS NULL) = (custom_dropoff_lng IS NULL));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'deliveries_custom_dropoff_pair') THEN
        ALTER TABLE public.deliveries ADD CONSTRAINT deliveries_custom_dropoff_pair
            CHECK ((custom_dropoff_lat IS NULL) = (custom_dropoff_lng IS NULL));
    END IF;
END;
$$;

COMMENT ON COLUMN public.orders.custom_dropoff_lat IS
    'Set only when the customer chose their own drop-off point. NULL means the '
    'order goes to delivery_location_id, one of the fixed campus locations.';

-- ----------------------------------------------------------------------------
-- 3. Distance to a loose point
--
-- campus_distance_km takes two location ids. A pin has no id, so these two
-- mirror it exactly: same 6371 km radius, same 5 m floor, so a fixed point and
-- a pin in the same spot are priced identically.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.point_distance_km(
    a_lat double precision, a_lng double precision,
    b_lat double precision, b_lng double precision
)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    d_lat double precision;
    d_lng double precision;
    h     double precision;
    km    numeric;
BEGIN
    IF a_lat IS NULL OR a_lng IS NULL OR b_lat IS NULL OR b_lng IS NULL THEN
        RETURN 0;
    END IF;

    d_lat := radians(b_lat - a_lat);
    d_lng := radians(b_lng - a_lng);

    h := sin(d_lat / 2) ^ 2
       + cos(radians(a_lat)) * cos(radians(b_lat)) * sin(d_lng / 2) ^ 2;

    km := (6371.0 * 2 * asin(sqrt(h)))::numeric;

    -- Under 5 m counts as the same place, as campus_distance_km does.
    IF km < 0.005 THEN
        RETURN 0;
    END IF;

    RETURN km;
END;
$$;

CREATE OR REPLACE FUNCTION public.campus_to_point_distance_km(
    p_location_id uuid,
    p_lat double precision,
    p_lng double precision
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    a_lat double precision;
    a_lng double precision;
BEGIN
    IF p_location_id IS NULL OR p_lat IS NULL OR p_lng IS NULL THEN
        RETURN 0;
    END IF;

    SELECT latitude, longitude INTO a_lat, a_lng
    FROM public.campus_locations WHERE id = p_location_id;

    RETURN public.point_distance_km(a_lat, a_lng, p_lat, p_lng);
END;
$$;

-- ----------------------------------------------------------------------------
-- 4. Is the pin on campus
--
-- Used by migration 40 to refuse an order, and callable by the app so the map
-- can show the circle and grey out the button before the customer commits.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_within_delivery_zone(
    p_lat double precision,
    p_lng double precision
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_code   text;
    v_radius numeric;
    v_lat    double precision;
    v_lng    double precision;
BEGIN
    IF p_lat IS NULL OR p_lng IS NULL THEN
        RETURN false;
    END IF;

    SELECT center_location_code, radius_meters
    INTO v_code, v_radius
    FROM public.delivery_zone WHERE id;

    IF v_code IS NULL THEN
        RETURN false;   -- no zone configured: refuse rather than allow
    END IF;

    SELECT latitude, longitude INTO v_lat, v_lng
    FROM public.campus_locations WHERE location_code = v_code;

    IF v_lat IS NULL THEN
        RETURN false;   -- centre missing: refuse rather than allow
    END IF;

    RETURN (public.point_distance_km(v_lat, v_lng, p_lat, p_lng) * 1000) <= v_radius;
END;
$$;

CREATE OR REPLACE FUNCTION public.delivery_zone_info()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v jsonb;
BEGIN
    SELECT jsonb_build_object(
        'center_location_code', z.center_location_code,
        'center_name',          l.name,
        'center_latitude',      l.latitude,
        'center_longitude',     l.longitude,
        'radius_meters',        z.radius_meters
    )
    INTO v
    FROM public.delivery_zone z
    LEFT JOIN public.campus_locations l ON l.location_code = z.center_location_code
    WHERE z.id;

    RETURN coalesce(v, '{}'::jsonb);
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. Pricing a pin
--
-- compute_order_pricing is patched in place rather than restated, so this file
-- cannot drift from migration 31. Two changes:
--   - two new parameters, defaulting to NULL
--   - when they are given, distance is measured to the pin instead of to
--     delivery_location_id
--
-- Everything else -- the base fee, the per-km rate, the weight charge, the
-- trip count, the caution surcharge -- is untouched, so a pin is priced by the
-- same formula as a building, which is what was asked for.
--
-- If the anchors below do not match, this migration FAILS rather than
-- half-patching.
-- ----------------------------------------------------------------------------
DO $migration$
DECLARE
    v_def       text;
    v_sig_old   text := '(p_vendor_id uuid, p_delivery_location_id uuid, p_items jsonb)';
    v_sig_new   text := '(p_vendor_id uuid, p_delivery_location_id uuid, p_items jsonb, p_dropoff_lat numeric DEFAULT NULL::numeric, p_dropoff_lng numeric DEFAULT NULL::numeric)';
    v_dist_old  text := 'v_distance_km := public.campus_distance_km(v_vendor_loc, p_delivery_location_id);';
    v_dist_new  text := 'IF p_dropoff_lat IS NOT NULL AND p_dropoff_lng IS NOT NULL THEN'
                     || E'\n        v_distance_km := public.campus_to_point_distance_km(v_vendor_loc, p_dropoff_lat, p_dropoff_lng);'
                     || E'\n    ELSE'
                     || E'\n        v_distance_km := public.campus_distance_km(v_vendor_loc, p_delivery_location_id);'
                     || E'\n    END IF;';
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'compute_order_pricing'
      AND pg_get_function_identity_arguments(p.oid) =
          'p_vendor_id uuid, p_delivery_location_id uuid, p_items jsonb';

    IF v_def IS NULL THEN
        RAISE EXCEPTION
            'compute_order_pricing(uuid, uuid, jsonb) not found. Either migration 31 '
            'was never applied, or this migration has already run.';
    END IF;

    IF position(v_sig_old IN v_def) = 0 THEN
        RAISE EXCEPTION 'Could not find the argument list to extend. Patch by hand.';
    END IF;

    IF position(v_dist_old IN v_def) = 0 THEN
        RAISE EXCEPTION
            'Could not find the distance assignment in compute_order_pricing. '
            'It has drifted from migration 31; patch by hand.';
    END IF;

    v_def := replace(v_def, v_sig_old,  v_sig_new);
    v_def := replace(v_def, v_dist_old, v_dist_new);

    -- The old function must go before the new one exists, or PostgREST sees
    -- two candidates for a three-argument call.
    DROP FUNCTION public.compute_order_pricing(uuid, uuid, jsonb);
    EXECUTE v_def;

    RAISE NOTICE 'compute_order_pricing now prices a custom drop-off point.';
END;
$migration$;

REVOKE ALL ON FUNCTION public.compute_order_pricing(uuid, uuid, jsonb, numeric, numeric)
    FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.compute_order_pricing(uuid, uuid, jsonb, numeric, numeric)
    TO authenticated;

-- ----------------------------------------------------------------------------
-- 6. The quote the app shows
--
-- Short enough to restate. Same two new parameters, passed straight through,
-- so the figure on the checkout screen is the figure that will be charged.
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.quote_order_fee(uuid, uuid, jsonb);

CREATE OR REPLACE FUNCTION public.quote_order_fee(
    p_vendor_id            uuid,
    p_delivery_location_id uuid,
    p_items                jsonb,
    p_dropoff_lat          numeric DEFAULT NULL,
    p_dropoff_lng          numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- A pin outside the zone is refused here as well as at place_order, so the
    -- customer is told while they are still looking at the map.
    IF p_dropoff_lat IS NOT NULL AND p_dropoff_lng IS NOT NULL
       AND NOT public.is_within_delivery_zone(p_dropoff_lat, p_dropoff_lng) THEN
        RAISE EXCEPTION 'That spot is outside the UCLM delivery area. Choose a point inside the circle.';
    END IF;

    RETURN public.compute_order_pricing(
        p_vendor_id, p_delivery_location_id, p_items, p_dropoff_lat, p_dropoff_lng
    );
END;
$$;

REVOKE ALL ON FUNCTION public.quote_order_fee(uuid, uuid, jsonb, numeric, numeric)
    FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.quote_order_fee(uuid, uuid, jsonb, numeric, numeric)
    TO authenticated;

REVOKE ALL ON FUNCTION public.point_distance_km(double precision, double precision, double precision, double precision) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.point_distance_km(double precision, double precision, double precision, double precision) TO authenticated;

REVOKE ALL ON FUNCTION public.campus_to_point_distance_km(uuid, double precision, double precision) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.campus_to_point_distance_km(uuid, double precision, double precision) TO authenticated;

REVOKE ALL ON FUNCTION public.is_within_delivery_zone(double precision, double precision) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.is_within_delivery_zone(double precision, double precision) TO authenticated;

REVOKE ALL ON FUNCTION public.delivery_zone_info() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.delivery_zone_info() TO authenticated;
