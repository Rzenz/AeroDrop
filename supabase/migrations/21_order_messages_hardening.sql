-- ============================================================================
-- 21_order_messages_hardening.sql
--
-- Three corrections to migration 20, found while building the chat UI.
--
-- 1. 'rejected' and 'failed' are real order statuses.
--    Migration 20 closed threads only for 'delivered' and 'cancelled', but the
--    app treats 'rejected' and 'failed' as terminal too:
--      lib/features/orders/orders_screen.dart:35  - groups them under Cancelled
--      lib/features/orders/order_details_screen.dart:896
--      lib/core/providers/delivery_provider.dart:563
--    A rejected order therefore kept an open chat. Now closed.
--
-- 2. A customer could chat on an order the vendor cannot see.
--    Migration 16 hides unpaid Xendit orders from the vendor:
--      orders_select: vendor_id = auth.uid()
--                     AND (payment_method != 'xendit_online' OR payment_status = 'paid')
--    So on an unpaid online order the customer could post, the migration 20
--    trigger would notify the vendor, and the vendor would tap through to an
--    order they are not allowed to open. Posting now requires the order to be
--    visible to both sides; the UI should say the chat opens once payment is
--    confirmed.
--
-- 3. Vendors cannot read customer names.
--    users_select (01_remote_baseline.sql:934) allows reading only yourself,
--    everything if you are an admin, or active vendor profiles. A vendor has
--    no route to a customer's full_name, so the vendor's chat header had no
--    name to show. Widening users_select would expose every customer to every
--    vendor, so instead this adds a narrow SECURITY DEFINER lookup that
--    returns just the counterpart of one order the caller participates in.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-20.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1 + 2. Replace the INSERT policy
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS order_messages_insert ON public.order_messages;

CREATE POLICY order_messages_insert ON public.order_messages
    FOR INSERT TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND EXISTS (
            SELECT 1
            FROM public.orders o
            WHERE o.id = order_messages.order_id
              AND (o.user_id = auth.uid() OR o.vendor_id = auth.uid())
              -- terminal statuses close the thread
              AND o.order_status NOT IN ('delivered', 'cancelled', 'rejected', 'failed')
              -- both parties must be able to see the order (mirrors orders_select
              -- as set by migration 16)
              AND (o.payment_method IS DISTINCT FROM 'xendit_online'
                   OR o.payment_status = 'paid')
        )
    );

-- ----------------------------------------------------------------------------
-- 3. Counterpart lookup for the chat header
--
-- Returns the other party on an order the caller participates in, and nothing
-- else. Admins get the customer's side so a read-only view still has a title.
-- Raises instead of returning an empty row, so the UI cannot silently show a
-- wrong name.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_order_counterpart(p_order_id uuid)
RETURNS TABLE (
    counterpart_id   uuid,
    display_name     text,
    counterpart_role text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid   uuid := auth.uid();
    v_order RECORD;
    v_target uuid;
    v_role   text;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT o.id, o.user_id, o.vendor_id
    INTO v_order
    FROM public.orders o
    WHERE o.id = p_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    IF v_uid = v_order.user_id THEN
        v_target := v_order.vendor_id;
        v_role   := 'vendor';
    ELSIF v_uid = v_order.vendor_id THEN
        v_target := v_order.user_id;
        v_role   := 'customer';
    ELSIF public.is_admin() THEN
        -- read-only admin view: show the customer
        v_target := v_order.user_id;
        v_role   := 'customer';
    ELSE
        RAISE EXCEPTION 'Not a participant in this order';
    END IF;

    IF v_target IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT u.id,
           coalesce(
               nullif(btrim(u.business_name), ''),
               nullif(btrim(u.full_name), ''),
               split_part(u.email, '@', 1)
           )::text,
           v_role
    FROM public.users u
    WHERE u.id = v_target;
END;
$$;

REVOKE ALL ON FUNCTION public.get_order_counterpart(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_order_counterpart(uuid) TO authenticated;
