-- ============================================================
-- AERODROP REMOTE DATABASE BASELINE MIGRATION
-- File: supabase/migrations/01_remote_baseline.sql
--
-- This baseline migration represents the exact simplified AeroDrop
-- architecture currently active in the remote Supabase database:
--
-- 1. Consolidated users architecture:
--    - auth.users handles authentication
--    - public.users handles all user, vendor, and admin profiles
--    - public.users.role IN ('user', 'vendor', 'admin')
--    - public.users.vendor_status IN ('pending', 'active', 'suspended', 'rejected')
--    - public.users.account_status IN ('active', 'suspended', 'deleted')
-- 2. Core domain tables:
--    - campus_locations, drones, telemetry_event_types
--    - users, products, orders, order_items, deliveries
--    - drone_telemetry, notifications, weather_safety, no_fly_zones, delivery_status_logs
-- 3. Removed architectures are NOT present:
--    - user_roles, user_credentials, user_profiles, vendors, vendor_statuses
-- 4. Complete RLS policies, triggers, constraints, indexes, and existing functions.
--
-- Safe for execution on both fresh environments and existing remote database.
-- ============================================================

-- ============================================================
-- 1. EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 2. CORE TABLES
-- ============================================================

-- Campus locations
CREATE TABLE IF NOT EXISTS public.campus_locations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    location_code text UNIQUE NOT NULL,
    latitude double precision,
    longitude double precision,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Drones
CREATE TABLE IF NOT EXISTS public.drones (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    drone_code text UNIQUE NOT NULL,
    drone_name text,
    model text,
    max_payload_kg numeric NOT NULL DEFAULT 0.5,
    battery_level numeric NOT NULL DEFAULT 100,
    status text NOT NULL DEFAULT 'available',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Telemetry event types
CREATE TABLE IF NOT EXISTS public.telemetry_event_types (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text UNIQUE NOT NULL,
    description text,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Consolidated Users table
CREATE TABLE IF NOT EXISTS public.users (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email text UNIQUE NOT NULL,
    full_name text NOT NULL,
    phone_number text,
    role text NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'vendor', 'admin')),
    account_status text NOT NULL DEFAULT 'active' CHECK (account_status IN ('active', 'suspended', 'deleted')),
    vendor_status text CHECK (vendor_status IS NULL OR vendor_status IN ('pending', 'active', 'suspended', 'rejected')),
    business_name text,
    business_category text,
    business_description text,
    business_logo_url text,
    avatar_url text,
    campus_location_id uuid REFERENCES public.campus_locations(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Products (vendor_id references public.users.id)
CREATE TABLE IF NOT EXISTS public.products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    price numeric NOT NULL,
    stock_quantity integer NOT NULL DEFAULT 0,
    category text,
    weight_grams integer NOT NULL DEFAULT 0,
    image_url text,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Orders
CREATE TABLE IF NOT EXISTS public.orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    vendor_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    delivery_location_id uuid REFERENCES public.campus_locations(id) ON DELETE SET NULL,
    order_status text NOT NULL DEFAULT 'pending',
    payment_status text NOT NULL DEFAULT 'pending',
    payment_method text,
    payment_reference text,
    subtotal numeric NOT NULL DEFAULT 0,
    delivery_fee numeric NOT NULL DEFAULT 0,
    total_amount numeric NOT NULL DEFAULT 0,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Order Items
CREATE TABLE IF NOT EXISTS public.order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
    product_name text NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric NOT NULL,
    subtotal numeric NOT NULL,
    weight_grams integer NOT NULL DEFAULT 0
);

-- Deliveries
CREATE TABLE IF NOT EXISTS public.deliveries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL UNIQUE REFERENCES public.orders(id) ON DELETE CASCADE,
    drone_id uuid REFERENCES public.drones(id) ON DELETE SET NULL,
    pickup_location_id uuid REFERENCES public.campus_locations(id) ON DELETE SET NULL,
    dropoff_location_id uuid REFERENCES public.campus_locations(id) ON DELETE SET NULL,
    status text NOT NULL DEFAULT 'pending',
    progress numeric NOT NULL DEFAULT 0,
    estimated_delivery_seconds integer,
    delivery_started_at timestamptz,
    delivery_completed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Drone Telemetry
CREATE TABLE IF NOT EXISTS public.drone_telemetry (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_id uuid NOT NULL REFERENCES public.deliveries(id) ON DELETE CASCADE,
    drone_id uuid REFERENCES public.drones(id) ON DELETE SET NULL,
    latitude double precision,
    longitude double precision,
    altitude double precision,
    speed double precision,
    battery_level double precision,
    signal_strength double precision,
    event_type text,
    recorded_at timestamptz NOT NULL DEFAULT now()
);

-- Notifications
CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title text NOT NULL,
    message text NOT NULL,
    notification_type text,
    is_read boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Weather Safety
CREATE TABLE IF NOT EXISTS public.weather_safety (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    safety_status text NOT NULL DEFAULT 'safe',
    condition text,
    message text,
    temperature numeric,
    wind_speed numeric,
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- No-Fly Zones
CREATE TABLE IF NOT EXISTS public.no_fly_zones (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    latitude double precision,
    longitude double precision,
    radius_meters double precision,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Delivery Status Logs
CREATE TABLE IF NOT EXISTS public.delivery_status_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_id uuid NOT NULL REFERENCES public.deliveries(id) ON DELETE CASCADE,
    status text NOT NULL,
    message text,
    changed_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 3. INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS products_vendor_id_idx ON public.products(vendor_id);
CREATE INDEX IF NOT EXISTS products_active_idx ON public.products(is_active);
CREATE INDEX IF NOT EXISTS orders_user_id_idx ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS orders_vendor_id_idx ON public.orders(vendor_id);
CREATE INDEX IF NOT EXISTS orders_status_idx ON public.orders(order_status);
CREATE INDEX IF NOT EXISTS deliveries_status_idx ON public.deliveries(status);
CREATE INDEX IF NOT EXISTS telemetry_delivery_id_idx ON public.drone_telemetry(delivery_id);
CREATE INDEX IF NOT EXISTS telemetry_recorded_at_idx ON public.drone_telemetry(recorded_at);
CREATE INDEX IF NOT EXISTS notifications_user_id_idx ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS notifications_unread_idx ON public.notifications(user_id, is_read);

-- ============================================================
-- 4. FUNCTIONS
-- ============================================================

-- Function: set_updated_at()
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- Function: is_admin()
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = auth.uid()
          AND u.role = 'admin'
          AND u.account_status = 'active'
    );
$$;

-- Function: can_access_order(uuid)
CREATE OR REPLACE FUNCTION public.can_access_order(p_order_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
    SELECT
        public.is_admin()
        OR EXISTS (
            SELECT 1
            FROM public.orders o
            WHERE o.id = p_order_id
              AND (
                  o.user_id = auth.uid()
                  OR o.vendor_id = auth.uid()
              )
        );
$$;

-- Function: can_access_delivery(uuid)
CREATE OR REPLACE FUNCTION public.can_access_delivery(p_delivery_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
    SELECT
        public.is_admin()
        OR EXISTS (
            SELECT 1
            FROM public.deliveries d
            JOIN public.orders o ON o.id = d.order_id
            WHERE d.id = p_delivery_id
              AND (
                  o.user_id = auth.uid()
                  OR o.vendor_id = auth.uid()
              )
        );
$$;

-- Function: is_active_vendor(uuid)
CREATE OR REPLACE FUNCTION public.is_active_vendor(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = p_user_id
          AND u.role = 'vendor'
          AND u.vendor_status = 'active'
          AND u.account_status = 'active'
    );
$$;

-- Function: set_simulated_weather(text)
CREATE OR REPLACE FUNCTION public.set_simulated_weather(p_safety_status text)
RETURNS public.weather_safety
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
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

    v_status := lower(trim(coalesce(p_safety_status, '')));

    CASE v_status
        WHEN 'safe' THEN
            v_condition := 'Clear';
            v_temperature := 30;
            v_wind_speed := 8;
            v_message := 'Weather is safe for drone delivery.';
        WHEN 'caution' THEN
            v_condition := 'High Winds';
            v_temperature := 28;
            v_wind_speed := 25;
            v_message := 'Drone delivery may be delayed due to strong winds.';
        WHEN 'grounded' THEN
            v_condition := 'Heavy Rain';
            v_temperature := 22;
            v_wind_speed := 40;
            v_message := 'Drone delivery is grounded due to unsafe weather.';
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
        )
        VALUES (
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

-- Function: vendor_mark_order_ready(uuid)
CREATE OR REPLACE FUNCTION public.vendor_mark_order_ready(p_order_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_order_status text;
    v_vendor_id uuid;
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
        delivery_location_id
    INTO
        v_order_status,
        v_vendor_id,
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
        max_payload_kg
    INTO
        v_drone_id,
        v_drone_status,
        v_drone_max_payload
    FROM public.drones
    WHERE drone_code = 'DRN-001'
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Drone DRN-001 not found';
    END IF;

    IF v_drone_status IS DISTINCT FROM 'available' THEN
        RAISE EXCEPTION 'Drone DRN-001 is not currently available';
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
            status = 'in_transit',
            pickup_location_id = v_pickup_location_id,
            dropoff_location_id = v_dropoff_location_id,
            delivery_started_at = now(),
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
            'in_transit',
            v_pickup_location_id,
            v_dropoff_location_id,
            now(),
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
        'in_transit',
        'Drone DRN-001 dispatched to pick up the order from the vendor.',
        auth.uid(),
        now()
    );

    RETURN json_build_object(
        'delivery_id', v_delivery_id,
        'drone_id', v_drone_id,
        'order_status', 'ready_for_delivery',
        'delivery_status', 'in_transit'
    );
END;
$$;

-- Function: handle_new_auth_user()
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_requested_role text;
    v_role text := 'user';
    v_vendor_status text := NULL;
    v_campus_string text;
    v_campus_uuid uuid;
    v_full_name text;
    v_phone_number text;
    v_business_name text;
    v_business_category text;
    v_business_description text;
BEGIN
    v_requested_role := lower(
        trim(
            coalesce(
                NEW.raw_user_meta_data->>'requested_role',
                NEW.raw_user_meta_data->>'role',
                'user'
            )
        )
    );

    IF v_requested_role = 'vendor' THEN
        v_role := 'user';
        v_vendor_status := 'pending';
    ELSE
        v_role := 'user';
        v_vendor_status := NULL;
    END IF;

    v_full_name := coalesce(
        nullif(trim(NEW.raw_user_meta_data->>'full_name'), ''),
        nullif(trim(NEW.raw_user_meta_data->>'name'), ''),
        split_part(coalesce(NEW.email, 'user'), '@', 1)
    );

    v_phone_number := nullif(trim(NEW.raw_user_meta_data->>'phone_number'), '');

    IF v_requested_role = 'vendor' THEN
        v_business_name := nullif(trim(NEW.raw_user_meta_data->>'business_name'), '');
        v_business_category := nullif(trim(NEW.raw_user_meta_data->>'business_category'), '');
        v_business_description := nullif(trim(NEW.raw_user_meta_data->>'business_description'), '');
    ELSE
        v_business_name := NULL;
        v_business_category := NULL;
        v_business_description := NULL;
    END IF;

    v_campus_string := nullif(trim(NEW.raw_user_meta_data->>'campus_location_id'), '');
    IF v_campus_string IS NOT NULL
       AND v_campus_string ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    THEN
        v_campus_uuid := v_campus_string::uuid;
        IF NOT EXISTS (
            SELECT 1 FROM public.campus_locations WHERE id = v_campus_uuid
        ) THEN
            v_campus_uuid := NULL;
        END IF;
    ELSE
        v_campus_uuid := NULL;
    END IF;

    IF v_requested_role <> 'vendor' THEN
        v_campus_uuid := NULL;
    END IF;

    INSERT INTO public.users (
        id,
        full_name,
        email,
        phone_number,
        role,
        account_status,
        vendor_status,
        business_name,
        business_category,
        business_description,
        campus_location_id,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        v_full_name,
        lower(NEW.email),
        v_phone_number,
        v_role,
        'active',
        v_vendor_status,
        v_business_name,
        v_business_category,
        v_business_description,
        v_campus_uuid,
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE
    SET
        full_name = EXCLUDED.full_name,
        email = EXCLUDED.email,
        phone_number = EXCLUDED.phone_number,
        business_name = EXCLUDED.business_name,
        business_category = EXCLUDED.business_category,
        business_description = EXCLUDED.business_description,
        campus_location_id = EXCLUDED.campus_location_id,
        updated_at = now();

    RETURN NEW;
END;
$$;

-- Function: sync_auth_email_to_users()
CREATE OR REPLACE FUNCTION public.sync_auth_email_to_users()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
    IF NEW.email IS NOT NULL AND NEW.email IS DISTINCT FROM OLD.email THEN
        UPDATE public.users
        SET
            email = lower(NEW.email),
            updated_at = now()
        WHERE id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;

-- Function: protect_user_security_fields()
CREATE OR REPLACE FUNCTION public.protect_user_security_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
    IF current_user NOT IN ('postgres', 'service_role') AND NOT public.is_admin() THEN
        IF NEW.id IS DISTINCT FROM OLD.id
           OR NEW.email IS DISTINCT FROM OLD.email
           OR NEW.role IS DISTINCT FROM OLD.role
           OR NEW.account_status IS DISTINCT FROM OLD.account_status
           OR NEW.vendor_status IS DISTINCT FROM OLD.vendor_status THEN
            RAISE EXCEPTION 'You cannot modify protected account fields.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

-- Function: protect_order_fields()
CREATE OR REPLACE FUNCTION public.protect_order_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
    IF current_user NOT IN ('postgres', 'service_role') AND NOT public.is_admin() THEN
        IF NEW.id IS DISTINCT FROM OLD.id
           OR NEW.user_id IS DISTINCT FROM OLD.user_id
           OR NEW.vendor_id IS DISTINCT FROM OLD.vendor_id
           OR NEW.delivery_location_id IS DISTINCT FROM OLD.delivery_location_id
           OR NEW.subtotal IS DISTINCT FROM OLD.subtotal
           OR NEW.delivery_fee IS DISTINCT FROM OLD.delivery_fee
           OR NEW.total_amount IS DISTINCT FROM OLD.total_amount
           OR NEW.payment_method IS DISTINCT FROM OLD.payment_method
           OR NEW.payment_status IS DISTINCT FROM OLD.payment_status
           OR NEW.payment_reference IS DISTINCT FROM OLD.payment_reference
           OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
            RAISE EXCEPTION 'You cannot modify protected order fields.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

-- ============================================================
-- 5. TRIGGERS
-- ============================================================

-- updated_at triggers
DROP TRIGGER IF EXISTS users_set_updated_at ON public.users;
CREATE TRIGGER users_set_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS products_set_updated_at ON public.products;
CREATE TRIGGER products_set_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS orders_set_updated_at ON public.orders;
CREATE TRIGGER orders_set_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS drones_set_updated_at ON public.drones;
CREATE TRIGGER drones_set_updated_at BEFORE UPDATE ON public.drones FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS deliveries_set_updated_at ON public.deliveries;
CREATE TRIGGER deliveries_set_updated_at BEFORE UPDATE ON public.deliveries FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS no_fly_zones_set_updated_at ON public.no_fly_zones;
CREATE TRIGGER no_fly_zones_set_updated_at BEFORE UPDATE ON public.no_fly_zones FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS weather_set_updated_at ON public.weather_safety;
CREATE TRIGGER weather_set_updated_at BEFORE UPDATE ON public.weather_safety FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Protection triggers
DROP TRIGGER IF EXISTS protect_user_security_fields_trigger ON public.users;
CREATE TRIGGER protect_user_security_fields_trigger BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.protect_user_security_fields();

DROP TRIGGER IF EXISTS protect_order_fields_trigger ON public.orders;
CREATE TRIGGER protect_order_fields_trigger BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.protect_order_fields();

-- Auth sync triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

DROP TRIGGER IF EXISTS on_auth_email_updated ON auth.users;
CREATE TRIGGER on_auth_email_updated AFTER UPDATE OF email ON auth.users FOR EACH ROW EXECUTE FUNCTION public.sync_auth_email_to_users();

-- ============================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================

ALTER TABLE public.campus_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.telemetry_event_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drone_telemetry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weather_safety ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.no_fly_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_status_logs ENABLE ROW LEVEL SECURITY;

-- campus_locations policies
DROP POLICY IF EXISTS campus_locations_select ON public.campus_locations;
CREATE POLICY campus_locations_select ON public.campus_locations FOR SELECT TO anon, authenticated USING (true);
GRANT SELECT ON public.campus_locations TO anon;

DROP POLICY IF EXISTS campus_locations_admin_insert ON public.campus_locations;
CREATE POLICY campus_locations_admin_insert ON public.campus_locations FOR INSERT TO authenticated WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS campus_locations_admin_update ON public.campus_locations;
CREATE POLICY campus_locations_admin_update ON public.campus_locations FOR UPDATE TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS campus_locations_admin_delete ON public.campus_locations;
CREATE POLICY campus_locations_admin_delete ON public.campus_locations FOR DELETE TO authenticated USING (public.is_admin());

-- drones policies
DROP POLICY IF EXISTS drones_select ON public.drones;
CREATE POLICY drones_select ON public.drones FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS drones_admin_insert ON public.drones;
CREATE POLICY drones_admin_insert ON public.drones FOR INSERT TO authenticated WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS drones_admin_update ON public.drones;
CREATE POLICY drones_admin_update ON public.drones FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS drones_admin_delete ON public.drones;
CREATE POLICY drones_admin_delete ON public.drones FOR DELETE TO authenticated USING (public.is_admin());

-- users policies
DROP POLICY IF EXISTS users_select ON public.users;
CREATE POLICY users_select ON public.users FOR SELECT TO authenticated
USING (
    (id = auth.uid())
    OR public.is_admin()
    OR ((role = 'vendor') AND (vendor_status = 'active') AND (account_status = 'active'))
);

DROP POLICY IF EXISTS users_update ON public.users;
CREATE POLICY users_update ON public.users FOR UPDATE TO authenticated
USING ((id = auth.uid()) OR public.is_admin())
WITH CHECK ((id = auth.uid()) OR public.is_admin());

-- products policies
DROP POLICY IF EXISTS products_select ON public.products;
CREATE POLICY products_select ON public.products FOR SELECT TO authenticated
USING (
    public.is_admin()
    OR (vendor_id = auth.uid())
    OR ((is_active = true) AND public.is_active_vendor(vendor_id))
);

DROP POLICY IF EXISTS products_insert ON public.products;
CREATE POLICY products_insert ON public.products FOR INSERT TO authenticated
WITH CHECK (
    public.is_admin()
    OR ((vendor_id = auth.uid()) AND public.is_active_vendor(auth.uid()))
);

DROP POLICY IF EXISTS products_update ON public.products;
CREATE POLICY products_update ON public.products FOR UPDATE TO authenticated
USING (
    public.is_admin()
    OR ((vendor_id = auth.uid()) AND public.is_active_vendor(auth.uid()))
)
WITH CHECK (
    public.is_admin()
    OR ((vendor_id = auth.uid()) AND public.is_active_vendor(auth.uid()))
);

DROP POLICY IF EXISTS products_delete ON public.products;
CREATE POLICY products_delete ON public.products FOR DELETE TO authenticated
USING (
    public.is_admin()
    OR ((vendor_id = auth.uid()) AND public.is_active_vendor(auth.uid()))
);

-- orders policies
DROP POLICY IF EXISTS orders_select ON public.orders;
CREATE POLICY orders_select ON public.orders FOR SELECT TO authenticated
USING ((user_id = auth.uid()) OR (vendor_id = auth.uid()) OR public.is_admin());

DROP POLICY IF EXISTS orders_insert ON public.orders;
CREATE POLICY orders_insert ON public.orders FOR INSERT TO authenticated
WITH CHECK ((user_id = auth.uid()) AND public.is_active_vendor(vendor_id));

DROP POLICY IF EXISTS orders_owner_cancel ON public.orders;
CREATE POLICY orders_owner_cancel ON public.orders FOR UPDATE TO authenticated
USING ((user_id = auth.uid()) AND (order_status = 'pending'))
WITH CHECK ((user_id = auth.uid()) AND (order_status = 'cancelled'));

DROP POLICY IF EXISTS orders_vendor_update ON public.orders;
CREATE POLICY orders_vendor_update ON public.orders FOR UPDATE TO authenticated
USING ((vendor_id = auth.uid()) AND public.is_active_vendor(auth.uid()))
WITH CHECK (vendor_id = auth.uid());

DROP POLICY IF EXISTS orders_admin_update ON public.orders;
CREATE POLICY orders_admin_update ON public.orders FOR UPDATE TO authenticated
USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS orders_admin_delete ON public.orders;
CREATE POLICY orders_admin_delete ON public.orders FOR DELETE TO authenticated
USING (public.is_admin());

-- order_items policies
DROP POLICY IF EXISTS order_items_select ON public.order_items;
CREATE POLICY order_items_select ON public.order_items FOR SELECT TO authenticated
USING (public.can_access_order(order_id));

DROP POLICY IF EXISTS order_items_insert ON public.order_items;
CREATE POLICY order_items_insert ON public.order_items FOR INSERT TO authenticated
WITH CHECK (
    public.is_admin()
    OR (EXISTS (
        SELECT 1 FROM public.orders o
        WHERE o.id = order_items.order_id
          AND o.user_id = auth.uid()
          AND o.order_status = 'pending'
    ))
);

DROP POLICY IF EXISTS order_items_update ON public.order_items;
CREATE POLICY order_items_update ON public.order_items FOR UPDATE TO authenticated
USING (
    public.is_admin()
    OR (EXISTS (
        SELECT 1 FROM public.orders o
        WHERE o.id = order_items.order_id
          AND o.user_id = auth.uid()
          AND o.order_status = 'pending'
    ))
)
WITH CHECK (
    public.is_admin()
    OR (EXISTS (
        SELECT 1 FROM public.orders o
        WHERE o.id = order_items.order_id
          AND o.user_id = auth.uid()
          AND o.order_status = 'pending'
    ))
);

DROP POLICY IF EXISTS order_items_delete ON public.order_items;
CREATE POLICY order_items_delete ON public.order_items FOR DELETE TO authenticated
USING (
    public.is_admin()
    OR (EXISTS (
        SELECT 1 FROM public.orders o
        WHERE o.id = order_items.order_id
          AND o.user_id = auth.uid()
          AND o.order_status = 'pending'
    ))
);

-- deliveries policies
DROP POLICY IF EXISTS deliveries_select ON public.deliveries;
CREATE POLICY deliveries_select ON public.deliveries FOR SELECT TO authenticated
USING (public.can_access_order(order_id));

DROP POLICY IF EXISTS deliveries_admin_insert ON public.deliveries;
CREATE POLICY deliveries_admin_insert ON public.deliveries FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS deliveries_admin_update ON public.deliveries;
CREATE POLICY deliveries_admin_update ON public.deliveries FOR UPDATE TO authenticated
USING (public.is_admin());

DROP POLICY IF EXISTS deliveries_admin_delete ON public.deliveries;
CREATE POLICY deliveries_admin_delete ON public.deliveries FOR DELETE TO authenticated
USING (public.is_admin());

-- delivery_status_logs policies
DROP POLICY IF EXISTS delivery_status_logs_select ON public.delivery_status_logs;
CREATE POLICY delivery_status_logs_select ON public.delivery_status_logs FOR SELECT TO authenticated
USING (public.can_access_delivery(delivery_id));

DROP POLICY IF EXISTS delivery_status_logs_admin_insert ON public.delivery_status_logs;
CREATE POLICY delivery_status_logs_admin_insert ON public.delivery_status_logs FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS delivery_status_logs_admin_delete ON public.delivery_status_logs;
CREATE POLICY delivery_status_logs_admin_delete ON public.delivery_status_logs FOR DELETE TO authenticated
USING (public.is_admin());

-- drone_telemetry policies
DROP POLICY IF EXISTS drone_telemetry_select ON public.drone_telemetry;
CREATE POLICY drone_telemetry_select ON public.drone_telemetry FOR SELECT TO authenticated
USING (public.can_access_delivery(delivery_id));

DROP POLICY IF EXISTS drone_telemetry_insert ON public.drone_telemetry;
CREATE POLICY drone_telemetry_insert ON public.drone_telemetry FOR INSERT TO authenticated
WITH CHECK (true);

DROP POLICY IF EXISTS drone_telemetry_admin_delete ON public.drone_telemetry;
CREATE POLICY drone_telemetry_admin_delete ON public.drone_telemetry FOR DELETE TO authenticated
USING (public.is_admin());

-- notifications policies
DROP POLICY IF EXISTS notifications_select ON public.notifications;
CREATE POLICY notifications_select ON public.notifications FOR SELECT TO authenticated
USING ((user_id = auth.uid()) OR public.is_admin());

DROP POLICY IF EXISTS notifications_update_read ON public.notifications;
CREATE POLICY notifications_update_read ON public.notifications FOR UPDATE TO authenticated
USING ((user_id = auth.uid()) OR public.is_admin())
WITH CHECK ((user_id = auth.uid()) OR public.is_admin());

DROP POLICY IF EXISTS notifications_admin_insert ON public.notifications;
CREATE POLICY notifications_admin_insert ON public.notifications FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS notifications_delete ON public.notifications;
CREATE POLICY notifications_delete ON public.notifications FOR DELETE TO authenticated
USING ((user_id = auth.uid()) OR public.is_admin());

-- weather_safety policies
DROP POLICY IF EXISTS weather_safety_select ON public.weather_safety;
CREATE POLICY weather_safety_select ON public.weather_safety FOR SELECT TO authenticated
USING (true);

DROP POLICY IF EXISTS weather_safety_admin_insert ON public.weather_safety;
CREATE POLICY weather_safety_admin_insert ON public.weather_safety FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS weather_safety_admin_update ON public.weather_safety;
CREATE POLICY weather_safety_admin_update ON public.weather_safety FOR UPDATE TO authenticated
USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS weather_safety_admin_delete ON public.weather_safety;
CREATE POLICY weather_safety_admin_delete ON public.weather_safety FOR DELETE TO authenticated
USING (public.is_admin());

-- no_fly_zones policies
DROP POLICY IF EXISTS no_fly_zones_select ON public.no_fly_zones;
CREATE POLICY no_fly_zones_select ON public.no_fly_zones FOR SELECT TO authenticated
USING (true);

DROP POLICY IF EXISTS no_fly_zones_admin_insert ON public.no_fly_zones;
CREATE POLICY no_fly_zones_admin_insert ON public.no_fly_zones FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS no_fly_zones_admin_update ON public.no_fly_zones;
CREATE POLICY no_fly_zones_admin_update ON public.no_fly_zones FOR UPDATE TO authenticated
USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS no_fly_zones_admin_delete ON public.no_fly_zones;
CREATE POLICY no_fly_zones_admin_delete ON public.no_fly_zones FOR DELETE TO authenticated
USING (public.is_admin());

-- ============================================================
-- 7. SEED LOOKUPS & DEFAULT VALUES
-- ============================================================

-- Seed 5 campus locations
INSERT INTO public.campus_locations (id, name, location_code, latitude, longitude) VALUES
  ('10000000-0000-0000-0000-000000000001', 'Old Building', 'LOC-OB', 10.3156, 123.9016),
  ('10000000-0000-0000-0000-000000000002', 'Annex 1 Building', 'LOC-A1', 10.3159, 123.9019),
  ('10000000-0000-0000-0000-000000000003', 'Annex 2 Building', 'LOC-A2', 10.3154, 123.9021),
  ('10000000-0000-0000-0000-000000000004', 'Basic Education Building', 'LOC-BE', 10.3148, 123.9014),
  ('10000000-0000-0000-0000-000000000005', 'Maritime Building', 'LOC-MB', 10.3163, 123.9025)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  location_code = EXCLUDED.location_code,
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude;

-- Seed Prototype Drone DRN-001
INSERT INTO public.drones (id, drone_code, drone_name, model, max_payload_kg, battery_level, status) VALUES
  ('80000000-0000-0000-0000-000000000001', 'DRN-001', 'AeroCarrier Alpha', 'Prototype 001', 0.5, 100.0, 'available')
ON CONFLICT (drone_code) DO NOTHING;

-- Seed Telemetry Event Types
INSERT INTO public.telemetry_event_types (name, description) VALUES
  ('position_update', 'Drone location update.'),
  ('battery_update', 'Drone battery update.'),
  ('altitude_update', 'Drone altitude update.'),
  ('speed_update', 'Drone speed update.'),
  ('signal_update', 'Drone signal or connectivity update.'),
  ('system_warning', 'Drone system warning.'),
  ('obstacle_detected', 'Obstacle was detected during flight.')
ON CONFLICT (name) DO NOTHING;

-- Seed initial weather safety row if empty
INSERT INTO public.weather_safety (id, safety_status, condition, message, temperature, wind_speed) VALUES
  ('10000000-0000-0000-0000-000000000001', 'safe', 'Clear', 'Weather is safe for drone delivery.', 30.0, 8.0)
ON CONFLICT (id) DO NOTHING;
