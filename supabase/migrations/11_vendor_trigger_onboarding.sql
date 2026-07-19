-- 11_vendor_trigger_onboarding.sql
-- Recreates handle_new_auth_user() to support vendor application onboarding during registration.

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger AS $$
DECLARE
    v_role_name text;
    v_role_id uuid;
    v_full_name text;
    v_phone text;
    v_biz_name text;
    v_biz_desc text;
    v_location_id uuid;
    v_initials text;
    v_pending_status_id uuid;
BEGIN
    -- Read metadata from new auth user
    v_role_name := COALESCE(NEW.raw_user_meta_data->>'requested_role', NEW.raw_user_meta_data->>'role', 'student');
    v_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1));
    v_phone := NEW.raw_user_meta_data->>'phone_number';

    -- Validate role selection (disallow direct self-registration as admin or vendor)
    -- Vendors start with standard student credentials and get promoted upon approval
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

    -- If the user registered as a vendor, insert their pending store profile
    IF COALESCE(NEW.raw_user_meta_data->>'requested_role', '') = 'vendor' THEN
        v_biz_name := NEW.raw_user_meta_data->>'business_name';
        v_biz_desc := NEW.raw_user_meta_data->>'business_description';
        
        -- Block registration if required fields are missing
        IF v_biz_name IS NULL OR v_biz_name = '' THEN
            RAISE EXCEPTION 'Business Name is required for vendor applications.';
        END IF;
        
        IF NEW.raw_user_meta_data->>'campus_location_id' IS NULL THEN
            RAISE EXCEPTION 'Campus Location is required for vendor applications.';
        END IF;
        
        v_location_id := (NEW.raw_user_meta_data->>'campus_location_id')::uuid;
        v_initials := upper(substring(v_biz_name from 1 for 2));
        
        -- Resolve pending status ID
        SELECT id INTO v_pending_status_id FROM public.vendor_statuses WHERE name = 'pending';
        IF v_pending_status_id IS NULL THEN
            v_pending_status_id := 'e1a12a3d-4c8d-4a11-b0e1-123456789abc';
        END IF;

        INSERT INTO public.vendors (
            user_id,
            business_name,
            description,
            logo_initials,
            logo_color,
            campus_location_id,
            status_id,
            created_at,
            updated_at
        ) VALUES (
            NEW.id,
            v_biz_name,
            COALESCE(v_biz_desc, 'Pending store description.'),
            v_initials,
            '#FFFF6B35',
            v_location_id,
            v_pending_status_id,
            now(),
            now()
        ) ON CONFLICT (user_id) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
