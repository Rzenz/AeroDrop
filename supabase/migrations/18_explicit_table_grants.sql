-- ============================================================================
-- 18_explicit_table_grants.sql
--
-- WHY THIS EXISTS
-- Supabase stopped auto-granting Data API access to new tables in the "public"
-- schema on 2026-10-30. Before that date, every table created in "public"
-- silently received grants for anon / authenticated / service_role, so
-- migrations 01-17 never needed to declare them.
--
-- The live project is unaffected (its existing grants were kept). The problem
-- is schema RECREATION: running migrations 01-17 against a fresh project, a
-- preview branch, or `supabase db reset` after that date produces a perfect
-- schema with no grants at all, and every Data API call fails with
-- "permission denied for table ...".
--
-- This migration declares those grants explicitly so the migration history is
-- self-sufficient. Re-granting a privilege that already exists is a no-op, so
-- applying this to the live project changes nothing.
--
-- NOTE ON SECURITY: these grants are only the coarse, table-level layer.
-- Row Level Security is what actually restricts which rows each user can see
-- and modify, and RLS is enabled on all 16 tables by migrations 01, 07 and 12.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Schema usage (prerequisite for any table grant to be usable)
-- ----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Application tables
--
-- SELECT/INSERT/UPDATE/DELETE are the only privileges PostgREST needs.
-- TRIGGER, REFERENCES, TRUNCATE and MAINTAIN are deliberately NOT granted:
-- the Data API never uses them, and MAINTAIN only exists on PostgreSQL 17+,
-- which would break `supabase db reset` on an older local Postgres.
-- RLS still governs every row these roles can actually reach.
-- ----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON
    public.campus_locations,
    public.deliveries,
    public.delivery_status_logs,
    public.drone_telemetry,
    public.drones,
    public.no_fly_zones,
    public.notifications,
    public.order_items,
    public.orders,
    public.product_reviews,
    public.products,
    public.store_reviews,
    public.support_reports,
    public.telemetry_event_types,
    public.users,
    public.weather_safety
TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. Rating summary views (read-only; defined with security_invoker in 13)
-- ----------------------------------------------------------------------------
GRANT SELECT ON
    public.vendor_ratings_summary,
    public.product_ratings_summary
TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. Anonymous access
--
-- campus_locations must stay readable by anon: the vendor registration screen
-- loads the campus location list before the account exists, so the request is
-- made with the anon key.
-- ----------------------------------------------------------------------------
GRANT SELECT ON public.campus_locations TO anon;

-- ----------------------------------------------------------------------------
-- 5. Remove leftover default anon grants
--
-- These four tables still carry Supabase's old default of full DML for anon.
-- The core tables had anon revoked at some point in the project's history;
-- these were missed. store_reviews, product_reviews and support_reports were
-- added later (migrations 12 and 07); telemetry_event_types dates from 01 but
-- was overlooked by that revoke.
--
-- Verified safe to revoke before writing this migration:
--   store_reviews / product_reviews - only "FOR SELECT TO authenticated"
--       policies exist; all writes go through submit_order_reviews().
--   support_reports - every policy tests user_id = auth.uid() or is_admin(),
--       both of which are false when auth.uid() is NULL (anon).
--   telemetry_event_types - RLS enabled with zero policies (deny all), and
--       the Flutter app never queries it.
--
-- So anon could already reach none of these; this removes the latent risk that
-- a future permissive policy without a TO authenticated clause exposes them.
-- ----------------------------------------------------------------------------
REVOKE ALL ON public.store_reviews         FROM anon;
REVOKE ALL ON public.product_reviews       FROM anon;
REVOKE ALL ON public.support_reports       FROM anon;
REVOKE ALL ON public.telemetry_event_types FROM anon;
