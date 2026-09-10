-- 02_functions.sql
-- Implements backend support functions and atomic transactions in Supabase.

-- 1. TRANSACTION: PLACE ORDER (with stock check/deduction)
CREATE OR REPLACE FUNCTION public.place_order(
    p_user_id uuid,
    p_vendor_id uuid,
    p_dropoff_location_id uuid,
    p_total_amount numeric,
    p_items jsonb
)
RETURNS uuid AS $$
DECLARE
    v_order_id uuid;
    v_item jsonb;
    v_product_id uuid;
    v_quantity integer;
    v_price numeric;
    v_stock integer;
    v_pending_status_id uuid;
BEGIN
    -- Get pending order status
    SELECT id INTO v_pending_status_id FROM public.order_statuses WHERE name = 'pending';
    
    -- Insert parent order
    INSERT INTO public.orders (
        id, user_id, vendor_id, order_status_id, dropoff_location_id, total_amount, created_at, updated_at
    ) VALUES (
        gen_random_uuid(), p_user_id, p_vendor_id, v_pending_status_id, p_dropoff_location_id, p_total_amount, now(), now()
    ) RETURNING id INTO v_order_id;

    -- Loop over items, check stock, insert item records, decrement stock
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity := (v_item->>'quantity')::integer;
        v_price := (v_item->>'unit_price')::numeric;

        -- Check stock
        SELECT stock INTO v_stock FROM public.products WHERE id = v_product_id FOR UPDATE;
        IF v_stock < v_quantity THEN
            RAISE EXCEPTION 'Insufficient stock for product %', v_product_id;
        END IF;

        -- Decrement stock
        UPDATE public.products 
        SET stock = stock - v_quantity 
        WHERE id = v_product_id;

        -- Insert order item
        INSERT INTO public.order_items (
            id, order_id, product_id, quantity, unit_price, subtotal, created_at
        ) VALUES (
            gen_random_uuid(), v_order_id, v_product_id, v_quantity, v_price, (v_price * v_quantity), now()
        );
    END LOOP;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. TRANSACTION: VENDOR CONFIRM ORDER (starts preparing)
CREATE OR REPLACE FUNCTION public.confirm_order(
    p_order_id uuid
)
RETURNS boolean AS $$
DECLARE
    v_preparing_status_id uuid;
BEGIN
    SELECT id INTO v_preparing_status_id FROM public.order_statuses WHERE name = 'preparing';
    
    UPDATE public.orders 
    SET order_status_id = v_preparing_status_id, updated_at = now()
    WHERE id = p_order_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. TRANSACTION: PACKAGE VERIFICATION
CREATE OR REPLACE FUNCTION public.verify_package(
    p_delivery_package_id uuid,
    p_photo_url text,
    p_remarks text,
    p_verified_by uuid
)
RETURNS boolean AS $$
DECLARE
    v_verified_status_id uuid;
BEGIN
    SELECT id INTO v_verified_status_id FROM public.package_verification_statuses WHERE name = 'verified';
    
    INSERT INTO public.package_verifications (
        id, delivery_package_id, package_verification_status_id, photo_url, remarks, verified_by, verified_at, created_at, updated_at
    ) VALUES (
        gen_random_uuid(), p_delivery_package_id, v_verified_status_id, p_photo_url, p_remarks, p_verified_by, now(), now(), now()
    );
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
