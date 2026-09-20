-- ============================================================
-- 13_RATINGS_VIEWS_SECURITY.SQL
-- Fix security_definer_view linter warnings on ratings summary views.
-- Recreates vendor_ratings_summary from store_reviews only.
-- Recreates product_ratings_summary from product_reviews only.
-- Both configured WITH (security_invoker = on).
-- REVOKE ALL from PUBLIC, anon; GRANT SELECT to authenticated.
-- (Already applied manually in the live database.)
-- ============================================================

BEGIN;

-- 1. Recreate vendor_ratings_summary from store_reviews only
CREATE OR REPLACE VIEW public.vendor_ratings_summary 
WITH (security_invoker = on) AS
SELECT 
    vendor_id,
    round(avg(rating)::numeric, 1) AS average_rating,
    count(id)::integer AS review_count
FROM public.store_reviews
GROUP BY vendor_id;

ALTER VIEW public.vendor_ratings_summary SET (security_invoker = on);
REVOKE ALL ON public.vendor_ratings_summary FROM PUBLIC, anon;
GRANT SELECT ON public.vendor_ratings_summary TO authenticated;

-- 2. Recreate product_ratings_summary from product_reviews only
CREATE OR REPLACE VIEW public.product_ratings_summary 
WITH (security_invoker = on) AS
SELECT 
    product_id,
    round(avg(rating)::numeric, 1) AS average_rating,
    count(id)::integer AS review_count
FROM public.product_reviews
GROUP BY product_id;

ALTER VIEW public.product_ratings_summary SET (security_invoker = on);
REVOKE ALL ON public.product_ratings_summary FROM PUBLIC, anon;
GRANT SELECT ON public.product_ratings_summary TO authenticated;

COMMIT;
