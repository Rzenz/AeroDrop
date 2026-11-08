-- ============================================================================
-- 29_support_metadata_key.sql
--
-- One support report is identified by two different metadata keys, so opening
-- a thread does not clear every bell notification about it.
--
--   migration 19 writes  metadata->>'support_report_id'
--   migration 28 writes  metadata->>'report_id'   and matches only that
--
-- Migration 20 settled the convention with a single 'order_id' for order chat;
-- migration 28 followed it without noticing 19 had chosen another name first.
-- The effect: a reporter opens their thread, the support_message alert clears,
-- and the older "Report Submitted" / "Report Resolved" alerts stay unread for
-- ever.
--
-- Fixed from both ends:
--   1. The two migration 19 triggers now emit BOTH keys, so new notifications
--      carry 'report_id' like everything else. 'support_report_id' is kept so
--      nothing already written or already parsed breaks.
--   2. mark_support_messages_read() matches either key, which covers the rows
--      already in the table.
--
-- Only the metadata objects and that one WHERE clause change; the rest of each
-- function is its existing definition.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Emit both keys from the migration 19 triggers
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_support_report_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_short_id       text;
    v_reporter_name  text;
    v_category       text;
BEGIN
    v_short_id := substring(NEW.id::text, 1, 8);
    v_category := coalesce(nullif(trim(NEW.category), ''), 'general');

    SELECT coalesce(nullif(trim(u.full_name), ''), u.email)
    INTO v_reporter_name
    FROM public.users u
    WHERE u.id = NEW.user_id;

    -- Admin notification
    PERFORM public.notify_all_admins(
        'New Support Report',
        coalesce(v_reporter_name, 'A user')
            || ' submitted a ' || v_category || ' report: "'
            || NEW.subject || '" (#' || v_short_id || ').',
        'support_report',
        NEW.delivery_id,
        jsonb_build_object(
            'report_id',         NEW.id,
            'support_report_id', NEW.id,
            'reporter_id',       NEW.user_id,
            'category',          v_category,
            'order_id',          NEW.order_id,
            'delivery_id',       NEW.delivery_id,
            'status',            NEW.status
        )
    );

    -- Customer confirmation (guarded: see IMPORTANT FK NOTE above)
    IF EXISTS (SELECT 1 FROM public.users u WHERE u.id = NEW.user_id) THEN
        INSERT INTO public.notifications (
            user_id, title, message, notification_type,
            related_delivery_id, metadata
        ) VALUES (
            NEW.user_id,
            'Report Submitted',
            'We received your report "' || NEW.subject || '" (#' || v_short_id
                || '). Our support team will review it shortly.',
            'support_report',
            NEW.delivery_id,
            jsonb_build_object(
                'report_id',         NEW.id,
                'support_report_id', NEW.id,
                'category',          v_category,
                'status',            NEW.status
            )
        );
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_support_report_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_short_id text;
    v_title    text;
    v_message  text;
BEGIN
    IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
        RETURN NEW;
    END IF;

    v_short_id := substring(NEW.id::text, 1, 8);

    IF NEW.status = 'resolved' THEN
        v_title   := 'Report Resolved';
        v_message := 'Your report "' || NEW.subject || '" (#' || v_short_id
                     || ') has been resolved by our support team.';
    ELSIF NEW.status = 'open' THEN
        v_title   := 'Report Reopened';
        v_message := 'Your report "' || NEW.subject || '" (#' || v_short_id
                     || ') has been reopened and is being reviewed again.';
    ELSE
        v_title   := 'Report Updated';
        v_message := 'Your report "' || NEW.subject || '" (#' || v_short_id
                     || ') is now marked as ' || NEW.status || '.';
    END IF;

    -- Guarded: see IMPORTANT FK NOTE at the top of this file
    IF EXISTS (SELECT 1 FROM public.users u WHERE u.id = NEW.user_id) THEN
        INSERT INTO public.notifications (
            user_id, title, message, notification_type,
            related_delivery_id, metadata
        ) VALUES (
            NEW.user_id,
            v_title,
            v_message,
            'support_report_update',
            NEW.delivery_id,
            jsonb_build_object(
                'report_id',         NEW.id,
                'support_report_id', NEW.id,
                'status',            NEW.status,
                'previous_status',   OLD.status,
                'resolved_at',       NEW.resolved_at
            )
        );
    END IF;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_support_report_created()       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_support_report_status_change() FROM PUBLIC, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 2. Clear notifications written under either key
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
      AND coalesce(metadata->>'report_id', metadata->>'support_report_id')
          = p_report_id::text;

    RETURN v_updated;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_support_messages_read(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.mark_support_messages_read(uuid) TO authenticated;
