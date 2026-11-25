-- ============================================================================
-- 42_test_dropoff_and_new_hub.sql
--
-- Two changes agreed with the team on 25 November:
--
--   1. The drone hub moves 212 m east, to beside the Maritime Building.
--   2. A new drop-off point, "Test Drop-off Point", is added for field tests.
--      The four existing buildings are untouched and stay selectable.
--
-- WHERE THE NUMBERS CAME FROM
-- Read off the iPhone Compass app on site and converted from degrees-minutes-
-- seconds:
--
--   Test Drop-off  10°19'31" N 123°57'14" E  ->  10.3252778, 123.9538889
--   Base Hub       10°19'34" N 123°57'17" E  ->  10.3261111, 123.9547222
--
-- PRECISION -- READ THIS
-- The Compass app shows whole arcseconds, and one arcsecond of latitude is
-- 30.9 m. These readings are therefore on a ~31 m grid, accurate to about
-- +/-15 m, which is WORSE than the map estimates already in this table.
--
-- That matters here, because:
--   - the new Test Drop-off is 17 m from the Basic Education Building
--   - the new hub is 16 m from the Maritime Building
-- Both separations are smaller than the measurement error, so on the map
-- these points may appear to sit on top of a building they are not at.
--
-- Good enough to fly a simulation and demonstrate the feature. NOT good
-- enough to land on. For that, read the position off the drone's own GPS in
-- Mission Planner, in decimal degrees, and update these two rows.
--
-- WHAT THIS AFFECTS WITHOUT ANY CODE CHANGE
--   - the customer drop-off list in both clients (the app filters only on
--     location_code = 'BASE-HUB', so the new row simply appears)
--   - delivery pricing, which measures vendor -> drop-off
--   - get_order_flight_plan, whose launch and return waypoints read the hub
--   - is_within_delivery_zone: both new points are inside the 200 m zone
--     (29 m and 109 m from its centre), so the zone needs no change
--
-- WHAT IT DOES NOT AFFECT
-- Both clients keep their own hardcoded copies of these coordinates --
-- shared_drone_radar.dart and website/src/lib/flight-calc.ts. They will not
-- move until those are updated too.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-41.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Move the hub
--
-- Keyed on location_code, which is what the app, the radar and
-- get_order_flight_plan all look the hub up by. The row keeps its id, so
-- every delivery that already points at it stays valid.
-- ----------------------------------------------------------------------------
UPDATE public.campus_locations
SET latitude  = 10.3261111,
    longitude = 123.9547222
WHERE location_code = 'BASE-HUB';

-- ----------------------------------------------------------------------------
-- 2. Add the test drop-off
--
-- ON CONFLICT so re-running changes nothing unexpected. Named so that nobody
-- in a demo mistakes it for a real building.
-- ----------------------------------------------------------------------------
INSERT INTO public.campus_locations (name, location_code, latitude, longitude)
VALUES ('Test Drop-off Point', 'TEST-DROP', 10.3252778, 123.9538889)
ON CONFLICT (location_code) DO UPDATE SET
    name      = EXCLUDED.name,
    latitude  = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude;

-- ----------------------------------------------------------------------------
-- 3. Check it
--
-- Distances from the zone centre, so you can see at a glance that everything
-- is still inside the 200 m circle.
-- ----------------------------------------------------------------------------
DO $migration$
DECLARE
    r        record;
    v_lat    double precision;
    v_lng    double precision;
    v_radius numeric;
BEGIN
    SELECT coalesce(z.center_latitude, l.latitude),
           coalesce(z.center_longitude, l.longitude),
           z.radius_meters
    INTO v_lat, v_lng, v_radius
    FROM public.delivery_zone z
    LEFT JOIN public.campus_locations l ON l.location_code = z.center_location_code
    WHERE z.id;

    RAISE NOTICE 'Delivery zone: % m around %, %', v_radius, v_lat, v_lng;

    FOR r IN
        SELECT location_code, name,
               round(public.point_distance_km(v_lat, v_lng, latitude, longitude) * 1000) AS m
        FROM public.campus_locations ORDER BY 3
    LOOP
        -- RAISE takes only bare % placeholders (no printf widths), so the
        -- columns are padded here.
        RAISE NOTICE '  % % m  %',
            rpad(r.location_code, 12), lpad(r.m::text, 5),
            CASE WHEN r.m <= v_radius THEN 'inside' ELSE 'OUTSIDE THE ZONE' END;
    END LOOP;
END;
$migration$;
