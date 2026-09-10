-- 12_vendor_trigger_onboarding.sql
-- Recreates handle_new_auth_user() to support vendor application onboarding during registration directly into public.users.

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger AS $$
DECLARE
    v_role text := 'user';
    v_full_name text;
    v_phone text;
    v_requested_role text;
    v_vendor_status text := NULL;
    v_biz_name text := NULL;
    v_biz_category text := NULL;
    v_biz_desc text := NULL;
    v_location_id uuid := NULL;
    v_campus_string text;
BEGIN
    -- Read metadata from new auth user
    v_requested_role := lower(trim(COALESCE(NEW.raw_user_meta_data->>'requested_role', NEW.raw_user_meta_data->>'role', 'user')));
    v_full_name := COALESCE(nullif(trim(NEW.raw_user_meta_data->>'full_name'), ''), nullif(trim(NEW.raw_user_meta_data->>'name'), ''), split_part(coalesce(NEW.email, 'user'), '@', 1));
    v_phone := nullif(trim(NEW.raw_user_meta_data->>'phone_number'), '');

    -- Public vendor registration creates a pending user account
    IF v_requested_role = 'vendor' THEN
        v_role := 'user';
        v_vendor_status := 'pending';
        v_biz_name := nullif(trim(NEW.raw_user_meta_data->>'business_name'), '');
        v_biz_category := nullif(trim(NEW.raw_user_meta_data->>'business_category'), '');
        v_biz_desc := nullif(trim(NEW.raw_user_meta_data->>'business_description'), '');

        -- Validate campus location UUID
        v_campus_string := nullif(trim(NEW.raw_user_meta_data->>'campus_location_id'), '');
        IF v_campus_string IS NOT NULL AND v_campus_string ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
            v_location_id := v_campus_string::uuid;
        END IF;
    ELSE
        v_role := 'user';
        v_vendor_status := NULL;
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
        business_name,
        business_category,
        business_description,
        campus_location_id,
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
        v_biz_name,
        v_biz_category,
        v_biz_desc,
        v_location_id,
        now(), 
        now()
    )
    ON CONFLICT (id) DO UPDATE 
    SET email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        phone_number = EXCLUDED.phone_number,
        business_name = coalesce(EXCLUDED.business_name, public.users.business_name),
        business_category = coalesce(EXCLUDED.business_category, public.users.business_category),
        business_description = coalesce(EXCLUDED.business_description, public.users.business_description),
        campus_location_id = coalesce(EXCLUDED.campus_location_id, public.users.campus_location_id),
        updated_at = now();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
