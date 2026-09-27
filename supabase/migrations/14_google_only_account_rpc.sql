-- ============================================================
-- 14_GOOGLE_ONLY_ACCOUNT_RPC.SQL
-- Securely check whether an email belongs to a Google-only account
-- (registered via Google OAuth without an email password identity).
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.check_google_only_account(p_email text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_clean_email text;
    v_has_password boolean := false;
    v_has_google boolean := false;
    v_user_id uuid;
BEGIN
    v_clean_email := lower(trim(p_email));
    IF v_clean_email IS NULL OR v_clean_email = '' THEN
        RETURN false;
    END IF;

    -- Look up user in auth.users by normalized email
    SELECT id INTO v_user_id
    FROM auth.users
    WHERE lower(email) = v_clean_email
    LIMIT 1;

    IF v_user_id IS NULL THEN
        RETURN false;
    END IF;

    -- Check if user has an email identity or non-empty encrypted password
    SELECT 
        EXISTS (
            SELECT 1 FROM auth.identities 
            WHERE user_id = v_user_id AND provider = 'email'
        ) OR (
            encrypted_password IS NOT NULL AND encrypted_password <> ''
        )
    INTO v_has_password
    FROM auth.users
    WHERE id = v_user_id;

    -- Check if user has a google identity or google in app metadata
    SELECT 
        EXISTS (
            SELECT 1 FROM auth.identities 
            WHERE user_id = v_user_id AND provider = 'google'
        ) OR (
            raw_app_meta_data->>'provider' = 'google'
            OR (raw_app_meta_data->'providers')::text LIKE '%google%'
        )
    INTO v_has_google
    FROM auth.users
    WHERE id = v_user_id;

    -- Return true ONLY if they have Google AND do NOT have a password
    RETURN v_has_google AND NOT v_has_password;
END;
$$;

REVOKE ALL ON FUNCTION public.check_google_only_account(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_google_only_account(text) TO anon, authenticated;

COMMIT;
