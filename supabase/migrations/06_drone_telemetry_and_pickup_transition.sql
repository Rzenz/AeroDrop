-- Migration 06: Fix drone telemetry heading column, orders_status_check for in_transit, and pickup transition

-- 1. Ensure heading column exists on drone_telemetry
ALTER TABLE public.drone_telemetry ADD COLUMN IF NOT EXISTS heading double precision DEFAULT 0.0;

-- 2. Update orders_status_check constraint to include 'in_transit'
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_status_check CHECK (
    order_status = ANY (ARRAY[
        'pending'::text,
        'confirmed'::text,
        'preparing'::text,
        'ready_for_delivery'::text,
        'in_transit'::text,
        'out_for_delivery'::text,
        'delivered'::text,
        'cancelled'::text,
        'rejected'::text
    ])
);

-- 3. Ensure deliveries_status_check constraint includes all states
ALTER TABLE public.deliveries DROP CONSTRAINT IF EXISTS deliveries_status_check;
ALTER TABLE public.deliveries ADD CONSTRAINT deliveries_status_check CHECK (
    status = ANY (ARRAY[
        'pending'::text,
        'assigning'::text,
        'in_transit'::text,
        'delivered'::text,
        'cancelled'::text,
        'rejected'::text,
        'grounded'::text
    ])
);

-- 4. Secure and robust confirm_package_pickup RPC
CREATE OR REPLACE FUNCTION public.confirm_package_pickup(p_delivery_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

    -- Check caller authorization: admin, vendor of order, or customer of order
    SELECT role INTO v_user_role FROM public.users WHERE id = auth.uid();
    IF v_user_role != 'admin' AND auth.uid() != v_order_vendor_id AND auth.uid() != v_order_user_id THEN
        RAISE EXCEPTION 'Unauthorized: Caller cannot confirm pickup for this delivery';
    END IF;

    -- Idempotent check: if already in_transit or delivered, return success
    IF v_status != 'assigning' THEN
        IF v_status IN ('in_transit', 'delivered') THEN
            RETURN json_build_object(
                'success', true,
                'delivery_id', p_delivery_id,
                'order_id', v_order_id,
                'status', v_status,
                'already_processed', true
            );
        END IF;
        RAISE EXCEPTION 'Delivery is not in assigning phase (current status: %)', v_status;
    END IF;

    -- Update delivery to in_transit
    UPDATE public.deliveries
    SET 
        status = 'in_transit',
        delivery_started_at = now(),
        progress = 0.0,
        updated_at = now()
    WHERE id = p_delivery_id;

    -- Update order to in_transit
    UPDATE public.orders
    SET 
        order_status = 'in_transit',
        updated_at = now()
    WHERE id = v_order_id;

    -- Ensure drone remains assigned
    IF v_drone_id IS NOT NULL THEN
        UPDATE public.drones
        SET 
            status = 'assigned',
            updated_at = now()
        WHERE id = v_drone_id;
    END IF;

    -- Log transition
    INSERT INTO public.delivery_status_logs (
        id,
        delivery_id,
        status,
        message,
        changed_by,
        created_at
    ) VALUES (
        gen_random_uuid(),
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
        'progress', 0.0
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_package_pickup(uuid) TO authenticated;

-- 5. Updated record_simulated_telemetry RPC supporting heading and progress
CREATE OR REPLACE FUNCTION public.record_simulated_telemetry(
    p_delivery_id uuid,
    p_latitude double precision,
    p_longitude double precision,
    p_altitude double precision,
    p_speed double precision,
    p_battery_level double precision,
    p_signal_strength double precision,
    p_heading double precision DEFAULT 0.0,
    p_event_type text DEFAULT 'in_flight',
    p_progress double precision DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_drone_id uuid;
    v_user_role text;
    v_order_user_id uuid;
    v_order_vendor_id uuid;
    v_delivery_status text;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

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

    IF v_delivery_status NOT IN ('assigning', 'in_transit') THEN
        RAISE EXCEPTION 'Delivery is not currently active (status: %)', v_delivery_status;
    END IF;

    SELECT role INTO v_user_role FROM public.users WHERE id = auth.uid();
    IF v_user_role != 'admin' AND auth.uid() != v_order_vendor_id AND auth.uid() != v_order_user_id THEN
        RAISE EXCEPTION 'Unauthorized: Caller does not have rights for this order telemetry';
    END IF;

    IF p_latitude IS NULL OR p_longitude IS NULL THEN
        RAISE EXCEPTION 'Latitude and longitude are required';
    END IF;

    INSERT INTO public.drone_telemetry (
        id,
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
        gen_random_uuid(),
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

    UPDATE public.drones
    SET 
        battery_level = p_battery_level,
        updated_at = now()
    WHERE id = v_drone_id;

    IF p_progress IS NOT NULL THEN
        UPDATE public.deliveries
        SET
            progress = p_progress,
            updated_at = now()
        WHERE id = p_delivery_id;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, double precision, double precision, text, double precision) TO authenticated;
