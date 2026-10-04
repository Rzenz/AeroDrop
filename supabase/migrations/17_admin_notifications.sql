-- ============================================================================
-- AeroDrop Migration 17: Database-Level Admin In-App Notifications
-- ============================================================================
-- 1. Helper function: notify_all_admins()
--    Dispatches an in-app notification to all active users with role = 'admin'.
--    Strictly in-app into public.notifications; NEVER sends email.
-- 2. New Vendor Application Notification:
--    Triggered on public.users whenever vendor_status transitions to 'pending'.
-- 3. Delivery Completed / Failed Notifications:
--    Integrated into public.handle_delivery_drone_release() on public.deliveries.
-- 4. Order Cancelled & Weather Grounding / Payment Expiration Notifications:
--    Integrated into public.handle_order_status_notifications() on public.orders.
-- 5. Payment Failed Notifications:
--    Integrated into public.handle_order_status_notifications() on public.orders
--    when payment_status transitions to 'failed'.
-- 6. Weather Status Notifications (Caution & Grounded):
--    Integrated into public.handle_weather_safety_change() on public.weather_safety.
-- 7. Drone Low Battery & Stale Returning Notifications:
--    - Low battery (< 15%) trigger on public.drones.
--    - Stale returning recovery notification integrated into recover_stale_returning_drone().
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. HELPER: NOTIFY ALL ADMINS
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.notify_all_admins(
    p_title text,
    p_message text,
    p_notification_type text,
    p_related_delivery_id uuid DEFAULT NULL,
    p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin RECORD;
BEGIN
    FOR v_admin IN (
        SELECT id
        FROM public.users
        WHERE role = 'admin' AND account_status = 'active'
    ) LOOP
        INSERT INTO public.notifications (
            id,
            user_id,
            title,
            message,
            notification_type,
            is_read,
            related_delivery_id,
            metadata,
            created_at
        ) VALUES (
            gen_random_uuid(),
            v_admin.id,
            p_title,
            p_message,
            p_notification_type,
            false,
            p_related_delivery_id,
            p_metadata,
            now()
        );
    END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_all_admins(text, text, text, uuid, jsonb) FROM PUBLIC, anon, authenticated;


-- ----------------------------------------------------------------------------
-- 2. NEW VENDOR APPLICATION NOTIFICATION (AFTER INSERT OR UPDATE ON USERS)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_vendor_application_admin_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_applicant_name text;
BEGIN
    IF NEW.vendor_status = 'pending' AND (TG_OP = 'INSERT' OR OLD.vendor_status IS DISTINCT FROM 'pending') THEN
        v_applicant_name := coalesce(NEW.business_name, NEW.full_name, 'A vendor applicant');
        
        PERFORM public.notify_all_admins(
            'New Vendor Application',
            v_applicant_name || ' has submitted an application awaiting approval.',
            'vendor_application',
            NULL,
            jsonb_build_object(
                'applicant_id', NEW.id,
                'business_name', NEW.business_name,
                'email', NEW.email
            )
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_admin_vendor_application ON public.users;
CREATE TRIGGER trg_notify_admin_vendor_application
AFTER INSERT OR UPDATE OF vendor_status ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_vendor_application_admin_notification();


-- ----------------------------------------------------------------------------
-- 3. DELIVERY COMPLETED & FAILED NOTIFICATIONS (HOOK INTO handle_delivery_drone_release)
-- ----------------------------------------------------------------------------

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
    v_short_order_id text;
    v_drone_code text := 'Drone';
BEGIN
    v_order_id := NEW.order_id;
    v_short_order_id := substring(v_order_id::text, 1, 8);

    SELECT user_id, vendor_id
    INTO v_order_user_id, v_order_vendor_id
    FROM public.orders
    WHERE id = v_order_id;

    IF NEW.drone_id IS NOT NULL THEN
        SELECT coalesce(drone_code, 'Drone') INTO v_drone_code
        FROM public.drones
        WHERE id = NEW.drone_id;
    END IF;

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

        IF NEW.status = 'delivered' AND (OLD.status IS DISTINCT FROM 'delivered') THEN
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

            -- Admin in-app notification: Delivery Completed
            PERFORM public.notify_all_admins(
                'Delivery Completed',
                v_drone_code || ' successfully delivered order #' || v_short_order_id || '.',
                'delivery_completed',
                NEW.id,
                jsonb_build_object(
                    'delivery_id', NEW.id,
                    'order_id', v_order_id,
                    'drone_id', NEW.drone_id,
                    'status', NEW.status
                )
            );

        ELSIF NEW.status = 'failed' AND (OLD.status IS DISTINCT FROM 'failed') THEN
            -- Admin in-app notification: Delivery Failed
            PERFORM public.notify_all_admins(
                'Delivery Failed',
                'Delivery for order #' || v_short_order_id || ' failed during transit.',
                'delivery_failed',
                NEW.id,
                jsonb_build_object(
                    'delivery_id', NEW.id,
                    'order_id', v_order_id,
                    'drone_id', NEW.drone_id,
                    'status', NEW.status
                )
            );
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


-- ----------------------------------------------------------------------------
-- 4. ORDER CANCELLED & PAYMENT EXPIRED/FAILED (HOOK INTO handle_order_status_notifications)
-- ----------------------------------------------------------------------------

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
    v_short_id := substring(NEW.id::text, 1, 8);

    -- 1. Order Status Transitions
    IF NEW.order_status IS DISTINCT FROM OLD.order_status THEN
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
            IF NEW.payment_method IN ('gcash_simulated', 'card_simulated', 'xendit_online') AND NEW.payment_status = 'refunded' THEN
                v_refund_text := ' Your payment will be refunded.';
            END IF;

            IF NEW.cancellation_reason = 'weather_grounded' THEN
                v_cust_msg := 'Weather is currently unsafe for drone delivery. Your order #' || v_short_id || ' was cancelled.' || v_refund_text;
                v_vend_msg := 'Weather is currently unsafe for drone delivery. Order #' || v_short_id || ' was cancelled.';
            ELSIF NEW.cancellation_reason = 'customer' THEN
                v_cust_msg := 'Your order #' || v_short_id || ' has been cancelled.' || v_refund_text;
                v_vend_msg := 'Order #' || v_short_id || ' was cancelled by the customer.';
            ELSIF NEW.cancellation_reason = 'payment_expired' THEN
                v_cust_msg := 'Your order #' || v_short_id || ' has expired due to incomplete payment. No charges were made.';
                v_vend_msg := 'Order #' || v_short_id || ' expired due to incomplete payment.';
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

            -- Admin Notification for Order Cancellation (suppressed for weather_grounded to avoid noise; consolidated in single weather alert)
            IF NEW.cancellation_reason = 'weather_grounded' THEN
                -- Suppressed for admins: consolidated count is sent in the single weather alert
                NULL;
            ELSIF NEW.cancellation_reason = 'payment_expired' THEN
                PERFORM public.notify_all_admins(
                    'Payment Expired',
                    'Order #' || v_short_id || ' expired due to unpaid invoice timeout.',
                    'payment_expired',
                    NULL,
                    jsonb_build_object(
                        'order_id', NEW.id,
                        'reason', NEW.cancellation_reason,
                        'order_status', NEW.order_status
                    )
                );
            ELSE
                PERFORM public.notify_all_admins(
                    'Order Cancelled',
                    'Order #' || v_short_id || ' was cancelled (' || coalesce(NEW.cancellation_reason, 'unspecified reason') || ').',
                    'order_cancelled',
                    NULL,
                    jsonb_build_object(
                        'order_id', NEW.id,
                        'reason', NEW.cancellation_reason,
                        'order_status', NEW.order_status
                    )
                );
            END IF;
        END IF;
    END IF;

    -- 2. Payment Status Transition to Failed
    IF NEW.payment_status = 'failed' AND (OLD.payment_status IS DISTINCT FROM 'failed') THEN
        PERFORM public.notify_all_admins(
            'Payment Failed',
            'Payment for order #' || v_short_id || ' failed.',
            'payment_failed',
            NULL,
            jsonb_build_object(
                'order_id', NEW.id,
                'payment_method', NEW.payment_method,
                'payment_provider', NEW.payment_provider
            )
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_status_notifications ON public.orders;
CREATE TRIGGER trg_order_status_notifications
AFTER UPDATE OF order_status, payment_status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.handle_order_status_notifications();


-- ----------------------------------------------------------------------------
-- 5. WEATHER SAFETY: CAUTION OR GROUNDED NOTIFICATIONS (HOOK INTO handle_weather_safety_change)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_weather_safety_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_delivery RECORD;
    v_vendor_user RECORD;
    v_active_user RECORD;
    v_cancelled_order_count integer := 0;
    v_grounded_msg text;
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
            GET DIAGNOSTICS v_cancelled_order_count = ROW_COUNT;

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

            -- Admin in-app notification: Grounded Weather Alert with consolidated order count
            IF v_cancelled_order_count > 0 THEN
                v_grounded_msg := 'Weather grounded: ' || v_cancelled_order_count || ' active ' || 
                    CASE WHEN v_cancelled_order_count = 1 THEN 'order was' ELSE 'orders were' END || 
                    ' cancelled and in-flight drones are returning to base.';
            ELSE
                v_grounded_msg := 'Weather grounded: all flight operations suspended and in-flight drones are returning to base.';
            END IF;

            PERFORM public.notify_all_admins(
                'Weather Alert: Grounded',
                v_grounded_msg,
                'weather_alert',
                NULL,
                jsonb_build_object(
                    'safety_status', NEW.safety_status,
                    'condition', NEW.condition,
                    'wind_speed', NEW.wind_speed,
                    'temperature', NEW.temperature,
                    'cancelled_order_count', v_cancelled_order_count
                )
            );

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

            -- Admin in-app notification: Caution Weather Advisory
            PERFORM public.notify_all_admins(
                'Weather Advisory: Caution',
                'Weather safety status changed to Caution. Flight operations subject to weather surcharge and delays.',
                'weather_alert',
                NULL,
                jsonb_build_object(
                    'safety_status', NEW.safety_status,
                    'condition', NEW.condition,
                    'wind_speed', NEW.wind_speed,
                    'temperature', NEW.temperature
                )
            );

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


-- ----------------------------------------------------------------------------
-- 6. DRONE LOW BATTERY (< 15%) & STUCK RETURNING RECOVERY NOTIFICATIONS
-- ----------------------------------------------------------------------------

-- A. Drone Low Battery Trigger on public.drones
CREATE OR REPLACE FUNCTION public.handle_drone_battery_admin_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.battery_level < 15.0 AND (OLD.battery_level >= 15.0 OR OLD.battery_level IS NULL) THEN
        PERFORM public.notify_all_admins(
            'Drone Low Battery Warning',
            'Drone ' || coalesce(NEW.drone_code, 'DRN') || ' battery dropped to ' || round(NEW.battery_level::numeric, 1)::text || '%, below the 15% dispatch minimum.',
            'drone_low_battery',
            NULL,
            jsonb_build_object(
                'drone_id', NEW.id,
                'drone_code', NEW.drone_code,
                'battery_level', NEW.battery_level,
                'status', NEW.status
            )
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_admin_drone_battery ON public.drones;
CREATE TRIGGER trg_notify_admin_drone_battery
AFTER UPDATE OF battery_level ON public.drones
FOR EACH ROW
EXECUTE FUNCTION public.handle_drone_battery_admin_notification();


-- B. Stuck Returning Drone Recovery Notification (Hook into recover_stale_returning_drone)
CREATE OR REPLACE FUNCTION public.recover_stale_returning_drone(p_drone_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_drone_code text;
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

    SELECT drone_code, status, returning_started_at, sim_lease_until
    INTO v_drone_code, v_drone_status, v_returning_started_at, v_sim_lease_until
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

        -- Admin in-app notification: Stuck drone recovered
        PERFORM public.notify_all_admins(
            'Drone Stuck in Return Recovered',
            'Drone ' || coalesce(v_drone_code, 'DRN-001') || ' was detected stuck in returning state without telemetry and was automatically recovered.',
            'drone_stuck_returning',
            NULL,
            jsonb_build_object(
                'drone_id', p_drone_id,
                'drone_code', v_drone_code,
                'dispatched_next', v_dispatched
            )
        );

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

COMMIT;
