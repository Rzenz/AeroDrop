-- ============================================================================
-- 20_order_messages.sql
--
-- WHAT THIS ADDS
-- A per-order chat thread between the customer and the vendor, so they can
-- coordinate while an order is in progress (special instructions, "I'm at the
-- north gate", "the drone landed on the wrong side").
--
-- SCOPE DECISIONS
--   * Customer <-> vendor only. Admins can READ every thread (safety and
--     dispute handling) but cannot post, so they never appear to be either
--     party. Support requests to admins keep going through support_reports.
--   * Posting is allowed from the moment the order exists until it reaches
--     'delivered' or 'cancelled'. After that the thread becomes read-only, so
--     the history survives for disputes but the conversation is closed.
--   * Read receipts go through an RPC rather than an UPDATE policy, so the
--     table needs no UPDATE grant at all and nobody can rewrite a sent message.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-19:
--   public.orders (01): id, user_id -> public.users(id) ON DELETE SET NULL,
--       vendor_id -> public.users(id) ON DELETE SET NULL, order_status
--       (no CHECK constraint; values in use are pending, confirmed, preparing,
--        ready_for_delivery, in_transit, out_for_delivery, delivered, cancelled)
--   public.users (01): id -> auth.users(id), full_name, business_name, email
--   public.notifications (01 + 03): user_id -> public.users(id), title,
--       message, notification_type, is_read, related_delivery_id, metadata
--   public.is_admin() (01)
--   Realtime publication pattern copied from migration 11.
--
-- NOTE ON GRANTS
-- This is the first table created after Supabase stopped auto-granting Data
-- API access (2026-10-30, see migration 18). The grants at the bottom are
-- mandatory - without them every query here fails with "permission denied".
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.order_messages (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id   uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    sender_id  uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message    text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    read_at    timestamptz,
    CONSTRAINT order_messages_message_length
        CHECK (char_length(btrim(message)) BETWEEN 1 AND 1000)
);

CREATE INDEX IF NOT EXISTS idx_order_messages_order_created
    ON public.order_messages (order_id, created_at);

CREATE INDEX IF NOT EXISTS idx_order_messages_unread
    ON public.order_messages (order_id, sender_id)
    WHERE read_at IS NULL;

-- ----------------------------------------------------------------------------
-- 2. Row Level Security
--
-- Participation is decided by the parent order, never by a column on the
-- message itself, so a user cannot grant themselves access by forging a field.
-- ----------------------------------------------------------------------------
ALTER TABLE public.order_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS order_messages_select     ON public.order_messages;
DROP POLICY IF EXISTS order_messages_insert     ON public.order_messages;
DROP POLICY IF EXISTS order_messages_admin_read ON public.order_messages;

-- Participants read their own order's thread
CREATE POLICY order_messages_select ON public.order_messages
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.orders o
            WHERE o.id = order_messages.order_id
              AND (o.user_id = auth.uid() OR o.vendor_id = auth.uid())
        )
    );

-- Admins read every thread (safety / disputes). Read only: no insert policy
-- grants them posting rights.
CREATE POLICY order_messages_admin_read ON public.order_messages
    FOR SELECT TO authenticated
    USING (public.is_admin());

-- Participants post as themselves, while the order is still open
CREATE POLICY order_messages_insert ON public.order_messages
    FOR INSERT TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND EXISTS (
            SELECT 1
            FROM public.orders o
            WHERE o.id = order_messages.order_id
              AND (o.user_id = auth.uid() OR o.vendor_id = auth.uid())
              AND o.order_status NOT IN ('delivered', 'cancelled')
        )
    );

-- Deliberately no UPDATE or DELETE policy: a sent message is immutable, and
-- read receipts go through mark_order_messages_read() below.

-- ----------------------------------------------------------------------------
-- 3. Notify the other party about a new message
--
-- Collapsed: a recipient gets at most ONE unread 'order_message' notification
-- per order. Without this, a ten-message exchange would leave ten bell entries.
-- The notification is refreshed again only once the recipient has read it.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_order_message_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order        RECORD;
    v_recipient_id uuid;
    v_sender_name  text;
    v_short_id     text;
    v_preview      text;
BEGIN
    SELECT o.id, o.user_id, o.vendor_id
    INTO v_order
    FROM public.orders o
    WHERE o.id = NEW.order_id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- The recipient is whichever side of the order did not send this message
    IF NEW.sender_id = v_order.user_id THEN
        v_recipient_id := v_order.vendor_id;
    ELSIF NEW.sender_id = v_order.vendor_id THEN
        v_recipient_id := v_order.user_id;
    ELSE
        RETURN NEW;
    END IF;

    IF v_recipient_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT coalesce(
               nullif(btrim(u.business_name), ''),
               nullif(btrim(u.full_name), ''),
               u.email
           )
    INTO v_sender_name
    FROM public.users u
    WHERE u.id = NEW.sender_id;

    v_short_id := substring(NEW.order_id::text, 1, 8);

    v_preview := btrim(NEW.message);
    IF char_length(v_preview) > 80 THEN
        v_preview := substring(v_preview, 1, 77) || '...';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.notifications n
        WHERE n.user_id = v_recipient_id
          AND n.notification_type = 'order_message'
          AND n.is_read = false
          AND n.metadata->>'order_id' = NEW.order_id::text
    ) THEN
        INSERT INTO public.notifications (
            user_id, title, message, notification_type, metadata
        ) VALUES (
            v_recipient_id,
            'New message',
            coalesce(v_sender_name, 'Someone')
                || ' sent a message about order #' || v_short_id
                || ': "' || v_preview || '"',
            'order_message',
            jsonb_build_object(
                'order_id',   NEW.order_id,
                'message_id', NEW.id,
                'sender_id',  NEW.sender_id
            )
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_message_created ON public.order_messages;
CREATE TRIGGER trg_order_message_created
    AFTER INSERT ON public.order_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_order_message_created();

-- ----------------------------------------------------------------------------
-- 4. Read receipts
--
-- Marks every message in a thread that the caller did NOT send as read.
-- SECURITY DEFINER so the table needs no UPDATE grant; the participant check
-- is done here instead of in a policy.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_order_messages_read(p_order_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid     uuid := auth.uid();
    v_updated integer := 0;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.orders o
        WHERE o.id = p_order_id
          AND (o.user_id = v_uid OR o.vendor_id = v_uid)
    ) THEN
        RAISE EXCEPTION 'Not a participant in this order';
    END IF;

    UPDATE public.order_messages
    SET read_at = now()
    WHERE order_id = p_order_id
      AND sender_id <> v_uid
      AND read_at IS NULL;

    GET DIAGNOSTICS v_updated = ROW_COUNT;

    -- Clear the collapsed bell notification for this thread
    UPDATE public.notifications
    SET is_read = true,
        read_at = now()
    WHERE user_id = v_uid
      AND notification_type = 'order_message'
      AND is_read = false
      AND metadata->>'order_id' = p_order_id::text;

    RETURN v_updated;
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. Realtime (pattern from migration 11)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'order_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.order_messages;
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 6. Grants
--
-- Required explicitly: Supabase no longer auto-grants Data API access to new
-- public tables (see migration 18). No UPDATE and no DELETE: messages are
-- immutable, and read receipts go through mark_order_messages_read().
-- ----------------------------------------------------------------------------
GRANT SELECT, INSERT ON public.order_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.order_messages TO service_role;

REVOKE ALL ON FUNCTION public.handle_order_message_created() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.mark_order_messages_read(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.mark_order_messages_read(uuid) TO authenticated;
