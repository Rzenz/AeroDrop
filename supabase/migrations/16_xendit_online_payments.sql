-- ============================================================
-- 16_XENDIT_ONLINE_PAYMENTS.SQL
-- 1. Add 'xendit_online' to payment_method check constraint.
-- 2. Add 'expired' to payment_status check constraint.
-- 3. Add payment provider and invoice tracking columns (NO DEFAULT on provider).
-- 4. Update place_order (exact copy from migration 12 + pending payment).
-- 5. Update cancellation & refund trigger for xendit_online (from migration 12).
-- 6. Tighten orders_select and orders_vendor_update policies (from migration 01,
--    allowing cash_on_delivery and cash to remain actionable).
-- 7. Update vendor_mark_order_ready (exact copy from migration 10 + paid guard,
--    allowing cash_on_delivery and cash).
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. PAYMENT METHOD & PAYMENT STATUS CHECK CONSTRAINTS
-- ------------------------------------------------------------
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_method_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_payment_method_check
    CHECK (payment_method IS NULL OR payment_method IN (
        'gcash_simulated',
        'card_simulated',
        'cash_on_delivery',
        'cash',
        'xendit_online'
    ));

ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_status_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_payment_status_check
    CHECK (payment_status IN (
        'pending',
        'paid',
        'failed',
        'refunded',
        'expired'
    ));

-- ------------------------------------------------------------
-- 2. NEW PAYMENT TRACKING COLUMNS (NO DEFAULT ON PROVIDER)
-- ------------------------------------------------------------
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_provider text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_invoice_id text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_invoice_url text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_channel text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS paid_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_orders_payment_invoice_id ON public.orders(payment_invoice_id);

-- ------------------------------------------------------------
-- 3. UPDATED PLACE_ORDER (EXACT COPY FROM MIGRATION 12 WITH PAYMENT LOGIC ADAPTED)
-- ------------------------------------------------------------
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
    IF p_payment_method IS NULL OR p_payment_method NOT IN ('gcash_simulated', 'card_simulated', 'xendit_online') THEN
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

    -- 5. Determine payment status & reference
    IF p_payment_method = 'xendit_online' THEN
        v_payment_status := 'pending';
        v_payment_ref := NULL;
    ELSE
        v_payment_status := 'paid';
        v_payment_ref := 'PAY-' || extract(epoch from now())::bigint;
    END IF;

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
        payment_provider,
        paid_at,
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
        CASE WHEN p_payment_method = 'xendit_online' THEN 'xendit' ELSE NULL END,
        CASE WHEN p_payment_method != 'xendit_online' THEN now() ELSE NULL END,
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
    IF p_payment_method = 'xendit_online' THEN
        INSERT INTO public.notifications (
            id, user_id, title, message, notification_type, is_read, created_at
        ) VALUES (
            gen_random_uuid(),
            v_caller_id,
            'Order Placed Successfully',
            'Your order has been created. Please complete payment to notify the vendor.',
            'order_placed',
            false,
            now()
        );
    ELSE
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
    END IF;

    -- 9. Vendor New Order Notification (deferred for xendit_online until payment confirmation webhook)
    IF p_payment_method != 'xendit_online' THEN
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
    END IF;

    RETURN v_order_id;
END;
$$;

REVOKE ALL ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text) TO authenticated;

-- ------------------------------------------------------------
-- 4. CANCELLATION & REFUND TRIGGERS (EXACT COPY FROM MIGRATION 12 + XENDIT_ONLINE)
-- ------------------------------------------------------------
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
        IF NEW.payment_method IN ('gcash_simulated', 'card_simulated', 'xendit_online') AND NEW.payment_status = 'paid' THEN
            NEW.payment_status := 'refunded';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

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
            IF NEW.payment_method IN ('gcash_simulated', 'card_simulated', 'xendit_online') AND NEW.payment_status = 'refunded' THEN
                v_refund_text := ' Your payment will be refunded.';
            END IF;

            IF NEW.cancellation_reason = 'weather_grounded' THEN
                v_cust_msg := 'Weather is currently unsafe for drone delivery. Your order #' || v_short_id || ' was cancelled.' || v_refund_text;
                v_vend_msg := 'Weather is currently unsafe for drone delivery. Order #' || v_short_id || ' was cancelled.';
            ELSIF NEW.cancellation_reason = 'customer' THEN
                v_cust_msg := 'Your order #' || v_short_id || ' has been cancelled.' || v_refund_text;
                v_vend_msg := 'Order #' || v_short_id || ' was cancelled by the customer.';
            ELSIF NEW.cancellation_reason = 'payment_expired' THEN
                v_cust_msg := 'Your order #' || v_short_id || ' has expired due to incomplete payment. No charges were made.';
                v_vend_msg := 'Order #' || v_short_id || ' expired due to incomplete payment.';
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

-- ------------------------------------------------------------
-- 5. RLS POLICIES (FROM MIGRATION 01, PRESERVING CASH & COD)
-- ------------------------------------------------------------
DROP POLICY IF EXISTS orders_select ON public.orders;
CREATE POLICY orders_select ON public.orders FOR SELECT TO authenticated
USING (
    (user_id = auth.uid()) 
    OR (
        vendor_id = auth.uid() 
        AND (payment_method != 'xendit_online' OR payment_status = 'paid')
    ) 
    OR public.is_admin()
);

DROP POLICY IF EXISTS orders_vendor_update ON public.orders;
CREATE POLICY orders_vendor_update ON public.orders FOR UPDATE TO authenticated
USING (
    (vendor_id = auth.uid()) 
    AND public.is_active_vendor(auth.uid())
    AND (payment_status = 'paid' OR payment_method IN ('cash_on_delivery', 'cash'))
)
WITH CHECK (vendor_id = auth.uid());

-- ------------------------------------------------------------
-- 6. VENDOR_MARK_ORDER_READY (EXACT COPY FROM MIGRATION 10 + PAID GUARD, ALLOWING CASH & COD)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.vendor_mark_order_ready(p_order_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order_status text;
    v_payment_status text;
    v_payment_method text;
    v_vendor_id uuid;
    v_order_user_id uuid;
    v_dropoff_location_id uuid;
    v_pickup_location_id uuid;

    v_user_role text;
    v_vendor_status text;
    v_account_status text;

    v_item_count bigint;
    v_total_weight_grams bigint;
    v_total_weight_kg double precision;

    v_weather_status text;

    v_drone_id uuid;
    v_drone_status text;
    v_drone_battery double precision;
    v_drone_max_payload double precision;

    v_delivery_id uuid;
    v_delivery_status text;
    v_drone_available boolean := false;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT role, vendor_status, account_status
    INTO v_user_role, v_vendor_status, v_account_status
    FROM public.users
    WHERE id = auth.uid();

    IF NOT FOUND OR v_user_role IS DISTINCT FROM 'vendor' OR v_vendor_status IS DISTINCT FROM 'active' OR v_account_status IS DISTINCT FROM 'active' THEN
        RAISE EXCEPTION 'Unauthorized: Caller is not an active approved vendor';
    END IF;

    SELECT order_status, payment_status, payment_method, vendor_id, user_id, delivery_location_id
    INTO v_order_status, v_payment_status, v_payment_method, v_vendor_id, v_order_user_id, v_dropoff_location_id
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    IF v_vendor_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized: Order belongs to another vendor';
    END IF;

    -- Guard: reject when payment is not confirmed (unless cash or cash_on_delivery)
    IF v_payment_status IS DISTINCT FROM 'paid' AND v_payment_method NOT IN ('cash_on_delivery', 'cash') THEN
        RAISE EXCEPTION 'Cannot mark order ready: Payment status is %', coalesce(v_payment_status, 'unknown');
    END IF;

    IF v_order_status NOT IN ('confirmed', 'preparing', 'ready_for_delivery') THEN
        RAISE EXCEPTION 'Invalid order status: Must be confirmed, preparing, or ready_for_delivery';
    END IF;

    SELECT count(*), coalesce(sum(coalesce(weight_grams, 0) * coalesce(quantity, 0)), 0)
    INTO v_item_count, v_total_weight_grams
    FROM public.order_items
    WHERE order_id = p_order_id;

    IF v_item_count <= 0 THEN
        RAISE EXCEPTION 'Order contains no items';
    END IF;

    v_total_weight_kg := v_total_weight_grams::double precision / 1000.0;
    IF v_total_weight_kg <= 0 THEN
        RAISE EXCEPTION 'Total cargo weight must be greater than zero';
    END IF;

    -- Query weather status
    SELECT safety_status INTO v_weather_status
    FROM public.weather_safety
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_weather_status IS NULL OR v_weather_status = 'grounded' THEN
        RAISE EXCEPTION 'Flight dispatch blocked: Weather is grounded';
    END IF;

    -- Query locations
    SELECT campus_location_id INTO v_pickup_location_id
    FROM public.users
    WHERE id = auth.uid();

    IF v_pickup_location_id IS NULL THEN
        RAISE EXCEPTION 'Vendor pickup location not configured';
    END IF;

    IF v_dropoff_location_id IS NULL THEN
        RAISE EXCEPTION 'Order dropoff location not configured';
    END IF;

    -- Query DRN-001
    SELECT id, status, battery_level, max_payload_kg
    INTO v_drone_id, v_drone_status, v_drone_battery, v_drone_max_payload
    FROM public.drones
    WHERE drone_code = 'DRN-001'
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Drone DRN-001 not found';
    END IF;

    IF v_total_weight_kg > coalesce(v_drone_max_payload, 0.5) THEN
        RAISE EXCEPTION 'Total cargo weight exceeds drone maximum payload limit';
    END IF;

    -- Safety-net recovery for stale returning drone
    IF v_drone_status = 'returning' THEN
        PERFORM public.recover_stale_returning_drone(v_drone_id);
        SELECT status, battery_level INTO v_drone_status, v_drone_battery
        FROM public.drones WHERE id = v_drone_id;
    END IF;

    -- Self-healing: if drone is marked 'assigned' or 'busy' but has NO active deliveries, recover to available
    IF v_drone_status IN ('assigned', 'busy') AND NOT EXISTS (
        SELECT 1 FROM public.deliveries
        WHERE drone_id = v_drone_id AND status IN ('assigning', 'in_transit')
    ) THEN
        v_drone_status := 'available';
        UPDATE public.drones
        SET status = 'available', returning_started_at = NULL, sim_lease_holder = NULL, sim_lease_until = NULL, updated_at = now()
        WHERE id = v_drone_id;
    END IF;

    -- Check if drone is legitimately available right now
    IF v_drone_status = 'available' AND (v_drone_battery IS NULL OR v_drone_battery >= 15.0) THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.deliveries
            WHERE drone_id = v_drone_id AND status IN ('assigning', 'in_transit')
        ) THEN
            v_drone_available := true;
        END IF;
    END IF;

    -- Find or create delivery record
    SELECT id, status
    INTO v_delivery_id, v_delivery_status
    FROM public.deliveries
    WHERE order_id = p_order_id
    FOR UPDATE;

    IF v_drone_available THEN
        -- Drone available: dispatch immediately
        IF FOUND THEN
            UPDATE public.deliveries
            SET
                drone_id = v_drone_id,
                status = 'assigning',
                pickup_location_id = v_pickup_location_id,
                dropoff_location_id = v_dropoff_location_id,
                delivery_started_at = NULL,
                delivery_completed_at = NULL,
                estimated_delivery_seconds = 720,
                progress = 0,
                updated_at = now()
            WHERE id = v_delivery_id;
        ELSE
            INSERT INTO public.deliveries (
                order_id, drone_id, status, pickup_location_id, dropoff_location_id,
                delivery_started_at, delivery_completed_at, estimated_delivery_seconds, progress, created_at, updated_at
            ) VALUES (
                p_order_id, v_drone_id, 'assigning', v_pickup_location_id, v_dropoff_location_id,
                NULL, NULL, 720, 0, now(), now()
            )
            RETURNING id INTO v_delivery_id;
        END IF;

        UPDATE public.orders
        SET order_status = 'ready_for_delivery', updated_at = now()
        WHERE id = p_order_id;

        UPDATE public.drones
        SET status = 'assigned', returning_started_at = NULL, sim_lease_holder = NULL, sim_lease_until = NULL, updated_at = now()
        WHERE id = v_drone_id;

        INSERT INTO public.delivery_status_logs (
            delivery_id, status, message, changed_by, created_at
        ) VALUES (
            v_delivery_id, 'assigning', 'Drone DRN-001 assigned and dispatched to vendor for package pickup.', auth.uid(), now()
        );

        IF v_order_user_id IS NOT NULL THEN
            INSERT INTO public.notifications (
                id, user_id, title, message, notification_type, is_read, related_delivery_id, created_at
            ) VALUES (
                gen_random_uuid(), v_order_user_id, 'Drone Dispatched to Vendor',
                'Drone DRN-001 is on its way to the vendor to pick up your order.', 'drone_dispatched', false, v_delivery_id, now()
            );
        END IF;

        INSERT INTO public.notifications (
            id, user_id, title, message, notification_type, is_read, related_delivery_id, created_at
        ) VALUES (
            gen_random_uuid(), auth.uid(), 'Drone Heading to Pickup',
            'Drone DRN-001 has been dispatched to pick up the package from your shop.', 'drone_dispatched', false, v_delivery_id, now()
        );

        RETURN json_build_object(
            'success', true,
            'order_id', p_order_id,
            'delivery_id', v_delivery_id,
            'drone_code', 'DRN-001',
            'drone_dispatched', true,
            'order_status', 'ready_for_delivery',
            'delivery_status', 'assigning',
            'message', 'Order is ready for delivery. Drone DRN-001 dispatched for pickup.'
        );
    ELSE
        -- Drone unavailable: queue delivery as pending
        IF FOUND THEN
            UPDATE public.deliveries
            SET
                drone_id = NULL,
                status = 'pending',
                pickup_location_id = v_pickup_location_id,
                dropoff_location_id = v_dropoff_location_id,
                delivery_started_at = NULL,
                delivery_completed_at = NULL,
                progress = 0,
                updated_at = now()
            WHERE id = v_delivery_id;
        ELSE
            INSERT INTO public.deliveries (
                order_id, drone_id, status, pickup_location_id, dropoff_location_id,
                delivery_started_at, delivery_completed_at, estimated_delivery_seconds, progress, created_at, updated_at
            ) VALUES (
                p_order_id, NULL, 'pending', v_pickup_location_id, v_dropoff_location_id,
                NULL, NULL, 720, 0, now(), now()
            )
            RETURNING id INTO v_delivery_id;
        END IF;

        UPDATE public.orders
        SET order_status = 'ready_for_delivery', updated_at = now()
        WHERE id = p_order_id;

        INSERT INTO public.delivery_status_logs (
            delivery_id, status, message, changed_by, created_at
        ) VALUES (
            v_delivery_id, 'pending', 'Order marked ready. Waiting in queue for next available drone.', auth.uid(), now()
        );

        INSERT INTO public.notifications (
            id, user_id, title, message, notification_type, is_read, related_delivery_id, created_at
        ) VALUES (
            gen_random_uuid(), auth.uid(), 'Order Queued for Drone',
            'Order marked ready and placed in queue. Drone will be dispatched automatically when available.', 'order_queued', false, v_delivery_id, now()
        );

        RETURN json_build_object(
            'success', true,
            'order_id', p_order_id,
            'delivery_id', v_delivery_id,
            'drone_code', 'DRN-001',
            'drone_dispatched', false,
            'order_status', 'ready_for_delivery',
            'delivery_status', 'pending',
            'message', 'Drone currently unavailable. This order is ready and waiting for the next available drone.'
        );
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.vendor_mark_order_ready(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vendor_mark_order_ready(uuid) TO authenticated;

COMMIT;
