-- ============================================================
-- AeroDrop Migration 08: Fix Telemetry RPC, Support Columns & Authoritative Progress
-- ============================================================

-- 1. Drop all conflicting overloaded signatures of record_simulated_telemetry
DROP FUNCTION IF EXISTS public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, integer, double precision);
DROP FUNCTION IF EXISTS public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, integer, double precision, text, double precision);
DROP FUNCTION IF EXISTS public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, double precision, double precision, text, double precision);

-- 2. Recreate single authoritative record_simulated_telemetry RPC
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
SET search_path = public, pg_temp
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

REVOKE ALL ON FUNCTION public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, double precision, double precision, text, double precision) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_simulated_telemetry(uuid, double precision, double precision, double precision, double precision, double precision, double precision, double precision, text, double precision) TO authenticated;

-- 3. Update complete_delivery_order to enforce progress = 1.0 on all paths
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

-- 4. Enforce progress = 1.0 on all historical delivered deliveries
UPDATE public.deliveries
SET progress = 1.0
WHERE status = 'delivered' AND (progress IS NULL OR progress < 1.0);

-- 5. Add order_id and delivery_id columns to support_reports
ALTER TABLE public.support_reports
  ADD COLUMN IF NOT EXISTS order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS delivery_id uuid REFERENCES public.deliveries(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_support_reports_order_id ON public.support_reports(order_id);
CREATE INDEX IF NOT EXISTS idx_support_reports_delivery_id ON public.support_reports(delivery_id);

GRANT SELECT, INSERT ON public.support_reports TO authenticated;
