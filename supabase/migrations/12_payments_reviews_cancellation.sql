-- ============================================================
-- 12_PAYMENTS_REVIEWS_CANCELLATION.SQL
-- 1. Card simulated payments + refund triggers for GCash & Card.
-- 2. Cancellation rule RPC (pending/confirmed/preparing only)
--    with row locking; drop direct customer orders update policy.
-- 3. Store and product reviews & rating summaries (writes via
--    submit_order_reviews RPC only; SELECT for authenticated).
-- ============================================================

BEGIN;

-- ============================================================
-- PART 1: PAYMENT METHOD CONSTRAINT & REFUND TRIGGERS
-- ============================================================

-- 1.1 Update payment_method CHECK constraint on public.orders
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_method_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_payment_method_check
    CHECK (payment_method IS NULL OR payment_method IN
           ('gcash_simulated', 'card_simulated', 'cash_on_delivery', 'cash'));

-- 1.2 Update handle_order_cancellation_before to refund both GCash & Card
CREATE OR REPLACE FUNCTION public.handle_order_cancellation_before()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF (NEW.order_status IN ('cancelled', 'rejected') 
        AND (OLD.order_status IS NULL OR OLD.order_status NOT IN ('cancelled', 'rejected')))
    THEN
        IF NEW.payment_method IN ('gcash_simulated', 'card_simulated') AND NEW.payment_status = 'paid' THEN
            NEW.payment_status := 'refunded';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- 1.3 Update handle_order_status_notifications to include refund text for both GCash & Card
CREATE OR REPLACE FUNCTION public.handle_order_status_notifications()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_short_id text;
    v_refund_text text := '';
    v_cust_msg text;
    v_vend_msg text;
BEGIN
    IF NEW.order_status IS DISTINCT FROM OLD.order_status THEN
        v_short_id := substring(NEW.id::text, 1, 8);

        IF NEW.order_status = 'confirmed' THEN
            INSERT INTO public.notifications (
                id, user_id, title, message, notification_type, is_read, created_at
            ) VALUES (
                gen_random_uuid(),
                NEW.user_id,
                'Order Confirmed',
                'The vendor has accepted your order.',
                'order_confirmed',
                false,
                now()
            );
        ELSIF NEW.order_status = 'preparing' THEN
            INSERT INTO public.notifications (
                id, user_id, title, message, notification_type, is_read, created_at
            ) VALUES (
                gen_random_uuid(),
                NEW.user_id,
                'Preparing Your Order',
                'The vendor is now preparing your items.',
                'order_preparing',
                false,
                now()
            );
        ELSIF NEW.order_status IN ('cancelled', 'rejected') THEN
            IF NEW.payment_method IN ('gcash_simulated', 'card_simulated') AND NEW.payment_status = 'refunded' THEN
                v_refund_text := ' Your payment will be refunded.';
            END IF;

            IF NEW.cancellation_reason = 'weather_grounded' THEN
                v_cust_msg := 'Weather is currently unsafe for drone delivery. Your order #' || v_short_id || ' was cancelled.' || v_refund_text;
                v_vend_msg := 'Weather is currently unsafe for drone delivery. Order #' || v_short_id || ' was cancelled.';
            ELSIF NEW.cancellation_reason = 'customer' THEN
                v_cust_msg := 'Your order #' || v_short_id || ' has been cancelled.' || v_refund_text;
                v_vend_msg := 'Order #' || v_short_id || ' was cancelled by the customer.';
            ELSE
                v_cust_msg := 'Your order has been cancelled.' || v_refund_text;
                v_vend_msg := 'An order has been cancelled.';
            END IF;

            -- Customer Notification
            INSERT INTO public.notifications (
                id, user_id, title, message, notification_type, is_read, created_at
            ) VALUES (
                gen_random_uuid(),
                NEW.user_id,
                'Order Cancelled',
                v_cust_msg,
                'order_cancelled',
                false,
                now()
            );

            -- Vendor Notification
            IF NEW.vendor_id IS NOT NULL THEN
                INSERT INTO public.notifications (
                    id, user_id, title, message, notification_type, is_read, created_at
                ) VALUES (
                    gen_random_uuid(),
                    NEW.vendor_id,
                    'Order Cancelled',
                    v_vend_msg,
                    'order_cancelled',
                    false,
                    now()
                );
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- 1.4 Update place_order to reject payment methods other than gcash_simulated / card_simulated
CREATE OR REPLACE FUNCTION public.place_order(
    p_vendor_id uuid,
    p_delivery_location_id uuid,
    p_subtotal numeric,
    p_delivery_fee numeric,
    p_total_amount numeric,
    p_payment_method text,
    p_items jsonb,
    p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_caller_id uuid;
    v_order_id uuid;
    v_item jsonb;
    v_product_id uuid;
    v_quantity integer;
    v_unit_price numeric;
    v_item_subtotal numeric;
    v_product_name text;
    v_stock integer;
    v_weight_grams integer;
    v_total_weight_grams integer := 0;
    v_payment_status text;
    v_payment_ref text;
    v_remaining_stock integer;
    v_weather_status text;
    v_weather_msg text;
BEGIN
    -- 0. Check Weather Safety (Blocked if Grounded)
    SELECT safety_status, message INTO v_weather_status, v_weather_msg
    FROM public.weather_safety
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_weather_status = 'grounded' THEN
        RAISE EXCEPTION 'Ordering blocked: %', coalesce(v_weather_msg, 'Campus drone delivery is currently grounded due to unsafe weather.');
    END IF;

    -- 1. Require authenticated user
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Validate payment method for new orders
    IF p_payment_method IS NULL OR p_payment_method NOT IN ('gcash_simulated', 'card_simulated') THEN
        RAISE EXCEPTION 'Invalid payment method. New orders must be paid via GCash or Card.';
    END IF;

    -- Validate items array
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Order contains no items';
    END IF;

    -- 2. First pass: Lock product rows, validate stock & calculate total payload weight
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity := (v_item->>'quantity')::integer;

        IF v_quantity <= 0 THEN
            RAISE EXCEPTION 'Quantity must be greater than zero';
        END IF;

        -- Lock the product row FOR UPDATE to prevent race conditions
        SELECT 
            name, 
            coalesce(stock_quantity, 0), 
            coalesce(weight_grams, 0)
        INTO 
            v_product_name, 
            v_stock, 
            v_weight_grams
        FROM public.products
        WHERE id = v_product_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Product not found: %', v_product_id;
        END IF;

        -- Check stock sufficiency
        IF v_stock < v_quantity THEN
            RAISE EXCEPTION 'Not enough stock available for %. Only % item(s) remaining.', v_product_name, v_stock;
        END IF;

        -- Accumulate total cargo weight
        v_total_weight_grams := v_total_weight_grams + (v_weight_grams * v_quantity);
    END LOOP;

    -- 3. Drone maximum payload check (0.5 kg = 500 grams)
    IF v_total_weight_grams > 500 THEN
        RAISE EXCEPTION 'This order exceeds the drone''s maximum payload of 0.5 kg. Your order weighs % kg.', round((v_total_weight_grams::numeric / 1000.0), 2);
    END IF;

    -- 4. Second pass: Deduct stock for all products & trigger low/out of stock alerts
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity := (v_item->>'quantity')::integer;

        UPDATE public.products
        SET 
            stock_quantity = stock_quantity - v_quantity,
            updated_at = now()
        WHERE id = v_product_id
        RETURNING stock_quantity, name INTO v_remaining_stock, v_product_name;

        -- Vendor inventory alerts
        IF v_remaining_stock <= 0 THEN
            INSERT INTO public.notifications (
                id, user_id, title, message, notification_type, is_read, created_at
            ) VALUES (
                gen_random_uuid(),
                p_vendor_id,
                'Out of Stock Alert',
                v_product_name || ' is now out of stock.',
                'stock_out',
                false,
                now()
            );
        ELSIF v_remaining_stock <= 5 THEN
            INSERT INTO public.notifications (
                id, user_id, title, message, notification_type, is_read, created_at
            ) VALUES (
                gen_random_uuid(),
                p_vendor_id,
                'Low Stock Alert',
                v_product_name || ' has only ' || v_remaining_stock || ' item(s) left in stock.',
                'low_stock',
                false,
                now()
            );
        END IF;
    END LOOP;

    -- 5. Determine payment status & reference (paid for both GCash & Card)
    v_payment_status := 'paid';
    v_payment_ref := 'PAY-' || extract(epoch from now())::bigint;

    -- 6. Insert Order (including notes)
    INSERT INTO public.orders (
        id,
        user_id,
        vendor_id,
        delivery_location_id,
        order_status,
        subtotal,
        delivery_fee,
        total_amount,
        payment_method,
        payment_status,
        payment_reference,
        notes,
        created_at,
        updated_at
    ) VALUES (
        gen_random_uuid(),
        v_caller_id,
        p_vendor_id,
        p_delivery_location_id,
        'pending',
        p_subtotal,
        p_delivery_fee,
        p_total_amount,
        p_payment_method,
        v_payment_status,
        v_payment_ref,
        p_notes,
        now(),
        now()
    ) RETURNING id INTO v_order_id;

    -- 7. Insert Order Items (WITHOUT created_at)
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity := (v_item->>'quantity')::integer;
        v_unit_price := (v_item->>'unit_price')::numeric;
        v_item_subtotal := v_unit_price * v_quantity;

        SELECT name, coalesce(weight_grams, 0)
        INTO v_product_name, v_weight_grams
        FROM public.products
        WHERE id = v_product_id;

        INSERT INTO public.order_items (
            id,
            order_id,
            product_id,
            product_name,
            quantity,
            unit_price,
            weight_grams,
            subtotal
        ) VALUES (
            gen_random_uuid(),
            v_order_id,
            v_product_id,
            coalesce(v_item->>'product_name', v_product_name),
            v_quantity,
            v_unit_price,
            v_weight_grams,
            v_item_subtotal
        );
    END LOOP;

    -- 8. Customer Order Placed Notification
    INSERT INTO public.notifications (
        id, user_id, title, message, notification_type, is_read, created_at
    ) VALUES (
        gen_random_uuid(),
        v_caller_id,
        'Order Placed Successfully',
        'Your order has been sent to the vendor. Awaiting confirmation.',
        'order_placed',
        false,
        now()
    );

    -- 9. Vendor New Order Notification
    INSERT INTO public.notifications (
        id, user_id, title, message, notification_type, is_read, created_at
    ) VALUES (
        gen_random_uuid(),
        p_vendor_id,
        'New Customer Order!',
        'You have received a new order for ₱' || round(p_total_amount, 2)::text || '.',
        'new_order',
        false,
        now()
    );

    RETURN v_order_id;
END;
$$;

REVOKE ALL ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text) TO authenticated;


-- ============================================================
-- PART 2: CANCELLATION RPC & RLS POLICY TIGHTENING
-- ============================================================

-- 2.1 Drop direct customer UPDATE policy on orders
DROP POLICY IF EXISTS orders_owner_cancel ON public.orders;

-- 2.2 Create customer_cancel_order RPC with row locking (SELECT ... FOR UPDATE)
CREATE OR REPLACE FUNCTION public.customer_cancel_order(
    p_order_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_caller_id uuid;
    v_order RECORD;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Lock the order row to prevent race conditions with vendor preparation
    SELECT id, user_id, order_status
    INTO v_order
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    IF v_order.user_id != v_caller_id THEN
        RAISE EXCEPTION 'You do not own this order';
    END IF;

    IF v_order.order_status NOT IN ('pending', 'confirmed', 'preparing') THEN
        RAISE EXCEPTION 'Order cannot be cancelled in status: %', v_order.order_status;
    END IF;

    UPDATE public.orders
    SET 
        order_status = 'cancelled',
        cancellation_reason = 'customer',
        updated_at = now()
    WHERE id = p_order_id;

    RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.customer_cancel_order(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.customer_cancel_order(uuid) TO authenticated;


-- ============================================================
-- PART 3: REVIEWS & RATINGS SCHEMA (WRITES VIA RPC ONLY)
-- ============================================================

-- 3.1 Store Reviews table
CREATE TABLE IF NOT EXISTS public.store_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    vendor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT store_reviews_order_unique UNIQUE (order_id)
);

-- 3.2 Product Reviews table
CREATE TABLE IF NOT EXISTS public.product_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT product_reviews_order_product_unique UNIQUE (order_id, product_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_store_reviews_vendor ON public.store_reviews(vendor_id);
CREATE INDEX IF NOT EXISTS idx_store_reviews_user ON public.store_reviews(user_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_product ON public.product_reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_user ON public.product_reviews(user_id);

-- Enable RLS
ALTER TABLE public.store_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_reviews ENABLE ROW LEVEL SECURITY;

-- Read-only policies (writes go exclusively through SECURITY DEFINER submit_order_reviews)
DROP POLICY IF EXISTS store_reviews_select ON public.store_reviews;
CREATE POLICY store_reviews_select ON public.store_reviews FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS store_reviews_insert ON public.store_reviews;
DROP POLICY IF EXISTS store_reviews_update ON public.store_reviews;

DROP POLICY IF EXISTS product_reviews_select ON public.product_reviews;
CREATE POLICY product_reviews_select ON public.product_reviews FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS product_reviews_insert ON public.product_reviews;
DROP POLICY IF EXISTS product_reviews_update ON public.product_reviews;

-- 3.3 Dynamic summary views
CREATE OR REPLACE VIEW public.vendor_ratings_summary AS
SELECT 
    v.id AS vendor_id,
    coalesce(round(avg(r.rating)::numeric, 1), 0.0) AS average_rating,
    count(r.id)::integer AS review_count
FROM public.users v
LEFT JOIN public.store_reviews r ON r.vendor_id = v.id
WHERE v.role = 'vendor'
GROUP BY v.id;

CREATE OR REPLACE VIEW public.product_ratings_summary AS
SELECT 
    p.id AS product_id,
    coalesce(round(avg(r.rating)::numeric, 1), 0.0) AS average_rating,
    count(r.id)::integer AS review_count
FROM public.products p
LEFT JOIN public.product_reviews r ON r.product_id = p.id
GROUP BY p.id;

REVOKE ALL ON public.vendor_ratings_summary FROM PUBLIC, anon;
GRANT SELECT ON public.vendor_ratings_summary TO authenticated;

REVOKE ALL ON public.product_ratings_summary FROM PUBLIC, anon;
GRANT SELECT ON public.product_ratings_summary TO authenticated;

-- 3.4 RPC to submit or update order reviews atomically (p_store_rating is optional)
CREATE OR REPLACE FUNCTION public.submit_order_reviews(
    p_order_id uuid,
    p_store_rating integer DEFAULT NULL,
    p_store_comment text DEFAULT NULL,
    p_product_reviews jsonb DEFAULT '[]'::jsonb
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_caller_id uuid;
    v_order RECORD;
    v_pr jsonb;
    v_product_id uuid;
    v_prod_rating integer;
    v_prod_comment text;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT id, user_id, vendor_id, order_status
    INTO v_order
    FROM public.orders
    WHERE id = p_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    IF v_order.user_id != v_caller_id THEN
        RAISE EXCEPTION 'You do not own this order';
    END IF;

    IF v_order.order_status != 'delivered' THEN
        RAISE EXCEPTION 'Reviews are only permitted for delivered orders';
    END IF;

    -- 1. Upsert Store Review (only if p_store_rating provided)
    IF p_store_rating IS NOT NULL THEN
        IF p_store_rating < 1 OR p_store_rating > 5 THEN
            RAISE EXCEPTION 'Store rating must be between 1 and 5';
        END IF;

        INSERT INTO public.store_reviews (
            order_id, user_id, vendor_id, rating, comment, updated_at
        ) VALUES (
            p_order_id, v_caller_id, v_order.vendor_id, p_store_rating, p_store_comment, now()
        )
        ON CONFLICT (order_id) DO UPDATE SET
            rating = EXCLUDED.rating,
            comment = EXCLUDED.comment,
            updated_at = now();
    END IF;

    -- 2. Upsert Product Reviews
    IF p_product_reviews IS NOT NULL AND jsonb_array_length(p_product_reviews) > 0 THEN
        FOR v_pr IN SELECT * FROM jsonb_array_elements(p_product_reviews)
        LOOP
            v_product_id := (v_pr->>'product_id')::uuid;
            v_prod_rating := (v_pr->>'rating')::integer;
            v_prod_comment := v_pr->>'comment';

            IF v_prod_rating >= 1 AND v_prod_rating <= 5 THEN
                -- Verify product was in this order
                IF EXISTS (
                    SELECT 1 FROM public.order_items 
                    WHERE order_id = p_order_id AND product_id = v_product_id
                ) THEN
                    INSERT INTO public.product_reviews (
                        order_id, product_id, user_id, rating, comment, updated_at
                    ) VALUES (
                        p_order_id, v_product_id, v_caller_id, v_prod_rating, v_prod_comment, now()
                    )
                    ON CONFLICT (order_id, product_id) DO UPDATE SET
                        rating = EXCLUDED.rating,
                        comment = EXCLUDED.comment,
                        updated_at = now();
                END IF;
            END IF;
        END LOOP;
    END IF;

    RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_order_reviews(uuid, integer, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_order_reviews(uuid, integer, text, jsonb) TO authenticated;

-- 3.5 RPC to fetch vendor reviews with privacy-safe reviewer name
CREATE OR REPLACE FUNCTION public.get_vendor_reviews(p_vendor_id uuid)
RETURNS TABLE (
    id uuid,
    rating integer,
    comment text,
    created_at timestamptz,
    reviewer_name text
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, auth, pg_temp
AS $$
    SELECT 
        sr.id,
        sr.rating,
        sr.comment,
        sr.created_at,
        CASE 
            WHEN position(' ' in u.full_name) > 0 THEN
                split_part(u.full_name, ' ', 1) || ' ' || substring(split_part(u.full_name, ' ', 2), 1, 1) || '.'
            ELSE
                u.full_name
        END AS reviewer_name
    FROM public.store_reviews sr
    JOIN public.users u ON u.id = sr.user_id
    WHERE sr.vendor_id = p_vendor_id
    ORDER BY sr.created_at DESC;
$$;

REVOKE ALL ON FUNCTION public.get_vendor_reviews(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_vendor_reviews(uuid) TO authenticated;

-- 3.6 RPC to fetch product reviews with privacy-safe reviewer name
CREATE OR REPLACE FUNCTION public.get_product_reviews(p_product_id uuid)
RETURNS TABLE (
    id uuid,
    rating integer,
    comment text,
    created_at timestamptz,
    reviewer_name text
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, auth, pg_temp
AS $$
    SELECT 
        pr.id,
        pr.rating,
        pr.comment,
        pr.created_at,
        CASE 
            WHEN position(' ' in u.full_name) > 0 THEN
                split_part(u.full_name, ' ', 1) || ' ' || substring(split_part(u.full_name, ' ', 2), 1, 1) || '.'
            ELSE
                u.full_name
        END AS reviewer_name
    FROM public.product_reviews pr
    JOIN public.users u ON u.id = pr.user_id
    WHERE pr.product_id = p_product_id
    ORDER BY pr.created_at DESC;
$$;

REVOKE ALL ON FUNCTION public.get_product_reviews(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_product_reviews(uuid) TO authenticated;

-- 3.7 Add reviews tables to supabase_realtime publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'store_reviews'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.store_reviews;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'product_reviews'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.product_reviews;
    END IF;
END $$;

COMMIT;
