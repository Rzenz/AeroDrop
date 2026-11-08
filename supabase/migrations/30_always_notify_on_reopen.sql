-- ============================================================================
-- 30_always_notify_on_reopen.sql
--
-- Migration 28 collapses support notifications to one unread alert per report,
-- which is right for a back-and-forth: nobody wants five bell entries from one
-- conversation.
--
-- But it also swallowed the reopen alert. If an admin already had an unread
-- message alert for a ticket, a reporter reopening that ticket produced no new
-- notification at all -- and reopening is the agreed route for "this was
-- marked resolved but it is not fixed". The one alert that most needs to
-- arrive was the one most likely to be suppressed.
--
-- A reopen now always notifies. Ordinary replies collapse exactly as before.
--
-- Only that condition changes; the rest is the migration 28 definition.
-- ============================================================================

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
        --
        -- A REOPEN always notifies, bypassing the collapse check. Reopening is
        -- how a reporter says the fix did not work, so it is a status change
        -- rather than another line of conversation -- and it is precisely the
        -- alert that must not be swallowed because an admin happened to leave
        -- an earlier message alert unread. Ordinary replies still collapse to
        -- one unread alert per report.
        IF v_reopened OR NOT EXISTS (
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

REVOKE ALL ON FUNCTION public.handle_support_message_created() FROM PUBLIC, anon, authenticated;
