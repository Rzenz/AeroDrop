-- ============================================================================
-- 32_rate_limits.sql
--
-- Nothing currently stops one signed-in account placing hundreds of orders,
-- filing hundreds of tickets, or uploading attachments in a loop. Each of
-- those costs the system something real: reserved stock, an administrator's
-- attention, storage.
--
-- Enforced with BEFORE INSERT triggers rather than inside the RPCs, so the
-- limit holds no matter which client, which function, or which hand-crafted
-- request creates the row.
--
-- LIMITS are set well above honest use, including a demo where several orders
-- are placed in a row. They are there to stop a loop, not to ration people.
--
--   orders            10 per 10 minutes   (place_order is the only writer)
--   support_reports    5 per hour
--   support_messages  40 per 10 minutes
--   order_messages    40 per 10 minutes
--
-- Administrators are exempt: an admin working through a support queue can
-- legitimately send many messages in a short burst, and admin accounts are
-- created by hand rather than signed up for.
--
-- auth.uid() is readable inside a trigger even when the insert arrives through
-- a SECURITY DEFINER function, because it reads a request-scoped JWT claim
-- rather than the executing role.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-31:
--   public.orders.user_id, public.support_reports.user_id,
--   public.support_messages.sender_id, public.order_messages.sender_id,
--   public.is_admin()
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Orders
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_order_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    c_max    constant integer  := 10;
    c_window constant interval := interval '10 minutes';
    v_recent integer;
BEGIN
    IF NEW.user_id IS NULL OR public.is_admin() THEN
        RETURN NEW;
    END IF;

    SELECT count(*) INTO v_recent
    FROM public.orders
    WHERE user_id = NEW.user_id
      AND created_at > now() - c_window;

    IF v_recent >= c_max THEN
        RAISE EXCEPTION
            'Too many orders placed in a short time. Please wait a few minutes before ordering again.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_rate_limit ON public.orders;
CREATE TRIGGER trg_order_rate_limit
    BEFORE INSERT ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_order_rate_limit();

-- ----------------------------------------------------------------------------
-- 2. Support reports
--
-- The tightest limit of the four: each new report is a separate item in an
-- administrator's queue, and a reporter with an ongoing problem should be
-- replying in their existing thread rather than opening another ticket.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_support_report_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    c_max    constant integer  := 5;
    c_window constant interval := interval '1 hour';
    v_recent integer;
BEGIN
    IF NEW.user_id IS NULL OR public.is_admin() THEN
        RETURN NEW;
    END IF;

    SELECT count(*) INTO v_recent
    FROM public.support_reports
    WHERE user_id = NEW.user_id
      AND created_at > now() - c_window;

    IF v_recent >= c_max THEN
        RAISE EXCEPTION
            'Too many support reports filed in the last hour. Please reply in an existing report, or try again later.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_support_report_rate_limit ON public.support_reports;
CREATE TRIGGER trg_support_report_rate_limit
    BEFORE INSERT ON public.support_reports
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_support_report_rate_limit();

-- ----------------------------------------------------------------------------
-- 3. Support messages
--
-- Also the attachment limit in practice: every image belongs to a message, and
-- a message carries at most three.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_support_message_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    c_max    constant integer  := 40;
    c_window constant interval := interval '10 minutes';
    v_recent integer;
BEGIN
    IF NEW.sender_id IS NULL OR public.is_admin() THEN
        RETURN NEW;
    END IF;

    SELECT count(*) INTO v_recent
    FROM public.support_messages
    WHERE sender_id = NEW.sender_id
      AND created_at > now() - c_window;

    IF v_recent >= c_max THEN
        RAISE EXCEPTION
            'Too many messages sent in a short time. Please wait a moment before sending again.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_support_message_rate_limit ON public.support_messages;
CREATE TRIGGER trg_support_message_rate_limit
    BEFORE INSERT ON public.support_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_support_message_rate_limit();

-- ----------------------------------------------------------------------------
-- 4. Order chat
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_order_message_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    c_max    constant integer  := 40;
    c_window constant interval := interval '10 minutes';
    v_recent integer;
BEGIN
    IF NEW.sender_id IS NULL OR public.is_admin() THEN
        RETURN NEW;
    END IF;

    SELECT count(*) INTO v_recent
    FROM public.order_messages
    WHERE sender_id = NEW.sender_id
      AND created_at > now() - c_window;

    IF v_recent >= c_max THEN
        RAISE EXCEPTION
            'Too many messages sent in a short time. Please wait a moment before sending again.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_message_rate_limit ON public.order_messages;
CREATE TRIGGER trg_order_message_rate_limit
    BEFORE INSERT ON public.order_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_order_message_rate_limit();

-- ----------------------------------------------------------------------------
-- 5. Indexes
--
-- Each trigger counts recent rows for one account. Without these the count is
-- a sequential scan that gets slower as the table grows, on the hot path of
-- every order and every message.
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_orders_user_created
    ON public.orders (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_support_reports_user_created
    ON public.support_reports (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_support_messages_sender_created
    ON public.support_messages (sender_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_messages_sender_created
    ON public.order_messages (sender_id, created_at DESC);

-- ----------------------------------------------------------------------------
-- 6. Grants
--
-- Trigger functions; never called over the Data API.
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.enforce_order_rate_limit()           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enforce_support_report_rate_limit()  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enforce_support_message_rate_limit() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enforce_order_message_rate_limit()   FROM PUBLIC, anon, authenticated;
