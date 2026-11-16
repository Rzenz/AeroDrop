-- ============================================================================
-- 41_delivery_zone_centre.sql
--
-- Lets the delivery zone sit anywhere, not only on a building.
--
-- Migration 39 centred the zone on a campus_locations row, and the only
-- sensible choice was BASE-HUB. But the hub is the WESTERNMOST point of the
-- campus, so a circle around it spends half its area over the water and still
-- has to reach 228 m east to include the Maritime Building.
--
-- Centred on the middle of the four delivery buildings instead, the farthest
-- of them is 124 m away and the hub is 105 m away, so a much smaller circle
-- covers everything and far less of it falls outside the campus.
--
-- NO APP OR WEBSITE CHANGE IS NEEDED. delivery_zone_info() returns the same
-- fields it always did; only the values differ. is_within_delivery_zone()
-- reads the same place. Both clients pick this up on their next call.
--
-- THE NUMBERS ARE TUNABLE WITHOUT A MIGRATION. Centre and radius are columns.
-- Changing either is one UPDATE and takes effect immediately -- see the
-- bottom of this file.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-40.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. A centre that is not tied to a building
--
-- When these are set they win; when they are NULL the behaviour is exactly as
-- before, so this is safe to apply before deciding anything.
-- ----------------------------------------------------------------------------
ALTER TABLE public.delivery_zone
    ADD COLUMN IF NOT EXISTS center_latitude  numeric,
    ADD COLUMN IF NOT EXISTS center_longitude numeric;

ALTER TABLE public.delivery_zone
    ALTER COLUMN center_location_code DROP NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'delivery_zone_centre_pair') THEN
        ALTER TABLE public.delivery_zone ADD CONSTRAINT delivery_zone_centre_pair
            CHECK ((center_latitude IS NULL) = (center_longitude IS NULL));
    END IF;
END;
$$;

COMMENT ON COLUMN public.delivery_zone.center_latitude IS
    'Overrides center_location_code when set. Lets the zone sit between '
    'buildings rather than on one of them.';

-- ----------------------------------------------------------------------------
-- 2. Both readers take the override
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
    v_radius numeric;
    v_lat    double precision;
    v_lng    double precision;
BEGIN
    IF p_lat IS NULL OR p_lng IS NULL THEN
        RETURN false;
    END IF;

    SELECT z.radius_meters,
           coalesce(z.center_latitude,  l.latitude),
           coalesce(z.center_longitude, l.longitude)
    INTO v_radius, v_lat, v_lng
    FROM public.delivery_zone z
    LEFT JOIN public.campus_locations l ON l.location_code = z.center_location_code
    WHERE z.id;

    -- No centre configured: refuse rather than allow.
    IF v_lat IS NULL OR v_radius IS NULL THEN
        RETURN false;
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
        'center_name',          coalesce(
                                    CASE WHEN z.center_latitude IS NOT NULL
                                         THEN 'UCLM campus' END,
                                    l.name),
        'center_latitude',      coalesce(z.center_latitude,  l.latitude),
        'center_longitude',     coalesce(z.center_longitude, l.longitude),
        'radius_meters',        z.radius_meters
    )
    INTO v
    FROM public.delivery_zone z
    LEFT JOIN public.campus_locations l ON l.location_code = z.center_location_code
    WHERE z.id;

    RETURN coalesce(v, '{}'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.is_within_delivery_zone(double precision, double precision) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.is_within_delivery_zone(double precision, double precision) TO authenticated;
REVOKE ALL ON FUNCTION public.delivery_zone_info() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.delivery_zone_info() TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. Move the zone onto the campus
--
-- The centre is the mean of the four delivery buildings. From there:
--
--   ANNEX-2     19 m        MAIN        86 m
--   BASIC-ED    46 m        BASE-HUB   105 m
--   MARITIME   124 m
--
-- 200 m covers all five with 76 m to spare at the farthest, and reaches far
-- less water than 300 m from the hub did.
-- ----------------------------------------------------------------------------
UPDATE public.delivery_zone
SET center_latitude  = 10.3255400,
    center_longitude = 123.9539168,
    radius_meters    = 200,
    updated_at       = now()
WHERE id;

-- ----------------------------------------------------------------------------
-- 4. Changing it later
--
-- Both take effect on the clients' next call. No migration, no app release.
--
--   -- a different size
--   UPDATE public.delivery_zone SET radius_meters = 250, updated_at = now() WHERE id;
--
--   -- a different centre
--   UPDATE public.delivery_zone
--   SET center_latitude = 10.3256, center_longitude = 123.9540, updated_at = now()
--   WHERE id;
--
--   -- back to a building
--   UPDATE public.delivery_zone
--   SET center_latitude = NULL, center_longitude = NULL,
--       center_location_code = 'BASE-HUB', updated_at = now()
--   WHERE id;
--
-- To see what a given centre and radius would cover:
--   SELECT location_code,
--          round(public.point_distance_km(10.3255400, 123.9539168, latitude, longitude) * 1000) AS metres
--   FROM public.campus_locations ORDER BY 2;
-- ----------------------------------------------------------------------------
