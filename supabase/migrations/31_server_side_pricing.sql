-- ============================================================================
-- 31_server_side_pricing.sql
--
-- THE HOLE
-- Until now a client decided what an order cost, in three separate ways:
--   1. orders_insert let any signed-in user write an order row directly,
--      skipping place_order entirely: no stock check, no weight or trip
--      calculation, no weather grounding, and any total they liked.
--   2. place_order accepted p_subtotal, p_delivery_fee and p_total_amount as
--      parameters and stored them without deriving either.
--   3. place_order read each product's name, stock and weight from the table
--      but took unit_price from the client's payload.
-- The publishable key needed to exploit any of these ships inside the APK.
--
-- THE FIX
-- One pricing function, server-side, that both the order path and the clients
-- use. Nothing a client sends can change what an order costs.
--
--   compute_order_pricing()  derives subtotal, weight, trips, distance and
--                            every fee component from product rows and campus
--                            coordinates. The single source of truth.
--   quote_order_fee()        the same numbers for display at checkout, so a
--                            client never computes a price it will be charged.
--   place_order()            calls compute_order_pricing, uses database unit
--                            prices, and ignores the three amount parameters.
--                            They stay in the signature so neither client
--                            breaks on deploy.
--   orders_insert            dropped. Verified first: neither the Flutter app
--                            nor the website inserts orders directly; both
--                            call place_order (order_provider.dart:226 and
--                            website/src/data/live-api.ts:351).
--
-- WHY A QUOTE FUNCTION RATHER THAN SERVER VALIDATION
-- Checking the client's figure and rejecting a mismatch sounds simpler, but
-- the two sides would have to agree exactly, forever. They already disagree:
-- the Flutter checkout resolves a vendor's location by campus_location_id and
-- then falls back to fuzzy-matching a building name, which no sane server
-- implementation would copy. One formula that both sides read removes the
-- class of bug instead of policing it.
--
-- THE FORMULA mirrors DeliveryFeeCalculator exactly, so displayed prices do
-- not move:
--   base PHP 15.00 once; distance PHP 40.00/km multiplied by trips; weight
--   PHP 10.00/kg on the real total capped at 1.0 kg; PHP 25.00 per trip beyond
--   the first; PHP 5.00 once in caution weather; rounded to 2 decimals and
--   never below the base fee. A distance at or under 5 m counts as zero.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-30:
--   public.products: id, price, weight_grams, stock_quantity, vendor_id
--   public.campus_locations: id, latitude, longitude
--   public.users: id, campus_location_id
--   public.weather_safety: safety_status
--   place_order's current definition is migration 23's.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Distance between two campus points
--
-- Haversine on a 6371 km sphere, matching DeliveryFeeCalculator. Returns 0
-- when either point has no coordinates, so a missing location cannot inflate
-- or block a fee.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.campus_distance_km(
    p_from_location_id uuid,
    p_to_location_id   uuid
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    a_lat double precision; a_lng double precision;
    b_lat double precision; b_lng double precision;
    d_lat double precision; d_lng double precision;
    h     double precision;
    km    numeric;
BEGIN
    IF p_from_location_id IS NULL OR p_to_location_id IS NULL THEN
        RETURN 0;
    END IF;

    SELECT latitude, longitude INTO a_lat, a_lng
    FROM public.campus_locations WHERE id = p_from_location_id;

    SELECT latitude, longitude INTO b_lat, b_lng
    FROM public.campus_locations WHERE id = p_to_location_id;

    IF a_lat IS NULL OR a_lng IS NULL OR b_lat IS NULL OR b_lng IS NULL THEN
        RETURN 0;
    END IF;

    d_lat := radians(b_lat - a_lat);
    d_lng := radians(b_lng - a_lng);

    h := sin(d_lat / 2) * sin(d_lat / 2)
         + cos(radians(a_lat)) * cos(radians(b_lat))
           * sin(d_lng / 2) * sin(d_lng / 2);

    km := (6371.0 * 2 * atan2(sqrt(h), sqrt(1 - h)))::numeric;

    -- Same floor as the client: anything under 5 m is the same place.
    IF km <= 0.005 THEN
        RETURN 0;
    END IF;

    RETURN km;
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. The pricing authority
--
-- Everything an order costs, derived from the database. Raises on input it
-- cannot price; says nothing about stock or weather, which place_order checks.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.compute_order_pricing(
    p_vendor_id            uuid,
    p_delivery_location_id uuid,
    p_items                jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    c_base_fee        constant numeric := 15.00;
    c_rate_per_km     constant numeric := 40.00;
    c_rate_per_kg     constant numeric := 10.00;
    c_extra_trip_fee  constant numeric := 25.00;
    c_caution_fee     constant numeric := 5.00;
    c_payload_grams   constant integer := 500;
    c_max_trips       constant integer := 2;

    v_item          jsonb;
    v_product_id    uuid;
    v_quantity      integer;
    v_price         numeric;
    v_weight_grams  integer;
    v_vendor_of     uuid;

    v_subtotal      numeric := 0;
    v_total_grams   integer := 0;
    v_trips         integer := 1;
    v_distance_km   numeric := 0;
    v_capped_kg     numeric := 0;
    v_is_caution    boolean := false;

    v_fee_distance  numeric := 0;
    v_fee_weight    numeric := 0;
    v_fee_trips     numeric := 0;
    v_fee_weather   numeric := 0;
    v_fee_total     numeric := 0;

    v_vendor_loc    uuid;
BEGIN
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Order contains no items';
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity   := (v_item->>'quantity')::integer;

        IF v_quantity IS NULL OR v_quantity <= 0 THEN
            RAISE EXCEPTION 'Quantity must be greater than zero';
        END IF;

        SELECT price, coalesce(weight_grams, 0), vendor_id
        INTO v_price, v_weight_grams, v_vendor_of
        FROM public.products
        WHERE id = v_product_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Product not found: %', v_product_id;
        END IF;

        IF v_price IS NULL THEN
            RAISE EXCEPTION 'Product has no price: %', v_product_id;
        END IF;

        -- An order belongs to one vendor; mixing them would make the pickup
        -- point meaningless and the distance arbitrary.
        IF p_vendor_id IS NOT NULL AND v_vendor_of IS DISTINCT FROM p_vendor_id THEN
            RAISE EXCEPTION 'Product % does not belong to this vendor', v_product_id;
        END IF;

        v_subtotal    := v_subtotal + (v_price * v_quantity);
        v_total_grams := v_total_grams + (v_weight_grams * v_quantity);
    END LOOP;

    v_trips := greatest(1, ceil(v_total_grams::numeric / c_payload_grams)::integer);

    SELECT campus_location_id INTO v_vendor_loc
    FROM public.users WHERE id = p_vendor_id;

    v_distance_km := public.campus_distance_km(v_vendor_loc, p_delivery_location_id);

    SELECT (safety_status = 'caution') INTO v_is_caution
    FROM public.weather_safety
    ORDER BY updated_at DESC
    LIMIT 1;
    v_is_caution := coalesce(v_is_caution, false);

    v_capped_kg := least(v_total_grams::numeric / 1000.0,
                         (c_payload_grams * c_max_trips)::numeric / 1000.0);

    v_fee_distance := round(v_distance_km * c_rate_per_km * v_trips, 2);
    v_fee_weight   := round(v_capped_kg * c_rate_per_kg, 2);
    v_fee_trips    := c_extra_trip_fee * (v_trips - 1);
    v_fee_weather  := CASE WHEN v_is_caution THEN c_caution_fee ELSE 0 END;

    v_fee_total := round(
        greatest(c_base_fee,
                 c_base_fee + v_fee_distance + v_fee_weight + v_fee_trips + v_fee_weather),
        2);

    RETURN jsonb_build_object(
        'subtotal',       round(v_subtotal, 2),
        'delivery_fee',   v_fee_total,
        'total_amount',   round(v_subtotal + v_fee_total, 2),
        'total_weight_grams', v_total_grams,
        'trips_required', v_trips,
        'distance_km',    round(v_distance_km, 4),
        'is_caution',     v_is_caution,
        'breakdown', jsonb_build_object(
            'base',       c_base_fee,
            'distance',   v_fee_distance,
            'weight',     v_fee_weight,
            'extra_trip', v_fee_trips,
            'weather',    v_fee_weather
        )
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. The same numbers, for display
--
-- Clients call this at checkout instead of pricing an order themselves, so the
-- figure shown and the figure charged come from one place and cannot drift.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.quote_order_fee(
    p_vendor_id            uuid,
    p_delivery_location_id uuid,
    p_items                jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN public.compute_order_pricing(p_vendor_id, p_delivery_location_id, p_items);
END;
$$;

-- ----------------------------------------------------------------------------
-- 4. place_order, with every amount derived here
--
-- This is migration 23's definition with three changes: unit prices now come
-- from the product row, the stored amounts come from compute_order_pricing,
-- and the three amount parameters are ignored.
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
    v_pricing jsonb;
    v_srv_subtotal numeric;
    v_srv_delivery_fee numeric;
    v_srv_total numeric;
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
    -- ------------------------------------------------------------------
    -- SERVER-SIDE PRICING (migration 31)
    -- p_subtotal, p_delivery_fee and p_total_amount are accepted for
    -- backward compatibility and deliberately ignored. Every amount stored
    -- below is derived here, from product rows and campus coordinates, so a
    -- crafted request cannot set its own price. Clients display the same
    -- numbers by calling quote_order_fee(), which runs this same function.
    -- ------------------------------------------------------------------
    v_pricing := public.compute_order_pricing(p_vendor_id, p_delivery_location_id, p_items);

    v_srv_subtotal     := (v_pricing->>'subtotal')::numeric;
    v_srv_delivery_fee := (v_pricing->>'delivery_fee')::numeric;
    v_srv_total        := (v_pricing->>'total_amount')::numeric;

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
        v_srv_subtotal,
        v_srv_delivery_fee,
        v_srv_total,
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
        -- Price comes from the product row, never from the client payload.
        SELECT price INTO v_unit_price
        FROM public.products WHERE id = v_product_id;
        IF v_unit_price IS NULL THEN
            RAISE EXCEPTION 'Product has no price: %', v_product_id;
        END IF;
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


-- ----------------------------------------------------------------------------
-- 5. Close the direct-insert path
--
-- With prices derived server-side, a direct insert is the only remaining way
-- to create an order the system never validated: no stock reservation, no
-- payload ceiling, no weather grounding, no delivery row.
--
-- Checked before dropping: neither client inserts orders directly.
--   Flutter  lib/core/providers/order_provider.dart:226  rpc('place_order')
--   Website  website/src/data/live-api.ts:351            rpc('place_order')
-- The owner-cancel policy stays: it only lets a customer move their own
-- pending order to cancelled, which is a different operation.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS orders_insert ON public.orders;

-- ----------------------------------------------------------------------------
-- 6. Grants
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.campus_distance_km(uuid, uuid)             FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.compute_order_pricing(uuid, uuid, jsonb)   FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.quote_order_fee(uuid, uuid, jsonb) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.quote_order_fee(uuid, uuid, jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text) TO authenticated;
