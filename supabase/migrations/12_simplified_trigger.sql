-- 12_simplified_trigger.sql
-- Replaces handle_new_auth_user() to support the new single-table denormalized users schema.

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger AS $$
DECLARE
    v_role text;
    v_vendor_status text;
BEGIN
    -- Resolve requested role (default to student)
    v_role := COALESCE(NEW.raw_user_meta_data->>'requested_role', NEW.raw_user_meta_data->>'role', 'student');

    -- Prevent self-registration as admin
    IF v_role = 'admin' THEN
        v_role := 'student';
    END IF;

    -- Faculty staff or student roles are kept as requested.
    -- Vendor applicants start with a role of 'student' and vendor_status as 'pending'
    IF v_role = 'vendor' THEN
        v_role := 'student';
        v_vendor_status := 'pending';
    ELSE
        v_vendor_status := NULL;
    END IF;

    -- Insert exactly one row into the flat public.users table
    INSERT INTO public.users (
        id,
        full_name,
        email,
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
    ) VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
        LOWER(NEW.email),
        NEW.raw_user_meta_data->>'phone_number',
        v_role,
        'active',
        v_vendor_status,
        NEW.raw_user_meta_data->>'business_name',
        NEW.raw_user_meta_data->>'business_category',
        NEW.raw_user_meta_data->>'business_description',
        (NEW.raw_user_meta_data->>'campus_location_id')::uuid,
        now(),
        now()
    ) ON CONFLICT (id) DO UPDATE
    SET 
        email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        phone_number = EXCLUDED.phone_number,
        business_name = EXCLUDED.business_name,
        business_category = EXCLUDED.business_category,
        business_description = EXCLUDED.business_description,
        campus_location_id = EXCLUDED.campus_location_id,
        updated_at = now();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Ensure the trigger is attached to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();
