-- ============================================================================
-- 47_move_hub_and_test_drop.sql
--
-- Moves two points to where the team marked them on the pin picker on the
-- night of 27-28 November:
--
--   BASE-HUB    -> 10.3253829, 123.9537052   (into the middle of campus)
--   TEST-DROP   -> 10.3256272, 123.9539688   (north-east, beside Annex 2)
--
-- The four buildings are untouched.
--
-- ACCURACY -- better than anything before it
-- Marked on a screenshot of the app's own pin picker, which showed FOUR
-- markers whose coordinates were already known: MAIN, ANNEX-2, BASIC-ED and
-- TEST-DROP. Fitting a transform across all four gives horizontal and
-- vertical scales agreeing to 0.4%, and every one of the four lands within
-- 0.5 m of where that transform predicts.
--
-- For comparison, the Compass readings behind migration 42 were on a ~31 m
-- grid, and migration 43's figures came from a two-marker fit. These are the
-- first campus coordinates in this project that are good to about a metre
-- RELATIVE to the existing points -- though the whole set still inherits the
-- absolute error of the original map estimates. Good enough to put markers
-- where they belong on screen; still not survey data to land on.
--
-- CHECKS
--   hub       29 m from the zone centre, 29 m from its nearest building
--   test drop 11 m from the zone centre, 22 m from its nearest building
--   both inside the 200 m delivery zone
--   longest mission (hub -> vendor -> customer -> hub) falls to 341 m,
--   because the hub is now central rather than at the eastern edge
--
-- NO CLIENT CHANGE IS NEEDED. Since the 25 November refactor, the radar, the
-- pin picker, both flight simulators and the website map all read
-- campus_locations. Applying this moves the markers in both clients with no
-- rebuild. The pre-load hub fallbacks in client code still hold the old
-- value and will show it for the first frames after launch; that is cosmetic
-- and deliberately left alone.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-46.
-- ============================================================================

UPDATE public.campus_locations
SET latitude = 10.3253829, longitude = 123.9537052
WHERE location_code = 'BASE-HUB';

UPDATE public.campus_locations
SET latitude = 10.3256272, longitude = 123.9539688
WHERE location_code = 'TEST-DROP';

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
