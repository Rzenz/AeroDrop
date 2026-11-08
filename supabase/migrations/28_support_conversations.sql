-- ============================================================================
-- 28_support_conversations.sql
--
-- Turns support reports from a one-way form into a conversation.
--
-- Today a customer or vendor submits a report and never hears anything back
-- except a status change; migration 19 notifies them that it was resolved, but
-- there is nowhere to read a reply. This adds a message thread per report,
-- with up to three image attachments per message, so an admin can ask for a
-- photo of a damaged delivery and the reporter can send one.
--
-- DESIGN NOTES
--   * One thread per support_report. No new "conversation" table: the report
--     already is the conversation's subject, status and owner.
--   * A reporter posting on a RESOLVED report reopens it, rather than being
--     refused. A reply to "we fixed it" that nobody reads is worse than a
--     reopened ticket. Admin replies never reopen it.
--   * Attachments are storage paths on the message row itself, capped at three
--     by a CHECK, so the limit cannot be bypassed by a crafted client.
--   * The attachments bucket is PRIVATE, unlike vendor-logos and avatars.
--     A support photo may show a damaged order, a room, or a face; those
--     should not sit on a guessable public URL. The app reads them with
--     createSignedUrl().
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-27:
--   public.support_reports (07, 08): id, user_id -> auth.users(id), subject,
--       message, category, status ('open' default; app uses 'open'/'resolved'),
--       admin_notes, created_at, resolved_at, order_id, delivery_id
--   public.users (01): id, email, full_name, business_name, role
--   public.notifications (01, 03): user_id -> public.users(id), title, message,
--       notification_type, is_read, related_delivery_id, metadata
--   public.notify_all_admins(text, text, text, uuid, jsonb) (17)
--   public.is_admin() (01)
--   Storage policy shape copied from migration 09.
--
-- GRANTS ARE MANDATORY: Supabase stopped auto-granting Data API access to new
-- public tables on 2026-10-30 (see migration 18).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Record terms acceptance
--
-- The register screen has an "I agree" checkbox but nothing is stored, so the
-- system cannot show that a user ever accepted. One nullable column; existing
-- users stay NULL rather than being back-dated into a consent they never gave.
-- ----------------------------------------------------------------------------
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS terms_accepted_at timestamptz;

COMMENT ON COLUMN public.users.terms_accepted_at IS
    'When this user accepted the Terms and Privacy Policy. NULL means never recorded.';

-- ----------------------------------------------------------------------------
-- 2. Message thread
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.support_messages (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id   uuid NOT NULL REFERENCES public.support_reports(id) ON DELETE CASCADE,
    sender_id   uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message     text NOT NULL DEFAULT '',
    attachments text[] NOT NULL DEFAULT '{}',
    created_at  timestamptz NOT NULL DEFAULT now(),
    read_at     timestamptz,

    -- A message must carry something: words, a picture, or both.
    CONSTRAINT support_messages_not_empty
        CHECK (btrim(message) <> '' OR cardinality(attachments) > 0),
    CONSTRAINT support_messages_length
        CHECK (char_length(message) <= 2000),
    CONSTRAINT support_messages_attachment_limit
        CHECK (cardinality(attachments) <= 3)
);

CREATE INDEX IF NOT EXISTS idx_support_messages_report_created
    ON public.support_messages (report_id, created_at);

CREATE INDEX IF NOT EXISTS idx_support_messages_unread
    ON public.support_messages (report_id, sender_id)
    WHERE read_at IS NULL;

-- ----------------------------------------------------------------------------
-- 3. Row Level Security
--
-- Participation is decided by the parent report, never by a field on the
-- message, so a client cannot grant itself access by forging one.
-- ----------------------------------------------------------------------------
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS support_messages_select ON public.support_messages;
DROP POLICY IF EXISTS support_messages_insert ON public.support_messages;

CREATE POLICY support_messages_select ON public.support_messages
    FOR SELECT TO authenticated
    USING (
        public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.support_reports r
            WHERE r.id = support_messages.report_id
              AND r.user_id = auth.uid()
        )
    );

CREATE POLICY support_messages_insert ON public.support_messages
    FOR INSERT TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND (
            public.is_admin()
            OR EXISTS (
                SELECT 1 FROM public.support_reports r
                WHERE r.id = support_messages.report_id
                  AND r.user_id = auth.uid()
            )
        )
    );

-- No UPDATE or DELETE policy: a sent message is a record. Read receipts go
-- through mark_support_messages_read() below.

-- ----------------------------------------------------------------------------
-- 4. New message -> reopen if needed, then notify the other side
--
-- Notifications are collapsed to ONE unread alert per report per recipient,
-- the same way order chat does it, so a back-and-forth does not flood anyone.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_support_message_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_report      RECORD;
    v_sender_name text;
    v_sender_role text;
    v_short_id    text;
    v_preview     text;
    v_reopened    boolean := false;
BEGIN
    SELECT r.id, r.user_id, r.subject, r.status
    INTO v_report
    FROM public.support_reports r
    WHERE r.id = NEW.report_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    SELECT coalesce(nullif(btrim(u.business_name), ''),
                    nullif(btrim(u.full_name), ''),
                    split_part(u.email, '@', 1)),
           u.role
    INTO v_sender_name, v_sender_role
    FROM public.users u
    WHERE u.id = NEW.sender_id;

    v_short_id := substring(NEW.report_id::text, 1, 8);

    v_preview := btrim(NEW.message);
    IF v_preview = '' THEN
        v_preview := cardinality(NEW.attachments) || ' photo'
                     || CASE WHEN cardinality(NEW.attachments) = 1 THEN '' ELSE 's' END;
    ELSIF char_length(v_preview) > 80 THEN
        v_preview := substring(v_preview, 1, 77) || '...';
    END IF;

    -- A reporter replying to a resolved ticket reopens it. An admin replying
    -- does not, so closing remarks stay closing remarks.
    IF v_report.status = 'resolved' AND NEW.sender_id = v_report.user_id THEN
        UPDATE public.support_reports
        SET status = 'open',
            resolved_at = NULL
        WHERE id = NEW.report_id;
        v_reopened := true;
    END IF;

    IF NEW.sender_id = v_report.user_id THEN
        -- Reporter wrote: tell the admins.
        IF NOT EXISTS (
            SELECT 1
            FROM public.notifications n
            JOIN public.users u ON u.id = n.user_id AND u.role = 'admin'
            WHERE n.notification_type = 'support_message'
              AND n.is_read = false
              AND n.metadata->>'report_id' = NEW.report_id::text
        ) THEN
            PERFORM public.notify_all_admins(
                CASE WHEN v_reopened THEN 'Support ticket reopened'
                     ELSE 'New support message' END,
                coalesce(v_sender_name, 'A user') || ' replied on #' || v_short_id
                    || ' ("' || v_report.subject || '"): ' || v_preview,
                'support_message',
                NULL,
                jsonb_build_object(
                    'report_id',   NEW.report_id,
                    'message_id',  NEW.id,
                    'sender_id',   NEW.sender_id,
                    'reopened',    v_reopened
                )
            );
        END IF;
    ELSE
        -- Admin wrote: tell the reporter. Guarded, because
        -- support_reports.user_id references auth.users while
        -- notifications.user_id references public.users; a missing profile
        -- must cost a notification, never the message.
        IF EXISTS (SELECT 1 FROM public.users u WHERE u.id = v_report.user_id)
           AND NOT EXISTS (
               SELECT 1
               FROM public.notifications n
               WHERE n.user_id = v_report.user_id
                 AND n.notification_type = 'support_message'
                 AND n.is_read = false
                 AND n.metadata->>'report_id' = NEW.report_id::text
           )
        THEN
            INSERT INTO public.notifications (
                user_id, title, message, notification_type, metadata
            ) VALUES (
                v_report.user_id,
                'Support replied',
                'Support replied to your report #' || v_short_id
                    || ' ("' || v_report.subject || '"): ' || v_preview,
                'support_message',
                jsonb_build_object(
                    'report_id',  NEW.report_id,
                    'message_id', NEW.id,
                    'sender_id',  NEW.sender_id
                )
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_support_message_created ON public.support_messages;
CREATE TRIGGER trg_support_message_created
    AFTER INSERT ON public.support_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_support_message_created();

-- ----------------------------------------------------------------------------
-- 5. Read receipts
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_support_messages_read(p_report_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid      uuid := auth.uid();
    v_is_admin boolean;
    v_updated  integer := 0;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_is_admin := public.is_admin();

    IF NOT v_is_admin AND NOT EXISTS (
        SELECT 1 FROM public.support_reports r
        WHERE r.id = p_report_id AND r.user_id = v_uid
    ) THEN
        RAISE EXCEPTION 'Not a participant in this report';
    END IF;

    UPDATE public.support_messages
    SET read_at = now()
    WHERE report_id = p_report_id
      AND sender_id <> v_uid
      AND read_at IS NULL;

    GET DIAGNOSTICS v_updated = ROW_COUNT;

    UPDATE public.notifications
    SET is_read = true, read_at = now()
    WHERE user_id = v_uid
      AND notification_type IN ('support_message', 'support_report', 'support_report_update')
      AND is_read = false
      AND metadata->>'report_id' = p_report_id::text;

    RETURN v_updated;
END;
$$;

-- ----------------------------------------------------------------------------
-- 6. Realtime (pattern from migration 11)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'support_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.support_messages;
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 7. Attachment storage: PRIVATE bucket
--
-- Paths are '<report_id>/<uuid>.<ext>'. Keying on the report rather than the
-- uploader matters: both sides of a thread must see each other's photos, which
-- a per-user folder would prevent.
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('support-attachments', 'support-attachments', false)
ON CONFLICT (id) DO UPDATE SET public = false;

DROP POLICY IF EXISTS "Support attachments read" ON storage.objects;
CREATE POLICY "Support attachments read"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'support-attachments'
    AND (
        public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.support_reports r
            WHERE r.id::text = (storage.foldername(name))[1]
              AND r.user_id = auth.uid()
        )
    )
);

DROP POLICY IF EXISTS "Support attachments upload" ON storage.objects;
CREATE POLICY "Support attachments upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'support-attachments'
    AND (
        public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.support_reports r
            WHERE r.id::text = (storage.foldername(name))[1]
              AND r.user_id = auth.uid()
        )
    )
);

-- Deliberately no UPDATE or DELETE policy: an attachment on a support thread
-- is evidence, and the message rows referencing it are immutable too.

-- ----------------------------------------------------------------------------
-- 8. Grants (mandatory since 2026-10-30; see migration 18)
-- ----------------------------------------------------------------------------
GRANT SELECT, INSERT ON public.support_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.support_messages TO service_role;

REVOKE ALL ON FUNCTION public.handle_support_message_created() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.mark_support_messages_read(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.mark_support_messages_read(uuid) TO authenticated;
