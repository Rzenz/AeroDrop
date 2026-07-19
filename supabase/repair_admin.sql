-- verification_queries.sql
-- 1. VERIFICATION QUERIES

-- Check if admin exists in auth.users
SELECT id, email, raw_user_meta_data FROM auth.users WHERE email = 'admin.portal@gmail.com';

-- Check matching public.users row
SELECT * FROM public.users WHERE id = (SELECT id FROM auth.users WHERE email = 'admin.portal@gmail.com');

-- Check matching public.user_credentials row
SELECT * FROM public.user_credentials WHERE user_id = (SELECT id FROM auth.users WHERE email = 'admin.portal@gmail.com');

-- Check matching public.user_profiles row
SELECT * FROM public.user_profiles WHERE user_id = (SELECT id FROM auth.users WHERE email = 'admin.portal@gmail.com');


-- 2. SAFE REPAIR SQL BLOCK (safe to rerun, does not create a second unrelated UUID, uses existing auth.users UUID)
DO $$
DECLARE
    v_admin_id uuid;
    v_admin_role_id uuid;
BEGIN
    -- Find the admin user ID from auth.users
    SELECT id INTO v_admin_id FROM auth.users WHERE email = 'admin.portal@gmail.com';
    
    IF v_admin_id IS NULL THEN
        RAISE NOTICE 'Admin user admin.portal@gmail.com not found in auth.users. Please create the user in the Supabase Auth Dashboard first.';
    ELSE
        -- Resolve admin role_id
        SELECT role_id INTO v_admin_role_id FROM public.user_roles WHERE role_name = 'admin';
        
        -- Insert public.users row if missing
        INSERT INTO public.users (id, created_at, updated_at)
        VALUES (v_admin_id, now(), now())
        ON CONFLICT (id) DO NOTHING;
        
        -- Insert or update user_credentials
        INSERT INTO public.user_credentials (user_id, email, role_id, account_status, created_at, updated_at)
        VALUES (v_admin_id, 'admin.portal@gmail.com', v_admin_role_id, 'active', now(), now())
        ON CONFLICT (user_id) DO UPDATE
        SET email = EXCLUDED.email,
            role_id = EXCLUDED.role_id,
            account_status = 'active',
            updated_at = now();
            
        -- Insert or update user_profiles
        INSERT INTO public.user_profiles (user_id, full_name, phone_number, created_at, updated_at)
        VALUES (v_admin_id, 'Admin Commander', '09170000000', now(), now())
        ON CONFLICT (user_id) DO UPDATE
        SET full_name = EXCLUDED.full_name,
            updated_at = now();
            
        RAISE NOTICE 'Admin account synchronized and verified successfully.';
    END IF;
END $$;
