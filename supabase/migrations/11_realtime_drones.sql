-- ============================================================
-- 11_REALTIME_DRONES.SQL
-- Enable Supabase Realtime for public.drones so radar/fleet
-- screens receive live status and battery updates.
-- (Already applied manually in the SQL Editor.)
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'drones'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.drones;
    END IF;
END $$;
