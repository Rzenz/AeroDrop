-- 05_auth_sync.sql
-- Creates the secure database trigger to automatically synchronize Supabase Auth registrations.

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger AS $$
DECLARE
    v_role_name text;
    v_role_id uuid;
    v_full_name text;
    v_phone text;
BEGIN
    -- Read metadata from new auth user
    v_role_name := COALESCE(NEW.raw_user_meta_data->>'requested_role', NEW.raw_user_meta_data->>'role', 'student');
    v_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1));
    v_phone := NEW.raw_user_meta_data->>'phone_number';

    -- Validate role selection (disallow direct self-registration as admin or vendor)
    IF v_role_name NOT IN ('student', 'faculty_staff') THEN
        v_role_name := 'student';
    END IF;

    -- Enforce UCLM email domain constraint for faculty/staff
    IF v_role_name = 'faculty_staff' THEN
        IF NOT (NEW.email LIKE '%@uclm.edu.ph' OR NEW.email LIKE '%@uclm.edu') THEN
            RAISE EXCEPTION 'Faculty/Staff must use a @uclm.edu email address.';
        END IF;
    END IF;

    -- Resolve role_id from user_roles
    SELECT role_id INTO v_role_id FROM public.user_roles WHERE role_name = v_role_name;
    -- Fallback to student if not found
    IF v_role_id IS NULL THEN
        SELECT role_id INTO v_role_id FROM public.user_roles WHERE role_name = 'student';
    END IF;

    -- Insert into public.users
    INSERT INTO public.users (id, created_at, updated_at)
    VALUES (NEW.id, now(), now())
    ON CONFLICT (id) DO NOTHING;

    -- Insert into public.user_credentials
    INSERT INTO public.user_credentials (user_id, email, role_id, account_status, created_at, updated_at)
    VALUES (NEW.id, NEW.email, v_role_id, 'active', now(), now())
    ON CONFLICT (user_id) DO UPDATE 
    SET email = EXCLUDED.email,
        role_id = EXCLUDED.role_id,
        updated_at = now();

    -- Insert into public.user_profiles
    INSERT INTO public.user_profiles (user_id, full_name, phone_number, created_at, updated_at)
    VALUES (NEW.id, v_full_name, v_phone, now(), now())
    ON CONFLICT (user_id) DO UPDATE 
    SET full_name = EXCLUDED.full_name,
        phone_number = EXCLUDED.phone_number,
        updated_at = now();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();


-- =========================================================================
-- SAFE BACKFILL SCRIPT FOR EXISTING AUTH USERS
-- =========================================================================
DO $$
DECLARE
    r RECORD;
    v_role_name text;
    v_role_id uuid;
    v_full_name text;
    v_phone text;
BEGIN
    FOR r IN 
        SELECT id, email, raw_user_meta_data 
        FROM auth.users a
        WHERE NOT EXISTS (
            SELECT 1 FROM public.users p WHERE p.id = a.id
        ) OR NOT EXISTS (
            SELECT 1 FROM public.user_credentials c WHERE c.user_id = a.id
        ) OR NOT EXISTS (
            SELECT 1 FROM public.user_profiles pr WHERE pr.user_id = a.id
        )
    LOOP
        -- Read metadata from raw_user_meta_data
        v_role_name := COALESCE(r.raw_user_meta_data->>'requested_role', r.raw_user_meta_data->>'role', 'student');
        v_full_name := COALESCE(r.raw_user_meta_data->>'full_name', r.raw_user_meta_data->>'name', split_part(r.email, '@', 1));
        v_phone := r.raw_user_meta_data->>'phone_number';

        -- Validate role selection (disallow direct self-registration as admin or vendor)
        IF v_role_name NOT IN ('student', 'faculty_staff') THEN
            v_role_name := 'student';
        END IF;

        -- Enforce UCLM email domain constraint for faculty/staff
        IF v_role_name = 'faculty_staff' THEN
            IF NOT (r.email LIKE '%@uclm.edu.ph' OR r.email LIKE '%@uclm.edu') THEN
                v_role_name := 'student'; -- Demote or default to student instead of crashing backfill
            END IF;
        END IF;

        -- Resolve role_id from user_roles
        SELECT role_id INTO v_role_id FROM public.user_roles WHERE role_name = v_role_name;
        -- Fallback to student if not found
        IF v_role_id IS NULL THEN
            SELECT role_id INTO v_role_id FROM public.user_roles WHERE role_name = 'student';
        END IF;

        -- Insert into public.users
        INSERT INTO public.users (id, created_at, updated_at)
        VALUES (r.id, now(), now())
        ON CONFLICT (id) DO NOTHING;

        -- Insert into public.user_credentials
        INSERT INTO public.user_credentials (user_id, email, role_id, account_status, created_at, updated_at)
        VALUES (r.id, r.email, v_role_id, 'active', now(), now())
        ON CONFLICT (user_id) DO UPDATE 
        SET email = EXCLUDED.email,
            role_id = EXCLUDED.role_id,
            updated_at = now();

        -- Insert into public.user_profiles
        INSERT INTO public.user_profiles (user_id, full_name, phone_number, created_at, updated_at)
        VALUES (r.id, v_full_name, v_phone, now(), now())
        ON CONFLICT (user_id) DO UPDATE 
        SET full_name = EXCLUDED.full_name,
            phone_number = EXCLUDED.phone_number,
            updated_at = now();
            
        RAISE NOTICE 'Backfilled public tables for user % (%)', r.id, r.email;
    END LOOP;
END $$;


-- =========================================================================
-- DIAGNOSTIC AND SQL VERIFICATION QUERY
-- =========================================================================
-- Run this query to verify auth sync status for all registered users:
--
-- SELECT 
--     a.id AS auth_user_id,
--     a.email AS auth_email,
--     p.id IS NOT NULL AS public_user_exists,
--     c.user_id IS NOT NULL AS credentials_exists,
--     pr.user_id IS NOT NULL AS profile_exists,
--     r.role_name AS role_name,
--     c.account_status AS account_status
-- FROM auth.users a
-- LEFT JOIN public.users p ON a.id = p.id
-- LEFT JOIN public.user_credentials c ON a.id = c.user_id
-- LEFT JOIN public.user_roles r ON c.role_id = r.role_id
-- LEFT JOIN public.user_profiles pr ON a.id = pr.user_id;
