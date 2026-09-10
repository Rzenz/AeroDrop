-- ============================================================
-- AERODROP MISSING CAPABILITIES FORWARD MIGRATION
-- File: supabase/migrations/02_missing_capabilities.sql
--
-- Deploys the three missing capabilities identified during the remote audit:
-- 1. public.record_simulated_telemetry(...)
--    - Secures telemetry updates to in-transit deliveries
--    - Uses current drone_telemetry schema
-- 2. public.delete_user_account(uuid)
--    - Admin-only permanent account deletion
--    - Prevents self-deletion
--    - Cascades to public.users and preserves historical orders (ON DELETE SET NULL)
-- 3. public.place_order(...)
--    - Atomic transaction with row-level locks (FOR UPDATE)
--    - Strict stock sufficiency verification
--    - Maximum 500g drone payload limit validation
--    - Order & Order items creation matching current schema
-- ============================================================

-- ============================================================
-- 1. RECORD SIMULATED TELEMETRY RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.record_simulated_telemetry(
    p_delivery_id uuid,
    p_latitude double precision,
    p_longitude double precision,
    p_altitude double precision,
    p_speed double precision,
    p_battery_level double precision,
    p_signal_strength integer,
    p_heading double precision DEFAULT 0.0
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_drone_id uuid;
    v_user_role text;
    v_order_user_id uuid;
    v_order_vendor_id uuid;
    v_delivery_status text;
BEGIN
    -- 1. Check authentication
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- 2. Verify delivery exists and get drone_id, status, and order ownership
    SELECT 
        d.drone_id,
        d.status,
        o.user_id,
        o.vendor_id
    INTO 
        v_drone_id,
        v_delivery_status,
        v_order_user_id,
        v_order_vendor_id
    FROM public.deliveries d
    JOIN public.orders o ON d.order_id = o.id
    WHERE d.id = p_delivery_id;

    IF v_drone_id IS NULL THEN
        RAISE EXCEPTION 'Delivery does not exist or has no drone assigned';
    END IF;

    -- 3. Verify delivery status is in_transit
    IF v_delivery_status != 'in_transit' THEN
        RAISE EXCEPTION 'Delivery is not in transit';
    END IF;

    -- 4. Check caller role and authorization
    SELECT role INTO v_user_role
    FROM public.users
    WHERE id = auth.uid();

    IF v_user_role = 'admin' THEN
        -- Admins are always authorized
    ELSIF v_user_role = 'vendor' THEN
        IF auth.uid() != v_order_vendor_id THEN
            RAISE EXCEPTION 'Unauthorized: Vendor does not own this order';
        END IF;
    ELSE
        IF auth.uid() != v_order_user_id THEN
            RAISE EXCEPTION 'Unauthorized: User does not own this order';
        END IF;
    END IF;

    -- 5. Validate parameters
    IF p_latitude IS NULL OR p_longitude IS NULL THEN
        RAISE EXCEPTION 'Latitude and longitude are required';
    END IF;

    IF p_battery_level < 0 OR p_battery_level > 100 THEN
        RAISE EXCEPTION 'Battery level must be between 0 and 100';
    END IF;

    IF p_signal_strength < 0 OR p_signal_strength > 100 THEN
        RAISE EXCEPTION 'Signal strength must be between 0 and 100';
    END IF;

    -- 6. Insert telemetry record using current schema
    INSERT INTO public.drone_telemetry (
        drone_id,
        delivery_id,
        latitude,
        longitude,
        altitude,
        speed,
        battery_level,
        signal_strength,
        event_type,
        recorded_at
    ) VALUES (
        v_drone_id,
        p_delivery_id,
        p_latitude,
        p_longitude,
        p_altitude,
        p_speed,
        p_battery_level,
        p_signal_strength,
        'in_flight',
        now()
    );

    -- 7. Update drone battery level
    UPDATE public.drones
    SET 
        battery_level = p_battery_level,
        updated_at = now()
    WHERE id = v_drone_id;
END;
$$;

REVOKE ALL ON FUNCTION public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, integer, double precision) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, integer, double precision) FROM anon;
GRANT EXECUTE ON FUNCTION public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, integer, double precision) TO authenticated;

-- ============================================================
-- 2. PERMANENT USER DELETION RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.delete_user_account(p_target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
    -- 1. Check authenticated caller
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- 2. Check admin role
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only administrators can delete accounts';
    END IF;

    -- 3. Block self-deletion
    IF auth.uid() = p_target_user_id THEN
        RAISE EXCEPTION 'You cannot delete your own administrator account.';
    END IF;

    -- 4. Delete target user from auth.users (cascades to public.users via users_id_fkey)
    DELETE FROM auth.users WHERE id = p_target_user_id;

    -- Fallback: Ensure public.users record is removed if no cascade happened
    DELETE FROM public.users WHERE id = p_target_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_user_account(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_user_account(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_user_account(uuid) TO authenticated;

-- Preserve historical orders through ON DELETE SET NULL on orders.user_id
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = 'public.orders'::regclass
          AND confrelid = 'public.users'::regclass
          AND conname = 'orders_user_id_fkey'
    ) LOOP
        EXECUTE 'ALTER TABLE public.orders DROP CONSTRAINT ' || quote_ident(r.conname);
    END LOOP;
    
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Could not recreate orders_user_id_fkey constraint: %', SQLERRM;
END $$;

-- ============================================================
-- 3. ATOMIC ORDER PLACEMENT RPC WITH 500G PAYLOAD LIMIT
-- ============================================================

CREATE OR REPLACE FUNCTION public.place_order(
    p_vendor_id uuid,
    p_delivery_location_id uuid,
    p_subtotal numeric,
    p_delivery_fee numeric,
    p_total_amount numeric,
    p_payment_method text,
    p_items jsonb
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

    -- 4. Second pass: Deduct stock for all products
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity := (v_item->>'quantity')::integer;

        UPDATE public.products
        SET 
            stock_quantity = stock_quantity - v_quantity,
            updated_at = now()
        WHERE id = v_product_id;
    END LOOP;

    -- 5. Determine payment status & reference
    IF p_payment_method = 'gcash_simulated' THEN
        v_payment_status := 'paid';
    ELSE
        v_payment_status := 'pending';
    END IF;
    v_payment_ref := 'PAY-' || extract(epoch from now())::bigint;

    -- 6. Insert Order
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
        now(),
        now()
    ) RETURNING id INTO v_order_id;

    -- 7. Insert Order Items (using current order_items schema)
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

    RETURN v_order_id;
END;
$$;

REVOKE ALL ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb) TO authenticated;
