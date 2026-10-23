-- ============================================================================
-- 22_order_counterpart_avatar.sql
--
-- Adds the counterpart's avatar to get_order_counterpart(), so the chat can
-- show a profile picture next to incoming messages.
--
-- WHY A MIGRATION IS NEEDED FOR A PICTURE
-- users_select (01_remote_baseline.sql:934) lets an authenticated user read
-- only their own row, every row if they are an admin, or active vendor
-- profiles. A vendor therefore cannot read a customer's avatar_url any more
-- than they can read their full_name. Migration 21 solved the name with this
-- SECURITY DEFINER lookup; the avatar has to travel the same way.
--
-- WHY DROP AND RECREATE
-- PostgreSQL cannot CREATE OR REPLACE a function whose OUT columns change, so
-- the old three-column version is dropped first. Nothing else depends on it.
--
-- IMAGE SOURCE PER ROLE
--   vendor   -> business_logo_url, falling back to avatar_url
--   customer -> avatar_url
-- Both live in storage buckets that migration 09 marked public, so the URLs
-- render without a signed request.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-21:
--   public.users (01): id, email, full_name, business_name,
--                      business_logo_url, avatar_url
--   public.orders (01): id, user_id, vendor_id
--   public.is_admin() (01)
-- ============================================================================

DROP FUNCTION IF EXISTS public.get_order_counterpart(uuid);

CREATE FUNCTION public.get_order_counterpart(p_order_id uuid)
RETURNS TABLE (
    counterpart_id   uuid,
    display_name     text,
    counterpart_role text,
    avatar_url       text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid    uuid := auth.uid();
    v_order  RECORD;
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
           v_role,
           CASE
               WHEN v_role = 'vendor' THEN
                   coalesce(
                       nullif(btrim(u.business_logo_url), ''),
                       nullif(btrim(u.avatar_url), '')
                   )
               ELSE
                   nullif(btrim(u.avatar_url), '')
           END::text
    FROM public.users u
    WHERE u.id = v_target;
END;
$$;

REVOKE ALL ON FUNCTION public.get_order_counterpart(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_order_counterpart(uuid) TO authenticated;
