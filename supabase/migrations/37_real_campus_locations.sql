-- ============================================================================
-- 37_real_campus_locations.sql
--
-- 01_remote_baseline.sql seeds five campus locations that do not exist:
--
--   id                 10000000-0000-0000-0000-00000000000{1..5}
--   codes              LOC-OB, LOC-A1, LOC-A2, LOC-BE, LOC-MB
--   coordinates        around 10.3156, 123.9016
--
-- The real table holds five different rows, with different ids, different
-- codes, and coordinates around 10.3252, 123.9532 -- about 5.7 km from where
-- the seed puts them. It also has a BASE-HUB row the seed never created, and
-- no "Annex 1" at all.
--
-- Nothing is broken today, because the real rows are already in the live
-- database and nothing reads the seed. It matters the day someone rebuilds
-- the project from supabase/migrations: they would get a campus in the wrong
-- place, no drone hub, and a building that does not exist.
--
-- This migration makes the migration history produce the real campus.
--
-- WHY NOT JUST EDIT MIGRATION 01
-- It is already applied and recorded. Editing an applied migration means the
-- file no longer matches what ran, which is worse than a stale seed. Later
-- migrations correct earlier ones; that is what the history is for.
--
-- COORDINATES ARE ESTIMATES. They were picked off a map, not surveyed. They
-- are what the app uses to draw a drone moving between buildings, and they
-- are not accurate enough to land on. Replace them when the sites are
-- properly measured.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-36:
--   public.campus_locations (id, name, location_code, latitude, longitude,
--   created_at). There is no is_active column; the app supplies that itself.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. The real locations
--
-- Keyed by id, so on the live database every row already matches and this is
-- a no-op. On a rebuilt database it creates them.
-- ----------------------------------------------------------------------------
INSERT INTO public.campus_locations (id, name, location_code, latitude, longitude) VALUES
  ('d637fc1f-64af-4911-9edb-b80ee587bb1e', 'Campus Drone Hub',             'BASE-HUB', 10.3251520, 123.9530460),
  ('0b29ab20-8522-4778-a9d8-827516a57a6a', 'Old Building (Main Building)', 'MAIN',     10.3252100, 123.9532010),
  ('20e78551-c5a0-4d6f-8607-40628693589b', 'Basic Education Building',     'BASIC-ED', 10.3251330, 123.9538530),
  ('19f9571d-9c16-47d2-b54b-632d9f7a37c2', 'Annex 2 Building',             'ANNEX-2',  10.3256330, 123.9537700),
  ('b59b7f2d-07a2-44a4-a552-fb945c18452e', 'Maritime Building',            'MARITIME', 10.3261840, 123.9548430)
ON CONFLICT (id) DO UPDATE SET
  name          = EXCLUDED.name,
  location_code = EXCLUDED.location_code,
  latitude      = EXCLUDED.latitude,
  longitude     = EXCLUDED.longitude;

-- ----------------------------------------------------------------------------
-- 2. Remove the invented rows
--
-- Every foreign key to this table is ON DELETE SET NULL, so an unguarded
-- delete would not fail -- it would silently blank the drop-off on somebody's
-- order. The guard means a row that anything points at is kept, and the
-- NOTICE below says so.
--
-- On the live database this deletes nothing: those ids were never there.
-- ----------------------------------------------------------------------------
DO $migration$
DECLARE
    c_stale uuid[] := ARRAY[
        '10000000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000002',
        '10000000-0000-0000-0000-000000000003',
        '10000000-0000-0000-0000-000000000004',
        '10000000-0000-0000-0000-000000000005'
    ]::uuid[];
    v_referenced integer;
    v_deleted    integer;
BEGIN
    SELECT count(*) INTO v_referenced
    FROM public.campus_locations cl
    WHERE cl.id = ANY (c_stale)
      AND (EXISTS (SELECT 1 FROM public.users      u WHERE u.campus_location_id   = cl.id)
        OR EXISTS (SELECT 1 FROM public.orders     o WHERE o.delivery_location_id = cl.id)
        OR EXISTS (SELECT 1 FROM public.deliveries d WHERE d.pickup_location_id   = cl.id
                                                        OR d.dropoff_location_id  = cl.id));

    DELETE FROM public.campus_locations cl
    WHERE cl.id = ANY (c_stale)
      AND NOT EXISTS (SELECT 1 FROM public.users      u WHERE u.campus_location_id   = cl.id)
      AND NOT EXISTS (SELECT 1 FROM public.orders     o WHERE o.delivery_location_id = cl.id)
      AND NOT EXISTS (SELECT 1 FROM public.deliveries d WHERE d.pickup_location_id   = cl.id
                                                           OR d.dropoff_location_id  = cl.id);

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RAISE NOTICE 'Stale seeded locations removed: %. Kept because something still references them: %.',
        v_deleted, v_referenced;
END;
$migration$;
