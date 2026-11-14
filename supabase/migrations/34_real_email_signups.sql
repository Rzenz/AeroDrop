-- ============================================================================
-- 34_real_email_signups.sql
--
-- Accounts must use a real, existing email address.
--
-- Three layers, from cheapest to strongest:
--   1. The app and the website call the check-email Edge Function before
--      signing up. It rejects malformed addresses, domains that do not exist
--      or cannot receive mail (DNS MX lookup), throwaway inboxes and common
--      typos ("gmial.com"), with a message the form can show.
--   2. This migration refuses the same throwaway and typo domains inside the
--      database, so an account cannot be made by calling the auth API
--      directly and skipping the clients.
--   3. The emailed 6-digit code (unchanged) proves the inbox is real: an
--      account cannot sign in until it is entered.
--
-- blocked_email_domains is the one list both the trigger and the Edge
-- Function read. Add a row to block another domain; a blocked domain also
-- blocks its subdomains.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.blocked_email_domains (
    domain      text PRIMARY KEY CHECK (domain = lower(btrim(domain)) AND domain <> ''),
    reason      text NOT NULL DEFAULT 'disposable' CHECK (reason IN ('disposable', 'typo')),
    -- For typos: the domain the person most likely meant.
    suggestion  text,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- Read only by the trigger (SECURITY DEFINER) and the Edge Function
-- (service role). No client reads or writes it.
ALTER TABLE public.blocked_email_domains ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.blocked_email_domains FROM PUBLIC, anon, authenticated;

INSERT INTO public.blocked_email_domains (domain, reason, suggestion) VALUES
    -- Disposable inboxes
    ('mailinator.com', 'disposable', NULL),
    ('guerrillamail.com', 'disposable', NULL),
    ('guerrillamail.net', 'disposable', NULL),
    ('guerrillamail.org', 'disposable', NULL),
    ('guerrillamailblock.com', 'disposable', NULL),
    ('sharklasers.com', 'disposable', NULL),
    ('grr.la', 'disposable', NULL),
    ('10minutemail.com', 'disposable', NULL),
    ('10minutemail.net', 'disposable', NULL),
    ('temp-mail.org', 'disposable', NULL),
    ('temp-mail.io', 'disposable', NULL),
    ('tempmail.com', 'disposable', NULL),
    ('tempmail.net', 'disposable', NULL),
    ('tempmailo.com', 'disposable', NULL),
    ('tempail.com', 'disposable', NULL),
    ('tempinbox.com', 'disposable', NULL),
    ('tempr.email', 'disposable', NULL),
    ('tmpmail.org', 'disposable', NULL),
    ('tmpmail.net', 'disposable', NULL),
    ('yopmail.com', 'disposable', NULL),
    ('yopmail.net', 'disposable', NULL),
    ('yopmail.fr', 'disposable', NULL),
    ('trashmail.com', 'disposable', NULL),
    ('trashmail.net', 'disposable', NULL),
    ('getnada.com', 'disposable', NULL),
    ('nada.email', 'disposable', NULL),
    ('dispostable.com', 'disposable', NULL),
    ('maildrop.cc', 'disposable', NULL),
    ('throwawaymail.com', 'disposable', NULL),
    ('fakeinbox.com', 'disposable', NULL),
    ('fakemail.net', 'disposable', NULL),
    ('emailfake.com', 'disposable', NULL),
    ('mintemail.com', 'disposable', NULL),
    ('mohmal.com', 'disposable', NULL),
    ('emailondeck.com', 'disposable', NULL),
    ('mailnesia.com', 'disposable', NULL),
    ('spamgourmet.com', 'disposable', NULL),
    ('burnermail.io', 'disposable', NULL),
    ('moakt.com', 'disposable', NULL),
    ('mail.tm', 'disposable', NULL),
    ('mail.gw', 'disposable', NULL),
    ('mytemp.email', 'disposable', NULL),
    ('discard.email', 'disposable', NULL),
    ('inboxkitten.com', 'disposable', NULL),
    ('mailpoof.com', 'disposable', NULL),
    ('minuteinbox.com', 'disposable', NULL),
    ('mailcatch.com', 'disposable', NULL),
    ('dropmail.me', 'disposable', NULL),
    ('emailtemporanea.net', 'disposable', NULL),
    ('spam4.me', 'disposable', NULL),
    -- Common typos of real providers
    ('gmial.com', 'typo', 'gmail.com'),
    ('gmai.com', 'typo', 'gmail.com'),
    ('gamil.com', 'typo', 'gmail.com'),
    ('gmal.com', 'typo', 'gmail.com'),
    ('gnail.com', 'typo', 'gmail.com'),
    ('gmaill.com', 'typo', 'gmail.com'),
    ('gmail.co', 'typo', 'gmail.com'),
    ('gmail.con', 'typo', 'gmail.com'),
    ('gmail.cm', 'typo', 'gmail.com'),
    ('gmail.om', 'typo', 'gmail.com'),
    ('yaho.com', 'typo', 'yahoo.com'),
    ('yahooo.com', 'typo', 'yahoo.com'),
    ('yahoo.con', 'typo', 'yahoo.com'),
    ('yhoo.com', 'typo', 'yahoo.com'),
    ('hotmial.com', 'typo', 'hotmail.com'),
    ('hotmal.com', 'typo', 'hotmail.com'),
    ('hotmai.com', 'typo', 'hotmail.com'),
    ('hotmail.con', 'typo', 'hotmail.com'),
    ('outlok.com', 'typo', 'outlook.com'),
    ('outllok.com', 'typo', 'outlook.com'),
    ('outlook.con', 'typo', 'outlook.com'),
    ('iclod.com', 'typo', 'icloud.com'),
    ('icloud.con', 'typo', 'icloud.com')
ON CONFLICT (domain) DO NOTHING;

-- ----------------------------------------------------------------------------
-- The domain (or a parent domain) of an address, if it is blocked.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.blocked_email_domain(p_email text)
RETURNS public.blocked_email_domains
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT b.*
    FROM public.blocked_email_domains b
    WHERE lower(split_part(btrim(p_email), '@', 2)) = b.domain
       OR lower(split_part(btrim(p_email), '@', 2)) LIKE '%.' || b.domain
    ORDER BY length(b.domain) DESC
    LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.blocked_email_domain(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.blocked_email_domain(text) TO service_role;

-- ----------------------------------------------------------------------------
-- Refuse blocked domains when an auth account is created or its email
-- changes. Auth reports the failure to the client as
-- "Database error saving new user"; both clients explain it.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_real_email_domain()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_blocked public.blocked_email_domains;
BEGIN
    -- Phone-only accounts have no email.
    IF NEW.email IS NULL OR btrim(NEW.email) = '' THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.email IS NOT DISTINCT FROM OLD.email THEN
        RETURN NEW;
    END IF;

    v_blocked := public.blocked_email_domain(NEW.email);
    IF v_blocked.domain IS NOT NULL THEN
        RAISE EXCEPTION 'Email domain % is not accepted (%).', v_blocked.domain, v_blocked.reason
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_real_email_domain() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS enforce_real_email_domain ON auth.users;
CREATE TRIGGER enforce_real_email_domain
    BEFORE INSERT OR UPDATE OF email ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_real_email_domain();
