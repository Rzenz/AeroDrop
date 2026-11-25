-- ============================================================================
-- 44_enforce_no_fly_zones.sql
--
-- Makes the no-fly zone screen mean something.
--
-- public.no_fly_zones has existed since the first migration, with a 594-line
-- admin page to create, edit and delete zones. Nothing has ever read it. An
-- administrator could draw a zone over the chapel and the drone would route
-- straight through it, because no code consulted the table when an order was
-- placed or a flight planned.
--
-- After this migration an order whose drop-off falls inside an ACTIVE zone is
-- refused -- at the quote, so the customer is told while they are still
-- choosing, and again at place_order, so no client can skip the check.
--
-- APPLIES TO BOTH KINDS OF DROP-OFF. A map pin is checked at its own
-- coordinates; a campus building is checked at the building's. A zone drawn
-- over a building blocks orders to that building, which is the point.
--
-- EXISTING ZONES: there are none. The table is empty, so applying this
-- changes no behaviour until somebody draws a zone. That is deliberate --
-- it means this can go in without affecting anything today, and the admin
-- screen starts working the moment it is used.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-43:
--   public.no_fly_zones (latitude, longitude, radius_meters, is_active)
--   public.point_distance_km (migration 39)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Is this point inside a zone
--
-- Returns the name of the first active zone containing the point, or NULL.
-- A zone with no coordinates or no radius is ignored rather than treated as
-- covering everything: a half-filled row should not ground the fleet.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.no_fly_zone_at(
    p_lat double precision,
    p_lng double precision
)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT z.name
    FROM public.no_fly_zones z
    WHERE z.is_active
      AND z.latitude IS NOT NULL
      AND z.longitude IS NOT NULL
      AND z.radius_meters IS NOT NULL
      AND z.radius_meters > 0
      AND p_lat IS NOT NULL
      AND p_lng IS NOT NULL
      AND public.point_distance_km(z.latitude, z.longitude, p_lat, p_lng) * 1000
          <= z.radius_meters
    ORDER BY z.radius_meters
    LIMIT 1;
$$;

-- ----------------------------------------------------------------------------
-- 2. Refuse, and say which zone
--
-- A procedure rather than a boolean, so the callers below are a single line
-- and need no new local variable. Patching a 300-line function is safest
-- when the patch is one line.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assert_not_in_no_fly_zone(
    p_lat double precision,
    p_lng double precision
)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_zone text;
BEGIN
    v_zone := public.no_fly_zone_at(p_lat, p_lng);
    IF v_zone IS NOT NULL THEN
        RAISE EXCEPTION
            'That drop-off is inside the no-fly zone "%". Choose a different spot.',
            v_zone;
    END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. The zones, for drawing on a map
--
-- The pin picker can show them so a customer sees the restriction before
-- being refused by it. Nothing uses this yet.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.active_no_fly_zones()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'name', name, 'description', description,
        'latitude', latitude, 'longitude', longitude,
        'radius_meters', radius_meters
    ) ORDER BY name), '[]'::jsonb)
    FROM public.no_fly_zones
    WHERE is_active
      AND latitude IS NOT NULL AND longitude IS NOT NULL
      AND radius_meters IS NOT NULL AND radius_meters > 0;
$$;

-- ----------------------------------------------------------------------------
-- 4. Check it at the quote
--
-- quote_order_fee is short and was last written in full by migration 39, so
-- it is restated rather than patched. The delivery-zone check keeps its
-- current behaviour; the no-fly check is added after it and covers a campus
-- building as well as a pin.
-- ----------------------------------------------------------------------------
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
DECLARE
    v_lat double precision;
    v_lng double precision;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_dropoff_lat IS NOT NULL AND p_dropoff_lng IS NOT NULL
       AND NOT public.is_within_delivery_zone(p_dropoff_lat, p_dropoff_lng) THEN
        RAISE EXCEPTION 'That spot is outside the UCLM delivery area. Choose a point inside the circle.';
    END IF;

    -- Whichever kind of drop-off this is, resolve it to a point and check it.
    IF p_dropoff_lat IS NOT NULL THEN
        v_lat := p_dropoff_lat; v_lng := p_dropoff_lng;
    ELSE
        SELECT latitude, longitude INTO v_lat, v_lng
        FROM public.campus_locations WHERE id = p_delivery_location_id;
    END IF;

    PERFORM public.assert_not_in_no_fly_zone(v_lat, v_lng);

    RETURN public.compute_order_pricing(
        p_vendor_id, p_delivery_location_id, p_items, p_dropoff_lat, p_dropoff_lng
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. Check it again at place_order
--
-- The quote is advice; this is the gate. Patched from the live definition
-- with a SINGLE-LINE anchor -- migration 40 failed on a multi-line one, and
-- the lesson stuck.
-- ----------------------------------------------------------------------------
DO $migration$
DECLARE
    v_def  text;
    v_old  text := 'v_pricing := public.compute_order_pricing(p_vendor_id, p_delivery_location_id, p_items, p_dropoff_lat, p_dropoff_lng);';
    v_new  text := 'PERFORM public.assert_not_in_no_fly_zone('
                || 'coalesce(p_dropoff_lat, (SELECT latitude FROM public.campus_locations WHERE id = p_delivery_location_id)), '
                || 'coalesce(p_dropoff_lng, (SELECT longitude FROM public.campus_locations WHERE id = p_delivery_location_id)));'
                || E'\n    v_pricing := public.compute_order_pricing(p_vendor_id, p_delivery_location_id, p_items, p_dropoff_lat, p_dropoff_lng);';
    v_hits integer;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'place_order';

    IF v_def IS NULL THEN
        RAISE EXCEPTION 'place_order not found.';
    END IF;

    IF position('assert_not_in_no_fly_zone' IN v_def) > 0 THEN
        RAISE NOTICE 'place_order already checks no-fly zones; nothing to do.';
        RETURN;
    END IF;

    v_hits := (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old);

    IF v_hits = 0 THEN
        RAISE EXCEPTION
            'Could not find place_order''s pricing call. It has drifted from '
            'migration 40; patch by hand.';
    END IF;
    IF v_hits > 1 THEN
        RAISE EXCEPTION 'The pricing call appears % times; patch by hand.', v_hits;
    END IF;

    EXECUTE replace(v_def, v_old, v_new);
    RAISE NOTICE 'place_order now refuses a drop-off inside an active no-fly zone.';
END;
$migration$;

-- ----------------------------------------------------------------------------
-- 6. Grants
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.no_fly_zone_at(double precision, double precision) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.no_fly_zone_at(double precision, double precision) TO authenticated;

REVOKE ALL ON FUNCTION public.assert_not_in_no_fly_zone(double precision, double precision) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.assert_not_in_no_fly_zone(double precision, double precision) TO authenticated;

REVOKE ALL ON FUNCTION public.active_no_fly_zones() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.active_no_fly_zones() TO authenticated;

REVOKE ALL ON FUNCTION public.quote_order_fee(uuid, uuid, jsonb, numeric, numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.quote_order_fee(uuid, uuid, jsonb, numeric, numeric) TO authenticated;
