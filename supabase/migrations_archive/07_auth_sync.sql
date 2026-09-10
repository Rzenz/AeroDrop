-- 07_auth_sync.sql
-- Creates the secure database trigger to automatically synchronize Supabase Auth registrations directly into public.users.

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger AS $$
DECLARE
    v_role text;
    v_full_name text;
    v_phone text;
    v_vendor_status text := NULL;
BEGIN
    -- Read metadata from new auth user
    v_role := COALESCE(NEW.raw_user_meta_data->>'requested_role', NEW.raw_user_meta_data->>'role', 'user');
    v_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1));
    v_phone := NEW.raw_user_meta_data->>'phone_number';

    -- Validate role selection (disallow direct self-registration as admin; vendor applicants start with role 'user' and pending vendor_status)
    IF v_role = 'admin' THEN
        v_role := 'user';
    ELSIF v_role = 'vendor' THEN
        v_role := 'user';
        v_vendor_status := 'pending';
    ELSIF v_role NOT IN ('user', 'vendor', 'admin') THEN
        v_role := 'user';
    END IF;

    -- Insert into public.users
    INSERT INTO public.users (
        id, 
        email, 
        full_name, 
        phone_number, 
        role, 
        account_status, 
        vendor_status, 
        created_at, 
        updated_at
    )
    VALUES (
        NEW.id, 
        LOWER(NEW.email), 
        v_full_name, 
        v_phone, 
        v_role, 
        'active', 
        v_vendor_status, 
        now(), 
        now()
    )
    ON CONFLICT (id) DO UPDATE 
    SET email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
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
    v_role text;
    v_full_name text;
    v_phone text;
    v_vendor_status text;
BEGIN
    FOR r IN 
        SELECT id, email, raw_user_meta_data 
        FROM auth.users a
        WHERE NOT EXISTS (
            SELECT 1 FROM public.users p WHERE p.id = a.id
        )
    LOOP
        v_role := COALESCE(r.raw_user_meta_data->>'requested_role', r.raw_user_meta_data->>'role', 'user');
        v_full_name := COALESCE(r.raw_user_meta_data->>'full_name', r.raw_user_meta_data->>'name', split_part(r.email, '@', 1));
        v_phone := r.raw_user_meta_data->>'phone_number';

        IF v_role = 'admin' THEN
            v_role := 'user';
            v_vendor_status := NULL;
        ELSIF v_role = 'vendor' THEN
            v_role := 'user';
            v_vendor_status := 'pending';
        ELSE
            v_role := 'user';
            v_vendor_status := NULL;
        END IF;

        INSERT INTO public.users (
            id, 
            email, 
            full_name, 
            phone_number, 
            role, 
            account_status, 
            vendor_status, 
            created_at, 
            updated_at
        )
        VALUES (
            r.id, 
            LOWER(r.email), 
            v_full_name, 
            v_phone, 
            v_role, 
            'active', 
            v_vendor_status, 
            now(), 
            now()
        )
        ON CONFLICT (id) DO UPDATE 
        SET email = EXCLUDED.email,
            full_name = EXCLUDED.full_name,
            phone_number = EXCLUDED.phone_number,
            updated_at = now();
            
        RAISE NOTICE 'Backfilled public.users for user % (%)', r.id, r.email;
    END LOOP;
END $$;
