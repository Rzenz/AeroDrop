-- ============================================================================
-- 36_signup_is_not_proof.sql
--
-- Migration 35 counts 'email/signup' as proof that someone owns their email.
-- That holds only while Authentication -> Sign In / Providers -> Email ->
-- "Confirm email" is ON, because then the session exists only after a code
-- was entered.
--
-- That setting is now OFF -- migration 35's own header asks for it, so the
-- account can be used straight after sign-up. With it off, Supabase creates
-- the session immediately and records an 'email/signup' claim, the
-- verify_email_from_session_claim trigger fires, and the account is marked
-- verified before a single email has been sent.
--
-- Result: every new account verified itself, and the order gate let everyone
-- through. The feature was inert.
--
-- THE FIX
-- Drop 'email/signup' from the proving methods. The remaining six all involve
-- the person reading something that arrived at that address:
--
--   otp, magiclink   a 6-digit code emailed to it   <- the Verify email flow
--   recovery         a password-reset code emailed to it
--   email_change     a code emailed to the new address
--   invite           an invitation emailed to it
--   oauth            Google already verified it
--
-- NOTHING IS LOST IF "Confirm email" IS TURNED BACK ON. That case is covered
-- by migration 35's third path, verify_email_on_auth_confirm, which fires when
-- auth.users.email_confirmed_at goes from NULL to a value -- exactly what
-- entering the signup code does. 'email/signup' was only ever a second route
-- to the same place.
--
-- Accounts already marked verified are LEFT ALONE. Every account that existed
-- before migration 35 was deliberately backfilled as verified, and this
-- migration cannot tell those apart from ones the bug waved through. Reset a
-- specific test account by hand instead -- the query is at the bottom,
-- commented out.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-35.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.is_email_proving_method(p_method text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT p_method IN ('otp', 'magiclink', 'recovery', 'email_change', 'invite', 'oauth');
$$;

COMMENT ON FUNCTION public.is_email_proving_method(text) IS
    'Authentication methods that prove the person reads that inbox. '
    'Excludes email/signup: with "Confirm email" off, a sign-up session is '
    'created before any email is sent, so it proves nothing. A sign-up code '
    'entered while that setting is on is handled by verify_email_on_auth_confirm.';

-- ----------------------------------------------------------------------------
-- Un-verify one account so the flow can be tested end to end.
--
-- Uncomment, put the address in, and run it on its own. It only clears the
-- flag; the account keeps its password, its orders and everything else, and
-- the Verify email button will set the flag again properly.
-- ----------------------------------------------------------------------------
-- UPDATE public.users
-- SET email_verified_at = NULL
-- WHERE lower(email) = lower('put.the.address@here.com');
