-- ============================================================================
-- Migration 05: Realtime Publication, Strict Notification RLS & Drone Queueing
-- ============================================================================

-- 1. Add tables to supabase_realtime publication so Realtime PostgresChangeEvents fire
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'notifications' AND schemaname = 'public'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'orders' AND schemaname = 'public'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'deliveries' AND schemaname = 'public'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.deliveries;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'drone_telemetry' AND schemaname = 'public'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.drone_telemetry;
    END IF;
END $$;

-- 2. Strict Permissions & RLS on public.notifications
GRANT SELECT, UPDATE (is_read, read_at) ON public.notifications TO authenticated;

-- Ensure RLS policy permits authenticated users to update ONLY their own notifications
DROP POLICY IF EXISTS "notifications_update_read" ON public.notifications;
CREATE POLICY "notifications_update_read"
    ON public.notifications
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid() OR is_admin())
    WITH CHECK (user_id = auth.uid() OR is_admin());

-- Secure atomic RPC to mark a single notification read
CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_updated_count int;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    UPDATE public.notifications
    SET 
        is_read = true,
        read_at = now()
    WHERE id = p_notification_id
      AND user_id = auth.uid();

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    RETURN json_build_object(
        'success', true,
        'notification_id', p_notification_id,
        'updated', v_updated_count > 0
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_notification_read(uuid) TO authenticated;

-- Secure atomic RPC to mark all user notifications read
CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_updated_count int;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    UPDATE public.notifications
    SET 
        is_read = true,
        read_at = now()
    WHERE user_id = auth.uid()
      AND (is_read = false OR read_at IS NULL);

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    RETURN json_build_object(
        'success', true,
        'updated_count', v_updated_count
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated;


-- 3. Drone Queueing: Update vendor_mark_order_ready
CREATE OR REPLACE FUNCTION public.vendor_mark_order_ready(p_order_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
       AND v_order_status IS DISTINCT FROM 'ready_for_delivery'
    THEN
        RAISE EXCEPTION 'Invalid order status: Must be confirmed, preparing, or ready_for_delivery';
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

    -- Query weather status
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

    -- Query locations
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

    -- Query DRN-001
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

    IF v_total_weight_kg > coalesce(v_drone_max_payload, 0.5) THEN
        RAISE EXCEPTION 'Total cargo weight exceeds drone maximum payload limit';
    END IF;

    -- Self-healing: if drone is marked 'assigned' or 'busy' but has NO active deliveries, recover to available
    IF v_drone_status IN ('assigned', 'busy') AND NOT EXISTS (
        SELECT 1 FROM public.deliveries
        WHERE drone_id = v_drone_id
          AND status IN ('assigning', 'in_transit')
    ) THEN
        v_drone_status := 'available';
        UPDATE public.drones
        SET status = 'available', updated_at = now()
        WHERE id = v_drone_id;
    END IF;

    -- Check if drone is legitimately available right now
    IF v_drone_status = 'available' AND (v_drone_battery IS NULL OR v_drone_battery >= 15.0) THEN
        -- Verify no other delivery is currently assigning or in_transit with this drone
        IF NOT EXISTS (
            SELECT 1 FROM public.deliveries
            WHERE drone_id = v_drone_id
              AND status IN ('assigning', 'in_transit')
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
        -- Drone is available: assign and dispatch drone toward vendor
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

        -- Notify customer
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

        -- Notify vendor
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
            'drone_dispatched', true,
            'order_status', 'ready_for_delivery',
            'delivery_status', 'assigning',
            'cargo_weight_kg', v_total_weight_kg,
            'message', 'Order is ready for delivery. Drone DRN-001 dispatched for pickup.'
        );

    ELSE
        -- Drone is NOT available (busy with another delivery or charging)
        -- Order stays ready_for_delivery, delivery is created/queued as 'pending'
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
                NULL,
                'pending',
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

        INSERT INTO public.delivery_status_logs (
            delivery_id,
            status,
            message,
            changed_by,
            created_at
        )
        VALUES (
            v_delivery_id,
            'pending',
            'Order marked ready. Waiting in queue for next available drone.',
            auth.uid(),
            now()
        );

        -- Notify vendor that order is queued
        INSERT INTO public.notifications (
            id, user_id, title, message, notification_type, is_read, related_delivery_id, created_at
        ) VALUES (
            gen_random_uuid(),
            auth.uid(),
            'Order Queued for Drone',
            'Order marked ready and placed in queue. Drone will be dispatched automatically when available.',
            'order_queued',
            false,
            v_delivery_id,
            now()
        );

        RETURN json_build_object(
            'success', true,
            'order_id', p_order_id,
            'delivery_id', v_delivery_id,
            'drone_code', 'DRN-001',
            'drone_dispatched', false,
            'order_status', 'ready_for_delivery',
            'delivery_status', 'pending',
            'cargo_weight_kg', v_total_weight_kg,
            'message', 'Drone currently unavailable. This order is ready and waiting for the next available drone.'
        );
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.vendor_mark_order_ready(uuid) TO authenticated;


-- 4. Dispatch Waiting Delivery RPC (Explicit manual or automated dispatch)
CREATE OR REPLACE FUNCTION public.dispatch_waiting_delivery(p_delivery_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order_id uuid;
    v_order_status text;
    v_order_user_id uuid;
    v_order_vendor_id uuid;
    v_delivery_status text;
    v_drone_id uuid;
    v_drone_status text;
    v_drone_battery double precision;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT d.order_id, d.status, o.order_status, o.user_id, o.vendor_id
    INTO v_order_id, v_delivery_status, v_order_status, v_order_user_id, v_order_vendor_id
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

    IF v_drone_status != 'available' THEN
        RAISE EXCEPTION 'Drone DRN-001 is not currently available';
    END IF;

    -- Assign drone
    UPDATE public.deliveries
    SET 
        drone_id = v_drone_id,
        status = 'assigning',
        updated_at = now()
    WHERE id = p_delivery_id;

    UPDATE public.drones
    SET status = 'assigned', updated_at = now()
    WHERE id = v_drone_id;

    -- Notify customer and vendor
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
            p_delivery_id,
            now()
        );
    END IF;

    IF v_order_vendor_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            id, user_id, title, message, notification_type, is_read, related_delivery_id, created_at
        ) VALUES (
            gen_random_uuid(),
            v_order_vendor_id,
            'Drone Heading to Pickup',
            'Drone DRN-001 has been dispatched to pick up the queued order from your shop.',
            'drone_dispatched',
            false,
            p_delivery_id,
            now()
        );
    END IF;

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


-- 5. Auto-Dispatch on Delivery Completion Trigger
CREATE OR REPLACE FUNCTION public.handle_delivery_drone_release()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order_user_id uuid;
    v_order_vendor_id uuid;
    v_order_id uuid;
    v_next_delivery_id uuid;
    v_next_order_id uuid;
    v_next_order_user_id uuid;
    v_next_order_vendor_id uuid;
BEGIN
    v_order_id := NEW.order_id;

    SELECT user_id, vendor_id
    INTO v_order_user_id, v_order_vendor_id
    FROM public.orders
    WHERE id = v_order_id;

    -- A. When delivery completes or terminates
    IF NEW.status IN ('delivered', 'cancelled', 'rejected', 'failed') THEN
        -- Check if drone has other active deliveries
        IF NEW.drone_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM public.deliveries
            WHERE drone_id = NEW.drone_id
              AND id <> NEW.id
              AND status IN ('assigning', 'in_transit')
        ) THEN
            -- Check if there is a queued ready delivery waiting for a drone!
            SELECT d.id, d.order_id, o.user_id, o.vendor_id
            INTO v_next_delivery_id, v_next_order_id, v_next_order_user_id, v_next_order_vendor_id
            FROM public.deliveries d
            JOIN public.orders o ON d.order_id = o.id
            WHERE d.status = 'pending'
              AND o.order_status = 'ready_for_delivery'
            ORDER BY d.created_at ASC
            LIMIT 1
            FOR UPDATE OF d SKIP LOCKED;

            IF v_next_delivery_id IS NOT NULL THEN
                -- Auto-assign drone to the queued ready delivery
                UPDATE public.deliveries
                SET 
                    drone_id = NEW.drone_id,
                    status = 'assigning',
                    updated_at = now()
                WHERE id = v_next_delivery_id;

                UPDATE public.drones
                SET status = 'assigned', updated_at = now()
                WHERE id = NEW.drone_id;

                -- Log transition
                INSERT INTO public.delivery_status_logs (
                    delivery_id, status, message, changed_by, created_at
                ) VALUES (
                    v_next_delivery_id,
                    'assigning',
                    'Drone DRN-001 auto-assigned from queue and dispatched to vendor.',
                    v_next_order_vendor_id,
                    now()
                );

                -- Notify customer and vendor of queued order dispatch
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

                IF v_next_order_vendor_id IS NOT NULL THEN
                    INSERT INTO public.notifications (
                        id, user_id, title, message, notification_type, is_read, related_delivery_id, created_at
                    ) VALUES (
                        gen_random_uuid(),
                        v_next_order_vendor_id,
                        'Drone Heading to Pickup',
                        'Drone DRN-001 finished previous delivery and is now dispatched to pick up your order.',
                        'drone_dispatched',
                        false,
                        v_next_delivery_id,
                        now()
                    );
                END IF;
            ELSE
                -- No queued deliveries, release drone to available
                UPDATE public.drones
                SET status = 'available', updated_at = now()
                WHERE id = NEW.drone_id;
            END IF;
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

    -- B. When delivery transitions to in_transit
    ELSIF NEW.status = 'in_transit' AND (OLD.status IS NULL OR OLD.status <> 'in_transit') THEN
        UPDATE public.orders
        SET order_status = 'in_transit', updated_at = now()
        WHERE id = v_order_id AND order_status NOT IN ('in_transit', 'delivered');
    END IF;

    RETURN NEW;
END;
$$;
