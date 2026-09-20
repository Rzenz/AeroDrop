-- ============================================================================
-- AeroDrop Migration 10: Drone Return-to-Base, Sim Lease, Universal Cancel & Weather Operations
-- ============================================================================

BEGIN;

-- 1. SCHEMA EXTENSIONS & DRONE STATUS CONSTRAINT
-- ============================================================================

-- Ensure drones.status check constraint permits 'returning'
ALTER TABLE public.drones DROP CONSTRAINT IF EXISTS drones_status_check;
ALTER TABLE public.drones ADD CONSTRAINT drones_status_check
    CHECK (status IN ('available', 'assigned', 'busy', 'charging', 'maintenance', 'offline', 'returning'));

-- Add cancellation_reason to public.orders
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS cancellation_reason text;

-- Add returning_started_at and sim lease columns to public.drones
ALTER TABLE public.drones 
ADD COLUMN IF NOT EXISTS returning_started_at timestamptz,
ADD COLUMN IF NOT EXISTS sim_lease_holder uuid REFERENCES auth.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS sim_lease_until timestamptz;


-- 2. SIMULATION LEASE RPC
-- ============================================================================

CREATE OR REPLACE FUNCTION public.claim_drone_sim_lease(p_drone_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_updated_count int;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    UPDATE public.drones
    SET 
        sim_lease_holder = auth.uid(),
        sim_lease_until = now() + interval '10 seconds'
    WHERE id = p_drone_id
      AND (
          sim_lease_until IS NULL 
          OR sim_lease_until < now() 
          OR sim_lease_holder = auth.uid()
      );

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RETURN v_updated_count > 0;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_drone_sim_lease(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_drone_sim_lease(uuid) TO authenticated;


-- 3. UNIVERSAL CANCELLATION: BEFORE & AFTER TRIGGERS ON ORDERS
-- ============================================================================

-- NOTE on trigger ordering:
-- PostgreSQL executes BEFORE UPDATE triggers in alphabetical order by trigger name.
-- 'protect_order_fields_trigger' (starts with 'p') executes BEFORE 'trg_order_cancellation_before' (starts with 't').
-- When a user updates order_status to 'cancelled', protect_order_fields_trigger validates that payment_status
-- was not altered in the user's input payload and passes.
-- Then trg_order_cancellation_before executes and modifies NEW.payment_status := 'refunded', allowing
-- the automatic server-side refund without violating field protections.
CREATE OR REPLACE FUNCTION public.handle_order_cancellation_before()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF (NEW.order_status IN ('cancelled', 'rejected') 
        AND (OLD.order_status IS NULL OR OLD.order_status NOT IN ('cancelled', 'rejected')))
    THEN
        IF NEW.payment_method = 'gcash_simulated' AND NEW.payment_status = 'paid' THEN
            NEW.payment_status := 'refunded';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_cancellation_before ON public.orders;
CREATE TRIGGER trg_order_cancellation_before
BEFORE UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.handle_order_cancellation_before();


-- AFTER UPDATE trigger: restores product stock quantities exactly once per order
CREATE OR REPLACE FUNCTION public.handle_order_cancellation_after()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_item RECORD;
BEGIN
    IF (NEW.order_status IN ('cancelled', 'rejected') 
        AND (OLD.order_status IS NULL OR OLD.order_status NOT IN ('cancelled', 'rejected')))
    THEN
        FOR v_item IN (
            SELECT product_id, quantity 
            FROM public.order_items 
            WHERE order_id = NEW.id
        ) LOOP
            UPDATE public.products
            SET 
                stock_quantity = stock_quantity + v_item.quantity,
                updated_at = now()
            WHERE id = v_item.product_id;
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_cancellation_after ON public.orders;
CREATE TRIGGER trg_order_cancellation_after
AFTER UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.handle_order_cancellation_after();


-- 4. UNIFIED ORDER STATUS NOTIFICATIONS TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_order_status_notifications()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_short_id text;
    v_refund_text text := '';
    v_cust_msg text;
    v_vend_msg text;
BEGIN
    IF NEW.order_status IS DISTINCT FROM OLD.order_status THEN
        v_short_id := substring(NEW.id::text, 1, 8);

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
        ELSIF NEW.order_status IN ('cancelled', 'rejected') THEN
            IF NEW.payment_method = 'gcash_simulated' AND NEW.payment_status = 'refunded' THEN
                v_refund_text := ' Your payment will be refunded.';
            END IF;

            IF NEW.cancellation_reason = 'weather_grounded' THEN
                v_cust_msg := 'Weather is currently unsafe for drone delivery. Your order #' || v_short_id || ' was cancelled.' || v_refund_text;
                v_vend_msg := 'Weather is currently unsafe for drone delivery. Order #' || v_short_id || ' was cancelled.';
            ELSE
                v_cust_msg := 'Your order has been cancelled.' || v_refund_text;
                v_vend_msg := 'An order has been cancelled.';
            END IF;

            -- Customer Notification
            INSERT INTO public.notifications (
                id, user_id, title, message, notification_type, is_read, created_at
            ) VALUES (
                gen_random_uuid(),
                NEW.user_id,
                'Order Cancelled',
                v_cust_msg,
                'order_cancelled',
                false,
                now()
            );

            -- Vendor Notification
            IF NEW.vendor_id IS NOT NULL THEN
                INSERT INTO public.notifications (
                    id, user_id, title, message, notification_type, is_read, created_at
                ) VALUES (
                    gen_random_uuid(),
                    NEW.vendor_id,
                    'Order Cancelled',
                    v_vend_msg,
                    'order_cancelled',
                    false,
                    now()
                );
            END IF;
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


-- 5. CENTRALIZED QUEUE AUTO-DISPATCH (Internal Only)
-- ============================================================================

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

-- Internal function only: revoke from public, anon, and authenticated
REVOKE ALL ON FUNCTION public.dispatch_next_queued_delivery(uuid) FROM PUBLIC, anon, authenticated;


-- 6. COMPLETE DRONE RETURN RPC
-- ============================================================================

CREATE OR REPLACE FUNCTION public.complete_drone_return(p_drone_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_drone_status text;
    v_lease_holder uuid;
    v_is_admin boolean;
    v_dispatched boolean := false;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT status, sim_lease_holder
    INTO v_drone_status, v_lease_holder
    FROM public.drones
    WHERE id = p_drone_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Drone not found');
    END IF;

    v_is_admin := public.is_admin();

    -- Only succeed if status is 'returning' AND (caller is admin OR caller is the lease holder)
    IF v_drone_status != 'returning' OR (NOT v_is_admin AND v_lease_holder IS DISTINCT FROM auth.uid()) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Caller does not hold lease or drone is not in returning state',
            'status', v_drone_status
        );
    END IF;

    UPDATE public.drones
    SET 
        status = 'available',
        returning_started_at = NULL,
        sim_lease_holder = NULL,
        sim_lease_until = NULL,
        updated_at = now()
    WHERE id = p_drone_id;

    -- Try dispatching next waiting delivery
    v_dispatched := public.dispatch_next_queued_delivery(p_drone_id);

    RETURN json_build_object(
        'success', true,
        'status', CASE WHEN v_dispatched THEN 'assigned' ELSE 'available' END,
        'dispatched_next', v_dispatched
    );
END;
$$;

REVOKE ALL ON FUNCTION public.complete_drone_return(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_drone_return(uuid) TO authenticated;


-- 7. SAFETY-NET RECOVERY RPC (Callable by Admin Radar / Any Open Client / Server)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.recover_stale_returning_drone(p_drone_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_drone_status text;
    v_returning_started_at timestamptz;
    v_sim_lease_until timestamptz;
    v_last_telemetry_at timestamptz;
    v_reference_time timestamptz;
    v_dispatched boolean := false;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT status, returning_started_at, sim_lease_until
    INTO v_drone_status, v_returning_started_at, v_sim_lease_until
    FROM public.drones
    WHERE id = p_drone_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Drone not found');
    END IF;

    IF v_drone_status != 'returning' THEN
        RETURN json_build_object(
            'success', false, 
            'recovered', false, 
            'message', 'Drone is not in returning state', 
            'status', v_drone_status
        );
    END IF;

    -- Look up latest telemetry timestamp
    SELECT max(recorded_at) INTO v_last_telemetry_at
    FROM public.drone_telemetry
    WHERE drone_id = p_drone_id;

    v_reference_time := coalesce(v_last_telemetry_at, v_returning_started_at, now() - interval '61 seconds');

    -- Stale condition: > 60s without telemetry & no active unexpired simulation lease
    IF (now() - v_reference_time > interval '60 seconds') 
       AND (v_sim_lease_until IS NULL OR v_sim_lease_until < now())
    THEN
        UPDATE public.drones
        SET 
            status = 'available',
            returning_started_at = NULL,
            sim_lease_holder = NULL,
            sim_lease_until = NULL,
            updated_at = now()
        WHERE id = p_drone_id;

        v_dispatched := public.dispatch_next_queued_delivery(p_drone_id);

        RETURN json_build_object(
            'success', true,
            'recovered', true,
            'status', CASE WHEN v_dispatched THEN 'assigned' ELSE 'available' END,
            'dispatched_next', v_dispatched
        );
    END IF;

    RETURN json_build_object(
        'success', true,
        'recovered', false,
        'message', 'Drone return flight is active or recently updated',
        'status', 'returning'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.recover_stale_returning_drone(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recover_stale_returning_drone(uuid) TO authenticated;


-- 8. UPDATED DELIVERY DRONE RELEASE TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_delivery_drone_release()
RETURNS trigger
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

    -- When delivery completes or terminates
    IF NEW.status IN ('delivered', 'cancelled', 'rejected', 'failed') THEN
        -- If delivery had a drone assigned, transition drone to returning
        IF NEW.drone_id IS NOT NULL THEN
            UPDATE public.drones
            SET 
                status = 'returning',
                returning_started_at = now(),
                sim_lease_holder = NULL,
                sim_lease_until = NULL,
                updated_at = now()
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

    -- When delivery transitions to in_transit
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


-- 9. UPDATED TELEMETRY RPC (Permits 'returning_to_base' for completed/cancelled deliveries)
-- ============================================================================

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

    -- Allow returning_to_base even if delivery is delivered/cancelled
    IF p_event_type = 'returning_to_base' THEN
        IF v_delivery_status NOT IN ('assigning', 'in_transit', 'delivered', 'cancelled') THEN
            RAISE EXCEPTION 'Delivery state invalid for return telemetry (status: %)', v_delivery_status;
        END IF;
    ELSE
        IF v_delivery_status NOT IN ('assigning', 'in_transit') THEN
            RAISE EXCEPTION 'Delivery is not currently active (status: %)', v_delivery_status;
        END IF;
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

    -- Update delivery progress if delivery is active
    IF p_progress IS NOT NULL AND v_delivery_status IN ('assigning', 'in_transit') THEN
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


-- 10. UPDATED VENDOR_MARK_ORDER_READY & DISPATCH_WAITING_DELIVERY (With self-healing & weather checks)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.vendor_mark_order_ready(p_order_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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

    SELECT order_status, vendor_id, user_id, delivery_location_id
    INTO v_order_status, v_vendor_id, v_order_user_id, v_dropoff_location_id
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    IF v_vendor_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized: Order belongs to another vendor';
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

    IF v_total_weight_kg > coalesce(v_drone_max_payload, 0.5) THEN
        RAISE EXCEPTION 'Total cargo weight exceeds drone maximum payload limit';
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
    IF v_drone_status = 'available' AND (v_drone_battery IS NULL OR v_drone_battery >= 15.0) THEN
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
                estimated_delivery_seconds = 720,
                progress = 0,
                updated_at = now()
            WHERE id = v_delivery_id;
        ELSE
            INSERT INTO public.deliveries (
                order_id, drone_id, status, pickup_location_id, dropoff_location_id,
                delivery_started_at, delivery_completed_at, estimated_delivery_seconds, progress, created_at, updated_at
            ) VALUES (
                p_order_id, v_drone_id, 'assigning', v_pickup_location_id, v_dropoff_location_id,
                NULL, NULL, 720, 0, now(), now()
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
                updated_at = now()
            WHERE id = v_delivery_id;
        ELSE
            INSERT INTO public.deliveries (
                order_id, drone_id, status, pickup_location_id, dropoff_location_id,
                delivery_started_at, delivery_completed_at, estimated_delivery_seconds, progress, created_at, updated_at
            ) VALUES (
                p_order_id, NULL, 'pending', v_pickup_location_id, v_dropoff_location_id,
                NULL, NULL, 720, 0, now(), now()
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


CREATE OR REPLACE FUNCTION public.dispatch_waiting_delivery(p_delivery_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order_id uuid;
    v_order_status text;
    v_delivery_status text;
    v_drone_id uuid;
    v_drone_status text;
    v_drone_battery double precision;
    v_weather_status text;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Query weather status
    SELECT safety_status INTO v_weather_status
    FROM public.weather_safety
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_weather_status = 'grounded' THEN
        RAISE EXCEPTION 'Flight dispatch blocked: Weather is grounded';
    END IF;

    SELECT d.order_id, d.status, o.order_status
    INTO v_order_id, v_delivery_status, v_order_status
    FROM public.deliveries d
    JOIN public.orders o ON d.order_id = o.id
    WHERE d.id = p_delivery_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Delivery not found';
    END IF;

    IF v_delivery_status != 'pending' THEN
        RETURN json_build_object(
            'success', true,
            'already_dispatched', true,
            'delivery_status', v_delivery_status
        );
    END IF;

    -- Query DRN-001
    SELECT id, status, battery_level
    INTO v_drone_id, v_drone_status, v_drone_battery
    FROM public.drones
    WHERE drone_code = 'DRN-001'
    LIMIT 1
    FOR UPDATE;

    IF v_drone_status = 'returning' THEN
        PERFORM public.recover_stale_returning_drone(v_drone_id);
        SELECT status, battery_level INTO v_drone_status, v_drone_battery
        FROM public.drones WHERE id = v_drone_id;
    END IF;

    IF v_drone_status != 'available' THEN
        RAISE EXCEPTION 'Drone DRN-001 is not currently available';
    END IF;

    PERFORM public.dispatch_next_queued_delivery(v_drone_id);

    RETURN json_build_object(
        'success', true,
        'delivery_id', p_delivery_id,
        'order_id', v_order_id,
        'drone_code', 'DRN-001',
        'status', 'assigning'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.dispatch_waiting_delivery(uuid) TO authenticated;


-- 11. SERVER-SIDE WEATHER GROUNDING TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_weather_safety_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order RECORD;
    v_delivery RECORD;
    v_drone RECORD;
    v_vendor_user RECORD;
    v_active_user RECORD;
BEGIN
    IF NEW.safety_status IS DISTINCT FROM OLD.safety_status THEN
        -- A. GROUNDED: Cancel active orders & abort in-flight deliveries
        IF NEW.safety_status = 'grounded' THEN
            -- 1. Cancel active unfulfilled orders (triggers BEFORE/AFTER triggers for refund, stock restore & notification)
            UPDATE public.orders
            SET 
                order_status = 'cancelled',
                cancellation_reason = 'weather_grounded',
                updated_at = now()
            WHERE order_status IN (
                'pending',
                'confirmed',
                'preparing',
                'ready_for_delivery',
                'in_transit',
                'out_for_delivery'
            );

            -- 2. Cancel queued pending deliveries
            UPDATE public.deliveries
            SET 
                status = 'cancelled',
                updated_at = now()
            WHERE status = 'pending';

            -- 3. Abort active deliveries and instruct drones to return to base
            FOR v_delivery IN (
                SELECT id, drone_id
                FROM public.deliveries
                WHERE status IN ('assigning', 'in_transit')
            ) LOOP
                UPDATE public.deliveries
                SET 
                    status = 'cancelled',
                    delivery_completed_at = now(),
                    updated_at = now()
                WHERE id = v_delivery.id;

                IF v_delivery.drone_id IS NOT NULL THEN
                    UPDATE public.drones
                    SET 
                        status = 'returning',
                        returning_started_at = now(),
                        sim_lease_holder = NULL,
                        sim_lease_until = NULL,
                        updated_at = now()
                    WHERE id = v_delivery.drone_id;
                END IF;
            END LOOP;

        -- B. CAUTION: Notify active order participants about potential delay
        ELSIF NEW.safety_status = 'caution' THEN
            FOR v_active_user IN (
                SELECT DISTINCT user_id
                FROM public.orders
                WHERE order_status IN ('pending', 'confirmed', 'preparing', 'ready_for_delivery', 'in_transit', 'out_for_delivery')
                UNION
                SELECT DISTINCT vendor_id as user_id
                FROM public.orders
                WHERE order_status IN ('pending', 'confirmed', 'preparing', 'ready_for_delivery', 'in_transit', 'out_for_delivery')
                  AND vendor_id IS NOT NULL
            ) LOOP
                INSERT INTO public.notifications (
                    id, user_id, title, message, notification_type, is_read, created_at
                ) VALUES (
                    gen_random_uuid(),
                    v_active_user.user_id,
                    'Weather Advisory: Caution',
                    'Delivery may be delayed due to caution-level weather conditions.',
                    'weather_alert',
                    false,
                    now()
                );
            END LOOP;

        -- C. SAFE: Notify active approved vendors that dispatch is safe
        ELSIF NEW.safety_status = 'safe' THEN
            FOR v_vendor_user IN (
                SELECT id
                FROM public.users
                WHERE role = 'vendor' AND vendor_status = 'active' AND account_status = 'active'
            ) LOOP
                INSERT INTO public.notifications (
                    id, user_id, title, message, notification_type, is_read, created_at
                ) VALUES (
                    gen_random_uuid(),
                    v_vendor_user.id,
                    'Weather Update: Safe',
                    'Weather conditions are safe for campus drone dispatch.',
                    'weather_alert',
                    false,
                    now()
                );
            END LOOP;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_weather_safety_change ON public.weather_safety;
CREATE TRIGGER trg_weather_safety_change
AFTER UPDATE OF safety_status ON public.weather_safety
FOR EACH ROW
EXECUTE FUNCTION public.handle_weather_safety_change();


-- 12. PLACE_ORDER RPC (Exact copy of 03_drone_notes_notifications.sql with grounded weather check)
-- ============================================================================

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

REVOKE ALL ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text) TO authenticated;


-- 13. ADMIN-ONLY ENFORCEMENT ON SET_SIMULATED_WEATHER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.set_simulated_weather(p_safety_status text)
RETURNS public.weather_safety
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_status text;
    v_condition text;
    v_temperature numeric(6, 2);
    v_wind_speed numeric(8, 2);
    v_message text;
    v_weather public.weather_safety%ROWTYPE;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Only administrators may change weather safety.';
    END IF;

    v_status := lower(trim(coalesce(p_safety_status, '')));

    CASE v_status
        WHEN 'safe' THEN
            v_condition := 'Clear Skies';
            v_temperature := 30.0;
            v_wind_speed := 10.0;
            v_message := 'Weather conditions are safe for campus drone dispatch.';
        WHEN 'caution' THEN
            v_condition := 'High Winds';
            v_temperature := 32.0;
            v_wind_speed := 28.0;
            v_message := 'Delivery may be delayed due to caution-level weather conditions.';
        WHEN 'grounded' THEN
            v_condition := 'Heavy Rain';
            v_temperature := 22.0;
            v_wind_speed := 40.0;
            v_message := 'Weather is currently unsafe for drone delivery. Please try again later.';
        ELSE
            RAISE EXCEPTION 'Invalid weather status. Use safe, caution, or grounded.';
    END CASE;

    SELECT *
    INTO v_weather
    FROM public.weather_safety
    ORDER BY updated_at DESC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
        UPDATE public.weather_safety
        SET
            condition = v_condition,
            temperature = v_temperature,
            wind_speed = v_wind_speed,
            safety_status = v_status,
            message = v_message,
            updated_at = now()
        WHERE id = v_weather.id
        RETURNING *
        INTO v_weather;
    ELSE
        INSERT INTO public.weather_safety (
            condition,
            temperature,
            wind_speed,
            safety_status,
            message,
            updated_at
        ) VALUES (
            v_condition,
            v_temperature,
            v_wind_speed,
            v_status,
            v_message,
            now()
        )
        RETURNING *
        INTO v_weather;
    END IF;

    RETURN v_weather;
END;
$$;

REVOKE ALL ON FUNCTION public.set_simulated_weather(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_simulated_weather(text) TO authenticated;

COMMIT;
