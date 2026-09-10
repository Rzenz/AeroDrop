-- 15_order_visibility_and_atomic_placement.sql
-- 1. Fix RLS policies on public.orders to allow vendors to see their orders in the simplified schema

DROP POLICY IF EXISTS select_own_orders ON public.orders;
CREATE POLICY select_own_orders ON public.orders FOR SELECT USING (
  auth.uid() = user_id 
  OR public.is_admin(auth.uid()) 
  OR auth.uid() = vendor_id
);

-- Allow vendors to update order status for their orders
DROP POLICY IF EXISTS update_own_orders ON public.orders;
CREATE POLICY update_own_orders ON public.orders FOR UPDATE USING (
  auth.uid() = user_id
  OR public.is_admin(auth.uid())
  OR auth.uid() = vendor_id
);

-- Ensure select on order_items for users and vendors
DROP POLICY IF EXISTS select_order_items ON public.order_items;
CREATE POLICY select_order_items ON public.order_items FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_items.order_id
      AND (
        o.user_id = auth.uid()
        OR o.vendor_id = auth.uid()
        OR public.is_admin(auth.uid())
      )
  )
);

-- 2. Transactional & Atomic place_order RPC with:
--    - Maximum 500g payload validation
--    - FOR UPDATE product row locking
--    - Stock sufficiency check
--    - Inventory deduction
--    - Order & Order Items creation

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
            subtotal,
            created_at
        ) VALUES (
            gen_random_uuid(),
            v_order_id,
            v_product_id,
            coalesce(v_item->>'product_name', v_product_name),
            v_quantity,
            v_unit_price,
            v_weight_grams,
            v_item_subtotal,
            now()
        );
    END LOOP;

    RETURN v_order_id;
END;
$$;

-- Security permissions
REVOKE ALL ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb) TO authenticated;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';
