-- Migration: 04_drone_pickup_and_grants.sql
-- Description: Drone pickup lifecycle, campus locations coordinates, grants, and synchronized delivery RPCs.

-- 1. NOTIFICATIONS TABLE GRANT
-- ============================================================
-- Fixes runtime 42501 "permission denied for table notifications" when updating is_read/read_at
GRANT UPDATE, SELECT, INSERT ON public.notifications TO authenticated;

-- 2. CAMPUS LOCATIONS GEOLOCATION REPAIR
-- ============================================================
UPDATE public.campus_locations SET latitude = 10.3156, longitude = 123.9016 WHERE location_code = 'MAIN';
UPDATE public.campus_locations SET latitude = 10.3159, longitude = 123.9019 WHERE location_code = 'ANNEX-1';
UPDATE public.campus_locations SET latitude = 10.3154, longitude = 123.9021 WHERE location_code = 'ANNEX-2';
UPDATE public.campus_locations SET latitude = 10.3148, longitude = 123.9014 WHERE location_code = 'BASIC-ED';
UPDATE public.campus_locations SET latitude = 10.3163, longitude = 123.9025 WHERE location_code = 'MARITIME';

-- Fallback for any records matched by name
UPDATE public.campus_locations SET latitude = 10.3156, longitude = 123.9016 WHERE latitude IS NULL AND name ILIKE '%main%';
UPDATE public.campus_locations SET latitude = 10.3156, longitude = 123.9016 WHERE latitude IS NULL AND name ILIKE '%old%';
UPDATE public.campus_locations SET latitude = 10.3159, longitude = 123.9019 WHERE latitude IS NULL AND name ILIKE '%annex 1%';
UPDATE public.campus_locations SET latitude = 10.3154, longitude = 123.9021 WHERE latitude IS NULL AND name ILIKE '%annex 2%';
UPDATE public.campus_locations SET latitude = 10.3148, longitude = 123.9014 WHERE latitude IS NULL AND name ILIKE '%basic%';
UPDATE public.campus_locations SET latitude = 10.3163, longitude = 123.9025 WHERE latitude IS NULL AND name ILIKE '%maritime%';

-- 3. VENDOR MARK ORDER READY (CORRECT PICKUP LIFECYCLE)
-- ============================================================
-- Sets delivery status = 'assigning' and order status = 'ready_for_delivery'.
-- The package is STILL AT THE VENDOR until the drone arrives and package is picked up.
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
            'assigning',
            v_pickup_location_id,
            v_dropoff_location_id,
            NULL,
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
        'assigning',
        'Drone DRN-001 assigned and dispatched to vendor for package pickup.',
        auth.uid(),
        now()
    );

    -- Notify customer that order is ready and drone is en route to vendor
    IF v_order_user_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            id, user_id, title, message, notification_type, is_read, related_delivery_id, created_at
        ) VALUES (
            gen_random_uuid(),
            v_order_user_id,
            'Drone Dispatched to Vendor',
            'Drone DRN-001 is on its way to the vendor to pick up your order.',
            'drone_dispatched',
            false,
            v_delivery_id,
            now()
        );
    END IF;

    -- Notify vendor that drone is en route to their location
    INSERT INTO public.notifications (
        id, user_id, title, message, notification_type, is_read, related_delivery_id, created_at
    ) VALUES (
        gen_random_uuid(),
        auth.uid(),
        'Drone Heading to Pickup',
        'Drone DRN-001 has been dispatched to pick up the package from your shop.',
        'drone_dispatched',
        false,
        v_delivery_id,
        now()
    );

    RETURN json_build_object(
        'success', true,
        'order_id', p_order_id,
        'delivery_id', v_delivery_id,
        'drone_code', 'DRN-001',
        'order_status', 'ready_for_delivery',
        'delivery_status', 'assigning',
        'cargo_weight_kg', v_total_weight_kg
    );
END;
$$;

-- 4. TELEMETRY RECORDING RPC (SUPPORTS ASSIGNING & IN_TRANSIT)
-- ============================================================
-- Drop old signatures to avoid function overloading conflicts
DROP FUNCTION IF EXISTS public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, integer, double precision);
DROP FUNCTION IF EXISTS public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, integer, double precision, text, double precision);

CREATE OR REPLACE FUNCTION public.record_simulated_telemetry(
    p_delivery_id uuid,
    p_latitude double precision,
    p_longitude double precision,
    p_altitude double precision,
    p_speed double precision,
    p_battery_level double precision,
    p_signal_strength integer,
    p_heading double precision DEFAULT 0.0,
    p_event_type text DEFAULT 'in_flight',
    p_progress double precision DEFAULT NULL
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

    -- 3. Verify delivery is in an active flight phase
    IF v_delivery_status NOT IN ('assigning', 'in_transit') THEN
        RAISE EXCEPTION 'Delivery is not currently active (status: %)', v_delivery_status;
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

    -- 6. Insert telemetry record
    INSERT INTO public.drone_telemetry (
        drone_id,
        delivery_id,
        latitude,
        longitude,
        altitude,
        speed,
        battery_level,
        signal_strength,
        heading,
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
        coalesce(p_heading, 0.0),
        coalesce(p_event_type, 'in_flight'),
        now()
    );

    -- 7. Update drone battery level
    UPDATE public.drones
    SET 
        battery_level = p_battery_level,
        updated_at = now()
    WHERE id = v_drone_id;

    -- 8. Optionally update progress on deliveries table
    IF p_progress IS NOT NULL THEN
        UPDATE public.deliveries
        SET
            progress = p_progress,
            updated_at = now()
        WHERE id = p_delivery_id;
    END IF;
END;
$$;

-- Provide 8-parameter overload for backward compatibility with older client calls
CREATE OR REPLACE FUNCTION public.record_simulated_telemetry(
    p_delivery_id uuid,
    p_latitude double precision,
    p_longitude double precision,
    p_altitude double precision,
    p_speed double precision,
    p_battery_level double precision,
    p_signal_strength integer,
    p_heading double precision
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM public.record_simulated_telemetry(
        p_delivery_id,
        p_latitude,
        p_longitude,
        p_altitude,
        p_speed,
        p_battery_level,
        p_signal_strength,
        p_heading,
        'in_flight',
        NULL
    );
END;
$$;

-- 5. CONFIRM PACKAGE PICKUP RPC
-- ============================================================
-- Transitions delivery from 'assigning' to 'in_transit' after drone arrives at vendor
CREATE OR REPLACE FUNCTION public.confirm_package_pickup(p_delivery_id uuid)
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

    -- Check caller authorization
    SELECT role INTO v_user_role FROM public.users WHERE id = auth.uid();
    IF v_user_role != 'admin' AND auth.uid() != v_order_vendor_id AND auth.uid() != v_order_user_id THEN
        RAISE EXCEPTION 'Unauthorized: Caller cannot confirm pickup for this delivery';
    END IF;

    IF v_status != 'assigning' THEN
        -- If already in_transit or delivered, return current state idempotently
        IF v_status IN ('in_transit', 'delivered') THEN
            RETURN json_build_object(
                'success', true,
                'delivery_id', p_delivery_id,
                'status', v_status,
                'already_processed', true
            );
        END IF;
        RAISE EXCEPTION 'Delivery is not in assigning phase (current: %)', v_status;
    END IF;

    -- Update delivery to in_transit
    UPDATE public.deliveries
    SET 
        status = 'in_transit',
        delivery_started_at = now(),
        progress = 0.5,
        updated_at = now()
    WHERE id = p_delivery_id;

    -- Update order to in_transit
    UPDATE public.orders
    SET 
        order_status = 'in_transit',
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
        'in_transit',
        'Package picked up by drone DRN-001. En route to customer drop-off location.',
        auth.uid(),
        now()
    );

    -- Notify customer: package picked up and en route
    IF v_order_user_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            id, user_id, title, message, notification_type, is_read, related_delivery_id, created_at
        ) VALUES (
            gen_random_uuid(),
            v_order_user_id,
            'Package Picked Up!',
            'Your order has been picked up by drone DRN-001 and is now flying to your dropoff location.',
            'order_in_transit',
            false,
            p_delivery_id,
            now()
        );
    END IF;

    -- Notify vendor: package picked up successfully
    IF v_order_vendor_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            id, user_id, title, message, notification_type, is_read, related_delivery_id, created_at
        ) VALUES (
            gen_random_uuid(),
            v_order_vendor_id,
            'Package Picked Up',
            'Drone DRN-001 has safely loaded the package and departed for customer delivery.',
            'package_picked_up',
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
        'progress', 0.5
    );
END;
$$;

-- 6. COMPLETE DELIVERY ORDER RPC
-- ============================================================
-- Atomically transitions delivery and order to 'delivered' and releases drone
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

    -- Check caller authorization
    SELECT role INTO v_user_role FROM public.users WHERE id = auth.uid();
    IF v_user_role != 'admin' AND auth.uid() != v_order_vendor_id AND auth.uid() != v_order_user_id THEN
        RAISE EXCEPTION 'Unauthorized: Caller cannot complete this delivery';
    END IF;

    IF v_status = 'delivered' THEN
        RETURN json_build_object(
            'success', true,
            'delivery_id', p_delivery_id,
            'status', 'delivered',
            'already_processed', true
        );
    END IF;

    -- Update delivery to delivered
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

    -- The trigger trg_delivery_drone_release handles releasing drone to 'available'
    -- and inserting customer & vendor delivered notifications.

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
        'status', 'delivered',
        'progress', 1.0
    );
END;
$$;

-- 7. GRANTS AND SECURITY SETTINGS
-- ============================================================
REVOKE ALL ON FUNCTION public.vendor_mark_order_ready(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.vendor_mark_order_ready(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.vendor_mark_order_ready(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, integer, double precision, text, double precision) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, integer, double precision, text, double precision) FROM anon;
GRANT EXECUTE ON FUNCTION public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, integer, double precision, text, double precision) TO authenticated;

REVOKE ALL ON FUNCTION public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, integer, double precision) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, integer, double precision) FROM anon;
GRANT EXECUTE ON FUNCTION public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, integer, double precision) TO authenticated;

REVOKE ALL ON FUNCTION public.confirm_package_pickup(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.confirm_package_pickup(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.confirm_package_pickup(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.complete_delivery_order(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.complete_delivery_order(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.complete_delivery_order(uuid) TO authenticated;
