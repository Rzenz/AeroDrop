-- 09_secure_telemetry_rpc.sql
-- Creates the secure record_simulated_telemetry function compatible with the simplified schema.

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
SET search_path = public
AS $$
DECLARE
    v_drone_id uuid;
    v_user_role text;
    v_order_user_id uuid;
    v_order_vendor_id uuid;
    v_delivery_status text;
BEGIN
    -- 1. Check if the user is authenticated
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- 2. Verify delivery exists and get drone_id, delivery status name, and order info
    SELECT 
        d.drone_id,
        ds.name,
        o.user_id,
        o.vendor_id
    INTO 
        v_drone_id,
        v_delivery_status,
        v_order_user_id,
        v_order_vendor_id
    FROM public.deliveries d
    JOIN public.orders o ON d.order_id = o.id
    JOIN public.delivery_statuses ds ON d.delivery_status_id = ds.id
    WHERE d.id = p_delivery_id;

    IF v_drone_id IS NULL THEN
        RAISE EXCEPTION 'Delivery does not exist or has no drone assigned';
    END IF;

    -- 3. Verify status is in_transit
    IF v_delivery_status != 'in_transit' THEN
        RAISE EXCEPTION 'Delivery is not in transit';
    END IF;

    -- 4. Resolve user role from flat users table
    SELECT role INTO v_user_role
    FROM public.users
    WHERE id = auth.uid();

    -- 5. Enforce role-based access control
    IF v_user_role = 'admin' THEN
        -- Admins are always authorized to simulate telemetry
    ELSIF v_user_role = 'vendor' THEN
        -- Vendors can only simulate/submit telemetry if they own the order's vendor store
        IF auth.uid() != v_order_vendor_id THEN
            RAISE EXCEPTION 'Unauthorized: Vendor does not own this order';
        END IF;
    ELSE
        -- Students/Faculty/other users must own the related order
        IF auth.uid() != v_order_user_id THEN
            RAISE EXCEPTION 'Unauthorized: User does not own this order';
        END IF;
    END IF;

    -- 6. Validate telemetry parameters
    IF p_latitude IS NULL OR p_longitude IS NULL THEN
        RAISE EXCEPTION 'Latitude and longitude are required';
    END IF;

    IF p_battery_level < 0 OR p_battery_level > 100 THEN
        RAISE EXCEPTION 'Battery level must be between 0 and 100';
    END IF;

    IF p_signal_strength < 0 OR p_signal_strength > 100 THEN
        RAISE EXCEPTION 'Signal strength must be between 0 and 100';
    END IF;

    -- 7. Insert telemetry row
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
        p_heading,
        now()
    );

    -- 8. Securely update drone battery level in public.drones (bypassing client RLS)
    UPDATE public.drones
    SET battery_level = p_battery_level
    WHERE id = v_drone_id;
END;
$$;

-- Grant execution to authenticated users
REVOKE EXECUTE ON FUNCTION public.record_simulated_telemetry FROM public, anon;
GRANT EXECUTE ON FUNCTION public.record_simulated_telemetry TO authenticated;
