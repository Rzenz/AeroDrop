-- ============================================================================
-- 43_adjust_campus_positions.sql
--
-- Moves three points to where the team marked them on the live map on
-- 25 November, after seeing migration 42 rendered:
--
--   TEST-DROP   18 m west, 5 m north   (off the path, onto the open ground)
--   BASE-HUB    24 m west of Maritime  (second move today)
--   MARITIME    50 m west              (onto the building itself)
--
-- The other three buildings are untouched.
--
-- WHERE THE NUMBERS CAME FROM
-- Marked by hand on two screenshots of the app's own map, then read back by
-- locating the marks against markers whose coordinates were already known
-- and converting pixels to metres.
--
--   TEST-DROP is the reliable one: both reference markers in that screenshot
--   were known, and the horizontal and vertical scales derived from them
--   agree to 2.2%, which means the transform is sound.
--
--   BASE-HUB and MARITIME come from the other screenshot, whose two
--   reference markers sit only 8 m apart north-south -- too short a baseline
--   to derive a vertical scale from. Those two were solved against one
--   marker using the first screenshot's scale, which is valid because the
--   horizontal scales of the two screenshots agree to 2.6%, so both were
--   taken at the same zoom. Treat them as +/-5 m rather than exact.
--
-- None of this is survey data. It is good enough to put the markers where
-- the team wants them on screen. For a real landing, read each position off
-- the drone's own GPS in Mission Planner, in decimal degrees.
--
-- STILL INSIDE THE ZONE: 101 m, 86 m and 32 m from the 200 m zone centre.
--
-- THE CLIENTS WILL NOT FOLLOW THIS ON THEIR OWN. Maritime's coordinates are
-- hardcoded in shared_drone_radar.dart and location_provider.dart, and the
-- hub has four hardcoded fallbacks. This is the third hub position today;
-- see the note at the bottom.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-42.
-- ============================================================================

UPDATE public.campus_locations
SET latitude = 10.3253252, longitude = 123.9537220
WHERE location_code = 'TEST-DROP';

UPDATE public.campus_locations
SET latitude = 10.3261338, longitude = 123.9546208
WHERE location_code = 'BASE-HUB';

UPDATE public.campus_locations
SET latitude = 10.3261650, longitude = 123.9543871
WHERE location_code = 'MARITIME';

-- ----------------------------------------------------------------------------
-- Check
-- ----------------------------------------------------------------------------
DO $migration$
DECLARE
    r record; v_lat double precision; v_lng double precision; v_radius numeric;
BEGIN
    SELECT coalesce(z.center_latitude, l.latitude),
           coalesce(z.center_longitude, l.longitude), z.radius_meters
    INTO v_lat, v_lng, v_radius
    FROM public.delivery_zone z
    LEFT JOIN public.campus_locations l ON l.location_code = z.center_location_code
    WHERE z.id;

    RAISE NOTICE 'Delivery zone: % m around %, %', v_radius, v_lat, v_lng;
    FOR r IN
        SELECT location_code,
               round(public.point_distance_km(v_lat, v_lng, latitude, longitude) * 1000) AS m
        FROM public.campus_locations ORDER BY 2
    LOOP
        -- RAISE takes only bare % placeholders (no printf widths), so the
        -- columns are padded here.
        RAISE NOTICE '  % % m  %', rpad(r.location_code, 12), lpad(r.m::text, 5),
            CASE WHEN r.m <= v_radius THEN 'inside' ELSE 'OUTSIDE THE ZONE' END;
    END LOOP;
END;
$migration$;

-- ----------------------------------------------------------------------------
-- A note for whoever moves one of these next
--
-- Today the hub moved twice and three rows changed. Each time, the clients
-- had to be edited as well, because the campus coordinates are written down
-- in about a dozen places across the app and the website: a hardcoded list
-- in the radar, an offline list in location_provider, a name lookup in each
-- simulator, four hub fallbacks, and several map-framing defaults.
--
-- That is the real cost here, and it grows every time a point moves. The fix
-- is for both clients to read campus_locations and keep only layout hints
-- (the offline schematic's x/y) hardcoded. Until then, every move like this
-- one is a migration plus a hunt through two codebases.
-- ----------------------------------------------------------------------------
