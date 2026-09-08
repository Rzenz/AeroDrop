-- 13_permanent_deletion.sql
-- Secure RPC function for Admin permanent user deletion & safe FK constraints

-- Function to permanently delete a user account from auth.users & public.users
CREATE OR REPLACE FUNCTION public.delete_user_account(p_target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
  -- 1. Check authenticated caller
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 2. Check admin role
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Only administrators can delete accounts';
  END IF;

  -- 3. Block self deletion
  IF auth.uid() = p_target_user_id THEN
    RAISE EXCEPTION 'You cannot delete your own administrator account.';
  END IF;

  -- 4. Delete target user from auth.users (this automatically cascades to public.users if FK is configured)
  DELETE FROM auth.users WHERE id = p_target_user_id;

  -- Fallback: Ensure public.users record is removed if no cascade happened
  DELETE FROM public.users WHERE id = p_target_user_id;
END;
$$;

-- Security & privileges
REVOKE ALL ON FUNCTION public.delete_user_account(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_user_account(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_user_account(uuid) TO authenticated;

-- Ensure public.users(id) references auth.users(id) with ON DELETE CASCADE
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = 'public.users'::regclass
          AND confrelid = 'auth.users'::regclass
    ) LOOP
        EXECUTE 'ALTER TABLE public.users DROP CONSTRAINT ' || quote_ident(r.conname);
    END LOOP;
    
    ALTER TABLE public.users
      ADD CONSTRAINT users_id_fkey
      FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Could not recreate users_id_fkey constraint: %', SQLERRM;
END $$;

-- Preserve historical records: set user_id to NULL on orders when user is deleted
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = 'public.orders'::regclass
          AND confrelid = 'public.users'::regclass
    ) LOOP
        EXECUTE 'ALTER TABLE public.orders DROP CONSTRAINT ' || quote_ident(r.conname);
    END LOOP;
    
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Could not recreate orders_user_id_fkey constraint: %', SQLERRM;
END $$;

-- Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';
