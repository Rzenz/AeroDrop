-- ============================================================
-- AERODROP USER/VENDOR ACCOUNT WORKFLOW MIGRATION
-- File: supabase/migrations/03_user_vendor_account_workflow.sql
--
-- Changes:
-- 1. Consolidates roles into user, vendor, admin
-- 2. Fixes Auth registration trigger
-- 3. Adds business_logo_url
-- 4. Synchronizes Auth email changes
-- 5. Creates initial grounded weather configuration
-- 6. Creates secure vendor ready-for-pickup RPC
-- 7. Creates avatar and vendor-logo Storage buckets/policies
--
-- This does not drop application tables or delete Auth users.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. CONSOLIDATE ACCOUNT ROLES
-- ============================================================

-- Remove existing CHECK constraints related to the role column.
DO $$
DECLARE
    constraint_record RECORD;
BEGIN
    FOR constraint_record IN
        SELECT
            conname
        FROM pg_constraint
        WHERE conrelid = 'public.users'::regclass
          AND contype = 'c'
          AND (
              pg_get_constraintdef(oid) ILIKE '%role%'
              OR conname ILIKE '%role%'
          )
    LOOP
        EXECUTE format(
            'ALTER TABLE public.users DROP CONSTRAINT IF EXISTS %I',
            constraint_record.conname
        );
    END LOOP;
END;
$$;

-- Convert old account roles into the new user role.
UPDATE public.users
SET
    role = 'user',
    updated_at = now()
WHERE role IN ('student', 'faculty_staff');

-- Create the new three-role constraint.
ALTER TABLE public.users
ADD CONSTRAINT users_role_check
CHECK (
    role IN ('user', 'vendor', 'admin')
);

-- Set the default role for new profiles.
ALTER TABLE public.users
ALTER COLUMN role SET DEFAULT 'user';

-- ============================================================
-- 2. RECREATE VENDOR STATUS CONSTRAINT
-- ============================================================

DO $$
DECLARE
    constraint_record RECORD;
BEGIN
    FOR constraint_record IN
        SELECT
            conname
        FROM pg_constraint
        WHERE conrelid = 'public.users'::regclass
          AND contype = 'c'
          AND (
              pg_get_constraintdef(oid) ILIKE '%vendor_status%'
              OR conname ILIKE '%vendor_status%'
          )
    LOOP
        EXECUTE format(
            'ALTER TABLE public.users DROP CONSTRAINT IF EXISTS %I',
            constraint_record.conname
        );
    END LOOP;
END;
$$;

ALTER TABLE public.users
ADD CONSTRAINT users_vendor_status_check
CHECK (
    vendor_status IS NULL
    OR vendor_status IN (
        'pending',
        'active',
        'suspended',
        'rejected'
    )
);

-- ============================================================
-- 3. ADD VENDOR BUSINESS LOGO COLUMN
-- ============================================================

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS business_logo_url text;

-- ============================================================
-- 4. FIX AUTH USER REGISTRATION TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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
    -- Never trust raw role metadata directly.
    v_requested_role := lower(
        trim(
            coalesce(
                NEW.raw_user_meta_data->>'requested_role',
                NEW.raw_user_meta_data->>'role',
                'user'
            )
        )
    );

    -- Public vendor registration creates a pending user account.
    IF v_requested_role = 'vendor' THEN
        v_role := 'user';
        v_vendor_status := 'pending';
    ELSE
        -- Covers:
        -- user, student, faculty_staff, admin, blank, or unknown values.
        v_role := 'user';
        v_vendor_status := NULL;
    END IF;

    -- Safely resolve profile fields.
    v_full_name := coalesce(
        nullif(
            trim(NEW.raw_user_meta_data->>'full_name'),
            ''
        ),
        nullif(
            trim(NEW.raw_user_meta_data->>'name'),
            ''
        ),
        split_part(coalesce(NEW.email, 'user'), '@', 1)
    );

    v_phone_number := nullif(
        trim(NEW.raw_user_meta_data->>'phone_number'),
        ''
    );

    -- Business information is accepted only for vendor applicants.
    IF v_requested_role = 'vendor' THEN
        v_business_name := nullif(
            trim(NEW.raw_user_meta_data->>'business_name'),
            ''
        );

        v_business_category := nullif(
            trim(NEW.raw_user_meta_data->>'business_category'),
            ''
        );

        v_business_description := nullif(
            trim(NEW.raw_user_meta_data->>'business_description'),
            ''
        );
    ELSE
        v_business_name := NULL;
        v_business_category := NULL;
        v_business_description := NULL;
    END IF;

    -- Safely parse the campus-location UUID.
    v_campus_string := nullif(
        trim(NEW.raw_user_meta_data->>'campus_location_id'),
        ''
    );

    IF v_campus_string IS NOT NULL
       AND v_campus_string ~
           '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    THEN
        v_campus_uuid := v_campus_string::uuid;

        -- Avoid a foreign-key error when an invalid location UUID
        -- was submitted.
        IF NOT EXISTS (
            SELECT 1
            FROM public.campus_locations
            WHERE id = v_campus_uuid
        ) THEN
            v_campus_uuid := NULL;
        END IF;
    ELSE
        v_campus_uuid := NULL;
    END IF;

    -- Normal user registration should not save a business location.
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

-- Recreate the Auth registration trigger.
DROP TRIGGER IF EXISTS on_auth_user_created
ON auth.users;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_auth_user();

-- Restrict direct function execution.
REVOKE ALL
ON FUNCTION public.handle_new_auth_user()
FROM PUBLIC;

-- ============================================================
-- 5. SYNCHRONIZE AUTH EMAIL WITH PUBLIC USERS
-- ============================================================

CREATE OR REPLACE FUNCTION public.sync_auth_email_to_users()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.email IS NOT NULL
       AND NEW.email IS DISTINCT FROM OLD.email
    THEN
        UPDATE public.users
        SET
            email = lower(NEW.email),
            updated_at = now()
        WHERE id = NEW.id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_email_updated
ON auth.users;

CREATE TRIGGER on_auth_email_updated
AFTER UPDATE OF email ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.sync_auth_email_to_users();

REVOKE ALL
ON FUNCTION public.sync_auth_email_to_users()
FROM PUBLIC;

-- ============================================================
-- 6. INITIAL WEATHER CONFIGURATION
-- ============================================================

-- Unknown weather must remain grounded until configured by admin.
INSERT INTO public.weather_safety (
    id,
    condition,
    temperature,
    wind_speed,
    safety_status,
    message,
    updated_at
)
SELECT
    '10000000-0000-0000-0000-000000000001'::uuid,
    'Not configured',
    0,
    0,
    'grounded',
    'Weather conditions must be configured by an administrator.',
    now()
WHERE NOT EXISTS (
    SELECT 1
    FROM public.weather_safety
);

-- ============================================================
-- 7. SECURE VENDOR READY-FOR-PICKUP RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.vendor_mark_order_ready(
    p_order_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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
    -- Require an authenticated caller.
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Load the caller's public profile.
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
        RAISE EXCEPTION
            'Authenticated account profile was not found';
    END IF;

    -- Only approved and active vendors may dispatch orders.
    IF v_user_role IS DISTINCT FROM 'vendor'
       OR v_vendor_status IS DISTINCT FROM 'active'
       OR v_account_status IS DISTINCT FROM 'active'
    THEN
        RAISE EXCEPTION
            'Unauthorized: Caller is not an active approved vendor';
    END IF;

    -- Lock and load the order to prevent duplicate dispatch requests.
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
        RAISE EXCEPTION
            'Unauthorized: Order belongs to another vendor';
    END IF;

    IF v_order_status IS DISTINCT FROM 'confirmed'
       AND v_order_status IS DISTINCT FROM 'preparing'
    THEN
        RAISE EXCEPTION
            'Invalid order status: Must be confirmed or preparing';
    END IF;

    -- Count items and calculate total cargo weight.
    SELECT
        count(*),
        coalesce(
            sum(
                coalesce(weight_grams, 0)
                * coalesce(quantity, 0)
            ),
            0
        )
    INTO
        v_item_count,
        v_total_weight_grams
    FROM public.order_items
    WHERE order_id = p_order_id;

    IF v_item_count <= 0 THEN
        RAISE EXCEPTION 'Order contains no items';
    END IF;

    v_total_weight_kg :=
        v_total_weight_grams::double precision / 1000.0;

    IF v_total_weight_kg <= 0 THEN
        RAISE EXCEPTION
            'Total cargo weight must be greater than zero';
    END IF;

    -- Lock and load the prototype drone.
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
        RAISE EXCEPTION
            'Drone DRN-001 is not currently available';
    END IF;

    IF v_drone_max_payload IS NULL
       OR v_drone_max_payload <= 0
    THEN
        RAISE EXCEPTION
            'Drone payload capacity is not configured';
    END IF;

    IF v_total_weight_kg > v_drone_max_payload THEN
        RAISE EXCEPTION
            'Total cargo weight exceeds drone maximum payload limit';
    END IF;

    -- Load the latest weather-safety status.
    SELECT
        safety_status
    INTO
        v_weather_status
    FROM public.weather_safety
    ORDER BY updated_at DESC
    LIMIT 1;

    IF NOT FOUND OR v_weather_status IS NULL THEN
        RAISE EXCEPTION
            'No weather safety record configured';
    END IF;

    IF v_weather_status IS DISTINCT FROM 'safe'
       AND v_weather_status IS DISTINCT FROM 'caution'
    THEN
        RAISE EXCEPTION
            'Flight dispatch blocked: Weather is grounded';
    END IF;

    -- Vendor's campus location becomes the pickup location.
    SELECT
        campus_location_id
    INTO
        v_pickup_location_id
    FROM public.users
    WHERE id = auth.uid();

    IF v_pickup_location_id IS NULL THEN
        RAISE EXCEPTION
            'Vendor pickup location not configured';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.campus_locations
        WHERE id = v_pickup_location_id
    ) THEN
        RAISE EXCEPTION
            'Vendor pickup location does not exist';
    END IF;

    IF v_dropoff_location_id IS NULL THEN
        RAISE EXCEPTION
            'Order dropoff location not configured';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.campus_locations
        WHERE id = v_dropoff_location_id
    ) THEN
        RAISE EXCEPTION
            'Order dropoff location does not exist';
    END IF;

    -- Lock the delivery record for this order when it exists.
    SELECT
        id,
        status
    INTO
        v_delivery_id,
        v_delivery_status
    FROM public.deliveries
    WHERE order_id = p_order_id
    FOR UPDATE;

    IF FOUND THEN
        -- An already-active delivery must not be dispatched twice.
        IF v_delivery_status IN (
            'pending',
            'assigning',
            'in_transit'
        ) THEN
            RAISE EXCEPTION
                'An active delivery already exists for this order';
        END IF;

        -- A completed delivery must never restart.
        IF v_delivery_status = 'delivered' THEN
            RAISE EXCEPTION
                'This order has already been delivered';
        END IF;

        -- Only inactive/failed delivery records may be reused.
        IF v_delivery_status NOT IN (
            'cancelled',
            'rejected',
            'grounded'
        ) THEN
            RAISE EXCEPTION
                'The existing delivery cannot be restarted';
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
        RETURNING id
        INTO v_delivery_id;
    END IF;

    -- Keep the order at ready_for_delivery while the drone
    -- travels to the vendor.
    UPDATE public.orders
    SET
        order_status = 'ready_for_delivery',
        updated_at = now()
    WHERE id = p_order_id;

    -- Reserve the drone for this delivery.
    UPDATE public.drones
    SET
        status = 'assigned',
        updated_at = now()
    WHERE id = v_drone_id;

    -- Record the dispatch event.
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

-- Prevent implicit PUBLIC access to the SECURITY DEFINER function.
REVOKE ALL
ON FUNCTION public.vendor_mark_order_ready(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.vendor_mark_order_ready(uuid)
FROM anon;

GRANT EXECUTE
ON FUNCTION public.vendor_mark_order_ready(uuid)
TO authenticated;

-- ============================================================
-- 8. STORAGE BUCKETS
-- ============================================================

INSERT INTO storage.buckets (
    id,
    name,
    public
)
VALUES (
    'avatars',
    'avatars',
    true
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (
    id,
    name,
    public
)
VALUES (
    'vendor-logos',
    'vendor-logos',
    true
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 9. AVATAR STORAGE POLICIES
-- ============================================================

DROP POLICY IF EXISTS "Public Access to Avatars"
ON storage.objects;

DROP POLICY IF EXISTS "Owner Upload Avatars"
ON storage.objects;

DROP POLICY IF EXISTS "Owner Update Avatars"
ON storage.objects;

DROP POLICY IF EXISTS "Owner Delete Avatars"
ON storage.objects;

CREATE POLICY "Public Access to Avatars"
ON storage.objects
FOR SELECT
USING (
    bucket_id = 'avatars'
);

CREATE POLICY "Owner Upload Avatars"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Owner Update Avatars"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Owner Delete Avatars"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================================
-- 10. VENDOR LOGO STORAGE POLICIES
-- ============================================================

DROP POLICY IF EXISTS "Public Access to Vendor Logos"
ON storage.objects;

DROP POLICY IF EXISTS "Owner Upload Logos"
ON storage.objects;

DROP POLICY IF EXISTS "Owner Update Logos"
ON storage.objects;

DROP POLICY IF EXISTS "Owner Delete Logos"
ON storage.objects;

CREATE POLICY "Public Access to Vendor Logos"
ON storage.objects
FOR SELECT
USING (
    bucket_id = 'vendor-logos'
);

CREATE POLICY "Owner Upload Logos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'vendor-logos'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Owner Update Logos"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'vendor-logos'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'vendor-logos'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Owner Delete Logos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'vendor-logos'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Ask PostgREST to refresh the schema after commit.
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ============================================================
-- OPTIONAL VERIFICATION QUERIES
-- These run after the migration and do not modify data.
-- ============================================================

-- Confirm only the new roles remain.
SELECT
    role,
    count(*) AS account_count
FROM public.users
GROUP BY role
ORDER BY role;

-- Confirm the Auth triggers exist.
SELECT
    tgname AS trigger_name,
    pg_get_triggerdef(oid) AS trigger_definition
FROM pg_trigger
WHERE tgrelid = 'auth.users'::regclass
  AND NOT tgisinternal
ORDER BY tgname;

-- Confirm the business-logo column exists.
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'users'
  AND column_name = 'business_logo_url';

-- Confirm the vendor dispatch function exists.
SELECT
    routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'vendor_mark_order_ready';

-- Confirm the Storage buckets exist.
SELECT
    id,
    name,
    public
FROM storage.buckets
WHERE id IN ('avatars', 'vendor-logos')
ORDER BY id;

-- Find any existing RLS policies that still mention old roles.
SELECT
    schemaname,
    tablename,
    policyname,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND (
      coalesce(qual, '') ILIKE '%student%'
      OR coalesce(qual, '') ILIKE '%faculty_staff%'
      OR coalesce(with_check, '') ILIKE '%student%'
      OR coalesce(with_check, '') ILIKE '%faculty_staff%'
  )
ORDER BY tablename, policyname;