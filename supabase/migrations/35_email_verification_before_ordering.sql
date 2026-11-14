-- ============================================================================
-- 35_email_verification_before_ordering.sql
--
-- An account can be used straight after sign-up, but it cannot place an
-- order until its email is verified with an emailed 6-digit code.
--
-- For sign-up to sign people in straight away, turn OFF Authentication →
-- Providers → Email → "Confirm email". Apply this migration FIRST: its
-- backfill treats every account confirmed so far as verified.
--
-- public.users.email_verified_at records the verification. It is set only by
-- the database, never by a client:
--   1. confirm_email_verified(): the website calls it right after the code is
--      entered. It accepts only a session that was itself created by an
--      emailed code (or Google), read from the JWT's "amr" claim.
--   2. Any new session created by an emailed code, a reset code or Google
--      (auth.mfa_amr_claims). This covers the app, which already asks for an
--      emailed code at every sign-in, without changing it.
--   3. An email confirmed through the "Confirm signup" code while that
--      setting is still on (auth.users.email_confirmed_at going from NULL).
--
-- A BEFORE INSERT trigger on orders refuses orders from unverified accounts,
-- so the rule holds for every client and for place_order alike.
-- ============================================================================

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS email_verified_at timestamptz;

COMMENT ON COLUMN public.users.email_verified_at IS
    'When the user proved they own their email with an emailed code (or Google). NULL = not verified: cannot order.';

-- Everyone who exists now signed up under "Confirm email" and entered a code.
UPDATE public.users u
SET email_verified_at = coalesce(a.email_confirmed_at, now())
FROM auth.users a
WHERE a.id = u.id
  AND a.email_confirmed_at IS NOT NULL
  AND u.email_verified_at IS NULL;

-- ----------------------------------------------------------------------------
-- Clients cannot set or clear the column themselves
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_email_verified_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Direct API writes run as anon/authenticated. SECURITY DEFINER functions
    -- (the ones below, handle_new_auth_user) run as their owner and pass.
    IF current_user IN ('anon', 'authenticated') THEN
        IF TG_OP = 'INSERT' THEN
            NEW.email_verified_at := NULL;
        ELSE
            NEW.email_verified_at := OLD.email_verified_at;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_email_verified_at ON public.users;
CREATE TRIGGER protect_email_verified_at
    BEFORE INSERT OR UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_email_verified_at();

-- ----------------------------------------------------------------------------
-- Shared setter
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_email_verified(p_user_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    UPDATE public.users
    SET email_verified_at = now()
    WHERE id = p_user_id
      AND email_verified_at IS NULL;
$$;

REVOKE ALL ON FUNCTION public.mark_email_verified(uuid) FROM PUBLIC, anon, authenticated;

-- Authentication methods that prove the person reads that inbox (or that
-- Google already verified it).
CREATE OR REPLACE FUNCTION public.is_email_proving_method(p_method text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT p_method IN ('otp', 'magiclink', 'email/signup', 'recovery', 'email_change', 'invite', 'oauth');
$$;

-- ----------------------------------------------------------------------------
-- 1. The website, right after the code is verified
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.confirm_email_verified()
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_at  timestamptz;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) AS e
        WHERE public.is_email_proving_method(e ->> 'method')
    ) THEN
        RAISE EXCEPTION 'Enter the code we emailed you to verify your email.';
    END IF;

    PERFORM public.mark_email_verified(v_uid);

    SELECT email_verified_at INTO v_at FROM public.users WHERE id = v_uid;
    RETURN v_at;
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_email_verified() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_email_verified() TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. Any session created by an emailed code or Google (covers the app)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.verify_email_from_session_claim()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF public.is_email_proving_method(NEW.authentication_method) THEN
        PERFORM public.mark_email_verified(s.user_id)
        FROM auth.sessions s
        WHERE s.id = NEW.session_id;
    END IF;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Never let bookkeeping stop someone signing in.
    RAISE WARNING 'verify_email_from_session_claim: %', SQLERRM;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.verify_email_from_session_claim() FROM PUBLIC, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 3. "Confirm signup" code entered while that setting is on
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.verify_email_on_auth_confirm()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM public.mark_email_verified(NEW.id);
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'verify_email_on_auth_confirm: %', SQLERRM;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.verify_email_on_auth_confirm() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS verify_email_on_auth_confirm ON auth.users;
CREATE TRIGGER verify_email_on_auth_confirm
    AFTER UPDATE OF email_confirmed_at ON auth.users
    FOR EACH ROW
    WHEN (OLD.email_confirmed_at IS NULL AND NEW.email_confirmed_at IS NOT NULL)
    EXECUTE FUNCTION public.verify_email_on_auth_confirm();

-- auth.mfa_amr_claims belongs to Supabase Auth. If this project's role cannot
-- add a trigger there, the website's confirm_email_verified() and the
-- email_confirmed_at trigger above still work; only app sign-ins stop
-- counting as verification.
DO $$
BEGIN
    DROP TRIGGER IF EXISTS verify_email_from_session_claim ON auth.mfa_amr_claims;
    CREATE TRIGGER verify_email_from_session_claim
        AFTER INSERT ON auth.mfa_amr_claims
        FOR EACH ROW
        EXECUTE FUNCTION public.verify_email_from_session_claim();
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Skipped the auth.mfa_amr_claims trigger: %', SQLERRM;
END;
$$;

-- ----------------------------------------------------------------------------
-- Orders need a verified email
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_verified_email_on_order()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.user_id IS NULL OR public.is_admin() THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = NEW.user_id
          AND u.email_verified_at IS NULL
    ) THEN
        RAISE EXCEPTION 'Verify your email before placing an order. Open your profile and choose Verify email.'
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_verified_email_on_order() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_order_requires_verified_email ON public.orders;
CREATE TRIGGER trg_order_requires_verified_email
    BEFORE INSERT ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_verified_email_on_order();
