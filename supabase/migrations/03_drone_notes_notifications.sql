-- ============================================================
-- 03_DRONE_NOTES_NOTIFICATIONS.SQL
-- Migration: Order Notes, Drone Availability Self-Healing,
-- Vendor Product Images Storage Bucket, and Realtime Notifications
-- ============================================================

-- 1. STORAGE BUCKET: product-images
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Public Access to Product Images" ON storage.objects;
CREATE POLICY "Public Access to Product Images"
ON storage.objects FOR SELECT
USING (bucket_id = 'product-images');

DROP POLICY IF EXISTS "Owner Upload Product Images" ON storage.objects;
CREATE POLICY "Owner Upload Product Images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'product-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Owner Update Product Images" ON storage.objects;
CREATE POLICY "Owner Update Product Images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'product-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'product-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Owner Delete Product Images" ON storage.objects;
CREATE POLICY "Owner Delete Product Images"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'product-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 2. NOTIFICATIONS TABLE SCHEMA ENHANCEMENT
-- ============================================================

ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS read_at timestamptz,
    ADD COLUMN IF NOT EXISTS related_delivery_id uuid,
    ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- 3. ONE-TIME DRONE STATUS REPAIR
-- ============================================================

UPDATE public.drones
SET status = 'available', updated_at = now()
WHERE drone_code = 'DRN-001'
  AND NOT EXISTS (
      SELECT 1 FROM public.deliveries
      WHERE drone_id = public.drones.id
        AND status IN ('pending', 'assigning', 'in_transit')
  );

-- 4. DELIVERY STATUS LIFECYCLE & DRONE RELEASE TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_delivery_drone_release()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order_user_id uuid;
    v_order_vendor_id uuid;
    v_order_id uuid;
BEGIN
    v_order_id := NEW.order_id;

    SELECT user_id, vendor_id
    INTO v_order_user_id, v_order_vendor_id
    FROM public.orders
    WHERE id = v_order_id;

    -- A. When delivery completes or ends, release drone to available
    IF NEW.status IN ('delivered', 'cancelled', 'rejected', 'failed') AND NEW.drone_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.deliveries
            WHERE drone_id = NEW.drone_id
              AND id <> NEW.id
              AND status IN ('pending', 'assigning', 'in_transit')
        ) THEN
            UPDATE public.drones
            SET status = 'available', updated_at = now()
            WHERE id = NEW.drone_id;
        END IF;

        IF NEW.status = 'delivered' THEN
            UPDATE public.orders
            SET order_status = 'delivered', updated_at = now()
            WHERE id = v_order_id AND order_status <> 'delivered';

            -- Customer delivered notification
            IF v_order_user_id IS NOT NULL THEN
                INSERT INTO public.notifications (
                    id, user_id, title, message, notification_type, is_read, related_delivery_id, created_at
                ) VALUES (
                    gen_random_uuid(),
                    v_order_user_id,
                    'Order Delivered!',
                    'Your package has safely arrived at the drop-off location.',
                    'order_delivered',
                    false,
                    NEW.id,
                    now()
                );
            END IF;

            -- Vendor delivered notification
            IF v_order_vendor_id IS NOT NULL THEN
                INSERT INTO public.notifications (
                    id, user_id, title, message, notification_type, is_read, related_delivery_id, created_at
                ) VALUES (
                    gen_random_uuid(),
                    v_order_vendor_id,
                    'Delivery Completed',
                    'Your customer order has been delivered successfully by drone.',
                    'delivery_completed',
                    false,
                    NEW.id,
                    now()
                );
            END IF;
        END IF;

    -- B. When delivery transitions to in_transit
    ELSIF NEW.status = 'in_transit' AND (OLD.status IS NULL OR OLD.status <> 'in_transit') THEN
        UPDATE public.orders
        SET order_status = 'in_transit', updated_at = now()
        WHERE id = v_order_id AND order_status NOT IN ('in_transit', 'delivered');

        IF v_order_user_id IS NOT NULL THEN
            INSERT INTO public.notifications (
                id, user_id, title, message, notification_type, is_read, related_delivery_id, created_at
            ) VALUES (
                gen_random_uuid(),
                v_order_user_id,
                'Drone Dispatched!',
                'Drone DRN-001 is in flight and carrying your order.',
                'order_in_transit',
                false,
                NEW.id,
                now()
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_delivery_drone_release ON public.deliveries;
CREATE TRIGGER trg_delivery_drone_release
AFTER UPDATE OF status ON public.deliveries
FOR EACH ROW
EXECUTE FUNCTION public.handle_delivery_drone_release();

-- 5. ORDER STATUS NOTIFICATIONS TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_order_status_notifications()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.order_status IS DISTINCT FROM OLD.order_status THEN
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
        ELSIF NEW.order_status = 'cancelled' THEN
            INSERT INTO public.notifications (
                id, user_id, title, message, notification_type, is_read, created_at
            ) VALUES (
                gen_random_uuid(),
                NEW.user_id,
                'Order Cancelled',
                'Your order has been cancelled.',
                'order_cancelled',
                false,
                now()
            );
            INSERT INTO public.notifications (
                id, user_id, title, message, notification_type, is_read, created_at
            ) VALUES (
                gen_random_uuid(),
                NEW.vendor_id,
                'Order Cancelled',
                'An order has been cancelled.',
                'order_cancelled',
                false,
                now()
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_status_notifications ON public.orders;
CREATE TRIGGER trg_order_status_notifications
AFTER UPDATE OF order_status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.handle_order_status_notifications();

-- 6. ATOMIC ORDER PLACEMENT RPC (WITH NOTES & NOTIFICATIONS)
-- ============================================================

-- Drop both 7-parameter and 8-parameter forms to avoid ambiguous resolution
DROP FUNCTION IF EXISTS public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb);
DROP FUNCTION IF EXISTS public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text);

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
BEGIN
    -- 1. Require authenticated user
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
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
    IF p_payment_method = 'gcash_simulated' THEN
        v_payment_status := 'paid';
    ELSE
        v_payment_status := 'pending';
    END IF;
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

    -- 7. Insert Order Items
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

REVOKE ALL ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text) TO authenticated;

-- 7. VENDOR MARK ORDER READY (WITH DRONE SELF-HEALING & BATTERY CHECK)
-- ============================================================

CREATE OR REPLACE FUNCTION public.vendor_mark_order_ready(p_order_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_order_status text;
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
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT
        role,
        vendor_status,
        account_status
    INTO
        v_user_role,
        v_vendor_status,
        v_account_status
    FROM public.users
    WHERE id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Authenticated account profile was not found';
    END IF;

    IF v_user_role IS DISTINCT FROM 'vendor'
       OR v_vendor_status IS DISTINCT FROM 'active'
       OR v_account_status IS DISTINCT FROM 'active'
    THEN
        RAISE EXCEPTION 'Unauthorized: Caller is not an active approved vendor';
    END IF;

    SELECT
        order_status,
        vendor_id,
        user_id,
        delivery_location_id
    INTO
        v_order_status,
        v_vendor_id,
        v_order_user_id,
        v_dropoff_location_id
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    IF v_vendor_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized: Order belongs to another vendor';
    END IF;

    IF v_order_status IS DISTINCT FROM 'confirmed'
       AND v_order_status IS DISTINCT FROM 'preparing'
    THEN
        RAISE EXCEPTION 'Invalid order status: Must be confirmed or preparing';
    END IF;

    SELECT
        count(*),
        coalesce(sum(coalesce(weight_grams, 0) * coalesce(quantity, 0)), 0)
    INTO
        v_item_count,
        v_total_weight_grams
    FROM public.order_items
    WHERE order_id = p_order_id;

    IF v_item_count <= 0 THEN
        RAISE EXCEPTION 'Order contains no items';
    END IF;

    v_total_weight_kg := v_total_weight_grams::double precision / 1000.0;

    IF v_total_weight_kg <= 0 THEN
        RAISE EXCEPTION 'Total cargo weight must be greater than zero';
    END IF;

    SELECT
        id,
        status,
        battery_level,
        max_payload_kg
    INTO
        v_drone_id,
        v_drone_status,
        v_drone_battery,
        v_drone_max_payload
    FROM public.drones
    WHERE drone_code = 'DRN-001'
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Drone DRN-001 not found';
    END IF;

    -- SELF-HEALING: If drone is marked 'assigned' but has NO active deliveries, recover to available
    IF v_drone_status = 'assigned' AND NOT EXISTS (
        SELECT 1 FROM public.deliveries
        WHERE drone_id = v_drone_id
          AND status IN ('pending', 'assigning', 'in_transit')
    ) THEN
        v_drone_status := 'available';
        UPDATE public.drones
        SET status = 'available', updated_at = now()
        WHERE id = v_drone_id;
    END IF;

    IF v_drone_status IS DISTINCT FROM 'available' THEN
        RAISE EXCEPTION 'Drone DRN-001 is not currently available';
    END IF;

    -- Battery check: must be at least 15%
    IF v_drone_battery IS NOT NULL AND v_drone_battery < 15.0 THEN
        RAISE EXCEPTION 'Drone DRN-001 battery is insufficient for delivery (current: % %)', v_drone_battery, '%';
    END IF;

    IF v_drone_max_payload IS NULL OR v_drone_max_payload <= 0 THEN
        RAISE EXCEPTION 'Drone payload capacity is not configured';
    END IF;

    IF v_total_weight_kg > v_drone_max_payload THEN
        RAISE EXCEPTION 'Total cargo weight exceeds drone maximum payload limit';
    END IF;

    SELECT safety_status
    INTO v_weather_status
    FROM public.weather_safety
    ORDER BY updated_at DESC
    LIMIT 1;

    IF NOT FOUND OR v_weather_status IS NULL THEN
        RAISE EXCEPTION 'No weather safety record configured';
    END IF;

    IF v_weather_status IS DISTINCT FROM 'safe' AND v_weather_status IS DISTINCT FROM 'caution' THEN
        RAISE EXCEPTION 'Flight dispatch blocked: Weather is grounded';
    END IF;

    SELECT campus_location_id
    INTO v_pickup_location_id
    FROM public.users
    WHERE id = auth.uid();

    IF v_pickup_location_id IS NULL THEN
        RAISE EXCEPTION 'Vendor pickup location not configured';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.campus_locations WHERE id = v_pickup_location_id
    ) THEN
        RAISE EXCEPTION 'Vendor pickup location does not exist';
    END IF;

    IF v_dropoff_location_id IS NULL THEN
        RAISE EXCEPTION 'Order dropoff location not configured';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.campus_locations WHERE id = v_dropoff_location_id
    ) THEN
        RAISE EXCEPTION 'Order dropoff location does not exist';
    END IF;

    SELECT id, status
    INTO v_delivery_id, v_delivery_status
    FROM public.deliveries
    WHERE order_id = p_order_id
    FOR UPDATE;

    IF FOUND THEN
        IF v_delivery_status IN ('pending', 'assigning', 'in_transit') THEN
            RAISE EXCEPTION 'An active delivery already exists for this order';
        END IF;

        IF v_delivery_status = 'delivered' THEN
            RAISE EXCEPTION 'This order has already been delivered';
        END IF;

        IF v_delivery_status NOT IN ('cancelled', 'rejected', 'grounded') THEN
            RAISE EXCEPTION 'The existing delivery cannot be restarted';
        END IF;

        UPDATE public.deliveries
        SET
            drone_id = v_drone_id,
            status = 'in_transit',
            pickup_location_id = v_pickup_location_id,
            dropoff_location_id = v_dropoff_location_id,
            delivery_started_at = now(),
            delivery_completed_at = NULL,
            estimated_delivery_seconds = 720,
            progress = 0,
            updated_at = now()
        WHERE id = v_delivery_id;
    ELSE
        INSERT INTO public.deliveries (
            order_id,
            drone_id,
            status,
            pickup_location_id,
            dropoff_location_id,
            delivery_started_at,
            delivery_completed_at,
            estimated_delivery_seconds,
            progress,
            created_at,
            updated_at
        )
        VALUES (
            p_order_id,
            v_drone_id,
            'in_transit',
            v_pickup_location_id,
            v_dropoff_location_id,
            now(),
            NULL,
            720,
            0,
            now(),
            now()
        )
        RETURNING id INTO v_delivery_id;
    END IF;

    UPDATE public.orders
    SET
        order_status = 'ready_for_delivery',
        updated_at = now()
    WHERE id = p_order_id;

    UPDATE public.drones
    SET
        status = 'assigned',
        updated_at = now()
    WHERE id = v_drone_id;

    INSERT INTO public.delivery_status_logs (
        delivery_id,
        status,
        message,
        changed_by,
        created_at
    )
    VALUES (
        v_delivery_id,
        'in_transit',
        'Drone DRN-001 dispatched to pick up the order from the vendor.',
        auth.uid(),
        now()
    );

    -- Notify customer that order is ready for delivery
    IF v_order_user_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            id, user_id, title, message, notification_type, is_read, related_delivery_id, created_at
        ) VALUES (
            gen_random_uuid(),
            v_order_user_id,
            'Order Ready for Delivery!',
            'Your order is prepared and Drone DRN-001 has been assigned for pickup.',
            'order_ready',
            false,
            v_delivery_id,
            now()
        );
    END IF;

    RETURN json_build_object(
        'delivery_id', v_delivery_id,
        'drone_id', v_drone_id,
        'order_status', 'ready_for_delivery',
        'delivery_status', 'in_transit'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.vendor_mark_order_ready(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.vendor_mark_order_ready(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.vendor_mark_order_ready(uuid) TO authenticated;
