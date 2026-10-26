-- ============================================================================
-- 23_multi_trip_deliveries.sql
--
-- WHAT THIS ADDS
-- An order heavier than one drone load is no longer rejected. The customer is
-- warned in the cart, and may choose to continue; the drone then flies the
-- order in several trips, and the delivery fee reflects that.
--
-- BEFORE: place_order raised
--   'This order exceeds the drone's maximum payload of 0.5 kg'
-- and vendor_mark_order_ready raised
--   'Total cargo weight exceeds drone maximum payload limit'
-- Either way the customer hit a dead end at checkout.
--
-- AFTER: up to 2 trips (1.0 kg) are accepted. Anything heavier is still
-- refused, with a message telling the customer to split the order.
--
-- FLIGHT PATTERN
-- A multi-trip order repeats the existing cycle rather than inventing a new
-- leg type:
--     Hub -> Vendor -> Customer -> Hub        (trip 1)
--     Hub -> Vendor -> Customer -> Hub        (trip 2)
-- The drone reloads at base between trips. This reuses the proven leg
-- machinery in delivery_provider.dart untouched; a direct Customer -> Vendor
-- shuttle would need a new leg type, new drone states, and changes to the
-- leg-inference code.
--
-- HOW THE TRIP LOOP IS WIRED
--   * complete_delivery_order() now completes a TRIP. Only the final trip
--     marks the delivery 'delivered'. Between trips the delivery deliberately
--     stays 'in_transit', so weather grounding, drone self-healing and the
--     admin radar keep treating the order as active with no changes.
--   * dispatch_next_queued_delivery() resumes an order that still owes trips
--     before it looks at the queue. It lives there rather than in
--     complete_drone_return() so that recover_stale_returning_drone() also
--     resumes an interrupted multi-trip order.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-22. The four functions below
-- are their current definitions (place_order and vendor_mark_order_ready from
-- migration 16, complete_delivery_order from 08, dispatch_next_queued_delivery
-- from 10) with only the multi-trip changes applied.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Columns
-- ----------------------------------------------------------------------------
ALTER TABLE public.orders
    ADD COLUMN IF NOT EXISTS trips_required integer NOT NULL DEFAULT 1;

ALTER TABLE public.deliveries
    ADD COLUMN IF NOT EXISTS trips_required integer NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS trips_completed integer NOT NULL DEFAULT 0;

ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_trips_required_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_trips_required_check
    CHECK (trips_required BETWEEN 1 AND 2);

ALTER TABLE public.deliveries DROP CONSTRAINT IF EXISTS deliveries_trips_check;
ALTER TABLE public.deliveries ADD CONSTRAINT deliveries_trips_check
    CHECK (trips_required BETWEEN 1 AND 2
           AND trips_completed >= 0
           AND trips_completed <= trips_required);


-- ----------------------------------------------------------------------------
-- 2. place_order - accept up to 2 trips, record trips_required
-- ----------------------------------------------------------------------------
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
    v_trips_required integer := 1;
    v_max_trips constant integer := 2;
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

    -- 3. Multi-trip payload check.
    --    One drone trip carries 500 g. An order heavier than that is flown in
    --    several trips instead of being rejected, up to v_max_trips.
    v_trips_required := greatest(1, ceil(v_total_weight_grams::numeric / 500.0)::integer);

    IF v_trips_required > v_max_trips THEN
        RAISE EXCEPTION 'This order weighs % kg and would need % drone trips. The maximum is % trips (% kg). Please split it into separate orders.',
            round((v_total_weight_grams::numeric / 1000.0), 2),
            v_trips_required,
            v_max_trips,
            round((v_max_trips * 0.5)::numeric, 1);
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
        trips_required,
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
        v_trips_required,
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


-- ----------------------------------------------------------------------------
-- 3. vendor_mark_order_ready - recompute trips at dispatch, scale battery
-- ----------------------------------------------------------------------------
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
    v_payload_cap double precision;
    v_trips_required integer := 1;
    v_max_trips constant integer := 2;

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

    -- Multi-trip: one trip carries max_payload_kg, and an order may use up to
    -- v_max_trips of them. Recomputed here rather than trusted from the order,
    -- so a stock or weight change since checkout is caught at dispatch.
    v_payload_cap := coalesce(v_drone_max_payload, 0.5);
    v_trips_required := greatest(1, ceil(v_total_weight_kg / v_payload_cap)::integer);

    IF v_trips_required > v_max_trips THEN
        RAISE EXCEPTION 'Total cargo weight (% kg) would need % drone trips; the maximum is %.',
            round(v_total_weight_kg::numeric, 2), v_trips_required, v_max_trips;
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
    -- Battery must cover every trip this order needs, not just the first.
    IF v_drone_status = 'available'
       AND (v_drone_battery IS NULL OR v_drone_battery >= (15.0 * v_trips_required)) THEN
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
                estimated_delivery_seconds = 720 * v_trips_required,
                progress = 0,
                trips_required = v_trips_required,
                trips_completed = 0,
                updated_at = now()
            WHERE id = v_delivery_id;
        ELSE
            INSERT INTO public.deliveries (
                order_id, drone_id, status, pickup_location_id, dropoff_location_id,
                delivery_started_at, delivery_completed_at, estimated_delivery_seconds, progress,
                trips_required, trips_completed, created_at, updated_at
            ) VALUES (
                p_order_id, v_drone_id, 'assigning', v_pickup_location_id, v_dropoff_location_id,
                NULL, NULL, 720 * v_trips_required, 0,
                v_trips_required, 0, now(), now()
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
                trips_required = v_trips_required,
                trips_completed = 0,
                updated_at = now()
            WHERE id = v_delivery_id;
        ELSE
            INSERT INTO public.deliveries (
                order_id, drone_id, status, pickup_location_id, dropoff_location_id,
                delivery_started_at, delivery_completed_at, estimated_delivery_seconds, progress,
                trips_required, trips_completed, created_at, updated_at
            ) VALUES (
                p_order_id, NULL, 'pending', v_pickup_location_id, v_dropoff_location_id,
                NULL, NULL, 720 * v_trips_required, 0,
                v_trips_required, 0, now(), now()
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

GRANT EXECUTE ON FUNCTION public.vendor_mark_order_ready(uuid) TO authenticated;


-- ----------------------------------------------------------------------------
-- 4. complete_delivery_order - complete a TRIP; only the last one delivers
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_delivery_order(p_delivery_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order_id uuid;
    v_drone_id uuid;
    v_status text;
    v_order_user_id uuid;
    v_order_vendor_id uuid;
    v_user_role text;
    v_trips_required integer := 1;
    v_trips_completed integer := 0;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT
        d.order_id,
        d.drone_id,
        d.status,
        o.user_id,
        o.vendor_id
    INTO
        v_order_id,
        v_drone_id,
        v_status,
        v_order_user_id,
        v_order_vendor_id
    FROM public.deliveries d
    JOIN public.orders o ON d.order_id = o.id
    WHERE d.id = p_delivery_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Delivery not found';
    END IF;

    SELECT role INTO v_user_role FROM public.users WHERE id = auth.uid();
    IF v_user_role != 'admin' AND auth.uid() != v_order_vendor_id AND auth.uid() != v_order_user_id THEN
        RAISE EXCEPTION 'Unauthorized: Caller cannot complete this delivery';
    END IF;

    IF v_status = 'delivered' THEN
        -- Defensive update: ensure progress is 1.0 even if already marked delivered
        UPDATE public.deliveries
        SET progress = 1.0, updated_at = now()
        WHERE id = p_delivery_id AND (progress IS NULL OR progress < 1.0);

        RETURN json_build_object(
            'success', true,
            'delivery_id', p_delivery_id,
            'status', 'delivered',
            'already_processed', true
        );
    END IF;

    -- ------------------------------------------------------------------
    -- MULTI-TRIP: an order heavier than one drone load arrives in stages.
    -- This arrival finishes the CURRENT trip; only the last one finishes the
    -- order. The delivery deliberately stays 'in_transit' between trips, so
    -- every existing query that treats the order as active (weather
    -- grounding, drone self-healing, the admin radar) keeps working unchanged.
    -- ------------------------------------------------------------------
    SELECT coalesce(trips_required, 1), coalesce(trips_completed, 0)
    INTO v_trips_required, v_trips_completed
    FROM public.deliveries
    WHERE id = p_delivery_id;

    v_trips_completed := v_trips_completed + 1;

    IF v_trips_completed < v_trips_required THEN
        UPDATE public.deliveries
        SET trips_completed = v_trips_completed,
            progress = 0,
            updated_at = now()
        WHERE id = p_delivery_id;

        -- handle_delivery_drone_release() only fires on terminal statuses, so
        -- the drone is sent home explicitly here.
        IF v_drone_id IS NOT NULL THEN
            UPDATE public.drones
            SET status = 'returning',
                returning_started_at = now(),
                sim_lease_holder = NULL,
                sim_lease_until = NULL,
                updated_at = now()
            WHERE id = v_drone_id;
        END IF;

        INSERT INTO public.delivery_status_logs (
            delivery_id, status, message, changed_by, created_at
        ) VALUES (
            p_delivery_id,
            'in_transit',
            'Trip ' || v_trips_completed || ' of ' || v_trips_required ||
            ' delivered. Drone returning to base to collect the remaining items.',
            auth.uid(),
            now()
        );

        IF v_order_user_id IS NOT NULL THEN
            INSERT INTO public.notifications (
                id, user_id, title, message, notification_type, is_read,
                related_delivery_id, created_at
            ) VALUES (
                gen_random_uuid(),
                v_order_user_id,
                'Part ' || v_trips_completed || ' of ' || v_trips_required || ' delivered',
                'Your order needs ' || v_trips_required ||
                ' drone trips. Part ' || v_trips_completed ||
                ' has arrived; the drone is returning to base to collect the rest.',
                'delivery_trip_completed',
                false,
                p_delivery_id,
                now()
            );
        END IF;

        RETURN json_build_object(
            'success', true,
            'delivery_id', p_delivery_id,
            'order_id', v_order_id,
            'status', 'in_transit',
            'trips_completed', v_trips_completed,
            'trips_required', v_trips_required,
            'more_trips', true
        );
    END IF;

    -- Final trip: record it, then complete the order normally.
    UPDATE public.deliveries
    SET trips_completed = v_trips_completed, updated_at = now()
    WHERE id = p_delivery_id;

    -- Update delivery to delivered with exact progress 1.0
    UPDATE public.deliveries
    SET
        status = 'delivered',
        delivery_completed_at = now(),
        progress = 1.0,
        updated_at = now()
    WHERE id = p_delivery_id;

    -- Update order to delivered
    UPDATE public.orders
    SET
        order_status = 'delivered',
        updated_at = now()
    WHERE id = v_order_id;

    -- Log transition
    INSERT INTO public.delivery_status_logs (
        delivery_id,
        status,
        message,
        changed_by,
        created_at
    ) VALUES (
        p_delivery_id,
        'delivered',
        'Order delivered safely at dropoff point.',
        auth.uid(),
        now()
    );

    RETURN json_build_object(
        'success', true,
        'delivery_id', p_delivery_id,
        'order_id', v_order_id,
        'status', 'delivered'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.complete_delivery_order(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_delivery_order(uuid) TO authenticated;


-- ----------------------------------------------------------------------------
-- 5. dispatch_next_queued_delivery - resume a part-flown order first
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dispatch_next_queued_delivery(p_drone_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_drone_status text;
    v_drone_battery double precision;
    v_next_delivery_id uuid;
    v_next_order_id uuid;
    v_next_order_user_id uuid;
    v_next_order_vendor_id uuid;
    v_pickup_location_id uuid;
    v_dropoff_location_id uuid;
    v_weather_status text;
    v_trip_delivery_id uuid;
    v_trip_done integer;
    v_trip_total integer;
BEGIN
    -- Check weather safety
    SELECT safety_status INTO v_weather_status
    FROM public.weather_safety
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_weather_status = 'grounded' THEN
        RETURN false;
    END IF;

    -- Query drone status & battery
    SELECT status, battery_level
    INTO v_drone_status, v_drone_battery
    FROM public.drones
    WHERE id = p_drone_id
    FOR UPDATE;

    IF NOT FOUND OR v_drone_status != 'available' OR (v_drone_battery IS NOT NULL AND v_drone_battery < 15.0) THEN
        RETURN false;
    END IF;

    -- ------------------------------------------------------------------
    -- MULTI-TRIP: an order that still owes trips outranks the queue. Placed
    -- here rather than in complete_drone_return() so that every caller --
    -- the normal return and recover_stale_returning_drone() alike -- resumes
    -- an interrupted multi-trip order instead of starting someone else's.
    -- ------------------------------------------------------------------
    SELECT d.id, coalesce(d.trips_completed, 0), coalesce(d.trips_required, 1)
    INTO v_trip_delivery_id, v_trip_done, v_trip_total
    FROM public.deliveries d
    WHERE d.drone_id = p_drone_id
      AND d.status = 'in_transit'
      AND coalesce(d.trips_completed, 0) < coalesce(d.trips_required, 1)
    ORDER BY d.updated_at
    LIMIT 1
    FOR UPDATE;

    IF v_trip_delivery_id IS NOT NULL THEN
        UPDATE public.deliveries
        SET status = 'assigning',
            progress = 0,
            delivery_started_at = NULL,
            updated_at = now()
        WHERE id = v_trip_delivery_id;

        UPDATE public.drones
        SET status = 'assigned',
            returning_started_at = NULL,
            sim_lease_holder = NULL,
            sim_lease_until = NULL,
            updated_at = now()
        WHERE id = p_drone_id;

        INSERT INTO public.delivery_status_logs (
            delivery_id, status, message, changed_by, created_at
        ) VALUES (
            v_trip_delivery_id,
            'assigning',
            'Drone dispatched to vendor for trip ' || (v_trip_done + 1) ||
            ' of ' || v_trip_total || '.',
            auth.uid(),
            now()
        );

        RETURN true;
    END IF;

    -- Find oldest queued delivery with an order ready_for_delivery
    SELECT
        d.id,
        d.order_id,
        o.user_id,
        o.vendor_id,
        o.delivery_location_id,
        u.campus_location_id
    INTO
        v_next_delivery_id,
        v_next_order_id,
        v_next_order_user_id,
        v_next_order_vendor_id,
        v_dropoff_location_id,
        v_pickup_location_id
    FROM public.deliveries d
    JOIN public.orders o ON d.order_id = o.id
    LEFT JOIN public.users u ON o.vendor_id = u.id
    WHERE d.status = 'pending'
      AND o.order_status = 'ready_for_delivery'
    ORDER BY d.created_at ASC
    LIMIT 1
    FOR UPDATE OF d SKIP LOCKED;

    IF v_next_delivery_id IS NULL THEN
        RETURN false;
    END IF;

    -- Assign drone & transition delivery to assigning
    UPDATE public.deliveries
    SET
        drone_id = p_drone_id,
        status = 'assigning',
        pickup_location_id = coalesce(pickup_location_id, v_pickup_location_id),
        dropoff_location_id = coalesce(dropoff_location_id, v_dropoff_location_id),
        delivery_started_at = NULL,
        delivery_completed_at = NULL,
        progress = 0,
        updated_at = now()
    WHERE id = v_next_delivery_id;

    UPDATE public.drones
    SET
        status = 'assigned',
        returning_started_at = NULL,
        sim_lease_holder = NULL,
        sim_lease_until = NULL,
        updated_at = now()
    WHERE id = p_drone_id;

    -- Log transition
    INSERT INTO public.delivery_status_logs (
        delivery_id, status, message, changed_by, created_at
    ) VALUES (
        v_next_delivery_id,
        'assigning',
        'Drone auto-assigned from queue and dispatched for pickup.',
        v_next_order_vendor_id,
        now()
    );

    -- Notify customer
    IF v_next_order_user_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            id, user_id, title, message, notification_type, is_read, related_delivery_id, created_at
        ) VALUES (
            gen_random_uuid(),
            v_next_order_user_id,
            'Drone Dispatched to Vendor',
            'Drone DRN-001 is now en route to the vendor to pick up your queued order.',
            'drone_dispatched',
            false,
            v_next_delivery_id,
            now()
        );
    END IF;

    -- Notify vendor
    IF v_next_order_vendor_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            id, user_id, title, message, notification_type, is_read, related_delivery_id, created_at
        ) VALUES (
            gen_random_uuid(),
            v_next_order_vendor_id,
            'Drone Heading to Pickup',
            'Drone DRN-001 is now dispatched to pick up the queued order from your shop.',
            'drone_dispatched',
            false,
            v_next_delivery_id,
            now()
        );
    END IF;

    RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.dispatch_next_queued_delivery(uuid) FROM PUBLIC, anon, authenticated;
