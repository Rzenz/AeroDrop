-- ============================================================================
-- 33_vendor_alert_server_amount.sql
--
-- Migration 31 made place_order derive every stored amount from the database
-- and ignore p_subtotal, p_delivery_fee and p_total_amount. One line was
-- missed: the vendor's "New Customer Order!" notification still formats
-- p_total_amount -- the figure the CLIENT sent -- into its message text.
--
-- The stored order is correct either way, so this is a display defect rather
-- than a pricing one. It is still worth closing: a tampered or merely stale
-- client could make the vendor's alert read a different figure from the order
-- it refers to, and an operator who trusts the alert is trusting the one
-- number in the flow that nothing verifies.
--
-- SCOPE: cash orders only. For p_payment_method = 'xendit_online' the vendor
-- notification is deferred to the Xendit webhook, which reads total_amount
-- back from the orders row and is already correct.
--
-- METHOD
-- place_order is 300 lines and was last defined in migration 31. Rather than
-- restate it (and risk this file drifting from 31 as the source of truth),
-- this migration reads the function's live definition, asserts the exact text
-- it expects to find, and replaces it. If migration 31 was never applied, or
-- the function has since been edited, the anchor will not match and this
-- migration FAILS LOUDLY rather than silently doing nothing.
--
-- v_srv_total is already declared and assigned in the function (migration 31,
-- 'v_srv_total := (v_pricing->>''total_amount'')::numeric'), and it is the
-- same value written to orders.total_amount, so no new state is introduced.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-32.
-- ============================================================================

DO $migration$
DECLARE
    v_def     text;
    v_anchor  text := 'round(p_total_amount, 2)::text';
    v_fixed   text := 'round(v_srv_total, 2)::text';
    v_hits    integer;
BEGIN
    -- 1. Read the live definition.
    SELECT pg_get_functiondef(p.oid)
    INTO v_def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'place_order'
      AND pg_get_function_identity_arguments(p.oid) =
          'p_vendor_id uuid, p_delivery_location_id uuid, p_subtotal numeric, '
          'p_delivery_fee numeric, p_total_amount numeric, p_payment_method text, '
          'p_items jsonb, p_notes text';

    IF v_def IS NULL THEN
        RAISE EXCEPTION
            'place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text) not found. '
            'Apply migrations 01-32 before this one.';
    END IF;

    -- 2. The function must be the migration 31 version, which assigns
    --    v_srv_total. Without it the replacement would reference an
    --    undeclared variable and the function would fail at runtime.
    IF position('v_srv_total' IN v_def) = 0 THEN
        RAISE EXCEPTION
            'place_order does not declare v_srv_total, so migration 31 '
            '(server-side pricing) has not been applied. Apply it first.';
    END IF;

    -- 3. The anchor must appear exactly once: only the vendor notification
    --    formats the total into message text.
    v_hits := (length(v_def) - length(replace(v_def, v_anchor, ''))) / length(v_anchor);

    IF v_hits = 0 THEN
        RAISE NOTICE
            'Nothing to do: place_order no longer formats p_total_amount into '
            'the vendor notification. Migration 33 has already been applied, '
            'or the line was fixed by hand.';
        RETURN;
    END IF;

    IF v_hits > 1 THEN
        RAISE EXCEPTION
            'Expected one occurrence of %, found %. place_order has drifted '
            'from migration 31; patch it by hand instead of with this file.',
            v_anchor, v_hits;
    END IF;

    -- 4. Replace and reinstall.
    v_def := replace(v_def, v_anchor, v_fixed);
    EXECUTE v_def;

    RAISE NOTICE
        'place_order: vendor order alert now reports the server-derived total.';
END;
$migration$;

-- ----------------------------------------------------------------------------
-- Grants
--
-- pg_get_functiondef emits CREATE OR REPLACE, which preserves the existing
-- owner and privileges. These are restated so this file is self-sufficient if
-- it is ever replayed against a rebuilt project.
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text)
    FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text)
    TO authenticated;
