-- ============================================================================
-- 19_support_report_notifications.sql
--
-- WHY THIS EXISTS
-- Migration 17 wired admin notifications for vendor applications, deliveries,
-- order cancellations, weather changes and drone battery - but not for support
-- reports. A customer could file a report and no admin was told; the only way
-- to find it was to open the admin Support screen. The customer likewise got
-- no confirmation that the report was received, and no word when it was
-- resolved.
--
-- This migration adds three notifications:
--   1. Admins, when a customer submits a report.
--   2. The customer, confirming the report was received.
--   3. The customer, when an admin resolves or reopens it.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-18:
--   public.support_reports (07, extended in 08):
--       id, user_id -> auth.users(id), subject, message, category,
--       status ('open' default; app uses 'open' and 'resolved'),
--       admin_notes, created_at, resolved_at, order_id, delivery_id
--   public.notifications (01, extended in 03):
--       id, user_id -> public.users(id), title, message, notification_type,
--       is_read, created_at, read_at, related_delivery_id, metadata
--       (notification_type has no CHECK constraint; the Flutter model treats
--        it as free text and falls back to 'info', so new values are safe)
--   public.notify_all_admins(text, text, text, uuid, jsonb) from 17
--
-- IMPORTANT FK NOTE
-- support_reports.user_id references auth.users(id), but notifications.user_id
-- references public.users(id). Those are normally the same id, but if a row is
-- ever missing from public.users the notification INSERT would raise a foreign
-- key violation and roll back the customer's report submission. Both triggers
-- therefore guard the customer notification with an EXISTS check: a missing
-- profile costs the notification, never the report itself.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. New report submitted -> notify all admins + confirm to the customer
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
                'support_report_id', NEW.id,
                'category',          v_category,
                'status',            NEW.status
            )
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_support_report_created ON public.support_reports;
CREATE TRIGGER trg_support_report_created
    AFTER INSERT ON public.support_reports
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_support_report_created();

-- ----------------------------------------------------------------------------
-- 2. Status changed by an admin -> notify the customer who filed it
--
-- Fires only when status actually changes, so editing admin_notes alone does
-- not spam the customer.
-- ----------------------------------------------------------------------------
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

DROP TRIGGER IF EXISTS trg_support_report_status_change ON public.support_reports;
CREATE TRIGGER trg_support_report_status_change
    AFTER UPDATE OF status ON public.support_reports
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_support_report_status_change();

-- ----------------------------------------------------------------------------
-- 3. Permissions
--
-- These are trigger functions; they are never called directly over the Data
-- API. Revoking EXECUTE keeps them off the RPC surface, matching how
-- migration 17 locked down notify_all_admins. The triggers still run, because
-- a SECURITY DEFINER function executes with its owner's privileges.
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.handle_support_report_created()       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_support_report_status_change() FROM PUBLIC, anon, authenticated;
