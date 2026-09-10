-- repair_admin.sql
-- 1. VERIFICATION QUERIES

-- Check if admin exists in auth.users
SELECT id, email, raw_user_meta_data FROM auth.users WHERE email = 'admin.portal@gmail.com';

-- Check matching public.users row
SELECT * FROM public.users WHERE id = (SELECT id FROM auth.users WHERE email = 'admin.portal@gmail.com');


-- 2. SAFE REPAIR SQL BLOCK (safe to rerun, does not create a second unrelated UUID, uses existing auth.users UUID)
DO $$
DECLARE
    v_admin_id uuid;
BEGIN
    -- Find the admin user ID from auth.users
    SELECT id INTO v_admin_id FROM auth.users WHERE email = 'admin.portal@gmail.com';
    
    IF v_admin_id IS NULL THEN
        RAISE NOTICE 'Admin user admin.portal@gmail.com not found in auth.users. Please create the user in the Supabase Auth Dashboard first.';
    ELSE
        -- Insert or update public.users profile directly
        INSERT INTO public.users (
            id, 
            email, 
            full_name, 
            phone_number, 
            role, 
            account_status, 
            created_at, 
            updated_at
        )
        VALUES (
            v_admin_id, 
            'admin.portal@gmail.com', 
            'Admin Commander', 
            '09170000000', 
            'admin', 
            'active', 
            now(), 
            now()
        )
        ON CONFLICT (id) DO UPDATE
        SET email = EXCLUDED.email,
            full_name = EXCLUDED.full_name,
            role = 'admin',
            account_status = 'active',
            updated_at = now();
            
        RAISE NOTICE 'Admin account synchronized and verified successfully in public.users.';
    END IF;
END $$;
