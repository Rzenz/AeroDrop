-- ============================================================================
-- 40_custom_dropoff_write_path.sql
--
-- Part 2 of 2 for customer-chosen drop-off points. Migration 39 added the
-- zone, the columns, the distance helpers and the pricing. This makes an
-- order with a pin actually placeable, dispatchable and flyable.
--
-- FOUR CHANGES
--   1. place_order accepts a pin, refuses one outside the zone, prices to it,
--      and stores it on the order.
--   2. vendor_mark_order_ready stops refusing an order that has a pin instead
--      of a location id. Without this, a custom order could be placed and
--      then never dispatched.
--   3. A trigger copies the pin from the order onto the delivery, so the
--      app's flight simulation reads one row instead of joining back.
--   4. get_order_flight_plan returns the pin as the drop-off waypoint.
--
-- WHY A TRIGGER FOR (3) RATHER THAN PATCHING vendor_mark_order_ready
-- That function writes deliveries in three places -- an INSERT and an UPDATE
-- in two branches. Patching all three means three coordinated edits to a
-- 200-line function, each a chance to half-apply. A trigger is one object
-- that cannot be partially correct, and it also covers any future code path
-- that creates a delivery.
--
-- ORDERS WITHOUT A PIN ARE UNAFFECTED. Every new parameter defaults to NULL,
-- and with them NULL every function behaves exactly as it does today. The
-- website calls place_order with eight arguments and keeps working.
--
-- SCHEMA VERIFIED AGAINST APPLIED MIGRATIONS 01-39.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. place_order accepts a pin
--
-- Patched from the live definition rather than restated, so this file cannot
-- drift from migrations 31 and 33. Three edits, each asserted:
--
--   a. three new parameters, all defaulting to NULL
--   b. validation and the pricing call, which now receives the pin
--   c. the pin is written onto the order after it is created
--
-- (c) is done as an UPDATE immediately after the INSERT rather than by
-- editing the INSERT's column and VALUES lists. Those are two lists that must
-- stay in step; editing them separately is the kind of change that applies
-- halfway and corrupts every order. The UPDATE runs in the same transaction.
-- ----------------------------------------------------------------------------
DO $migration$
DECLARE
    v_def      text;
    v_sig_old  text := ', p_notes text DEFAULT NULL::text)';
    v_sig_new  text := ', p_notes text DEFAULT NULL::text'
                    || ', p_dropoff_lat numeric DEFAULT NULL::numeric'
                    || ', p_dropoff_lng numeric DEFAULT NULL::numeric'
                    || ', p_dropoff_label text DEFAULT NULL::text)';
    v_price_old text := 'v_pricing := public.compute_order_pricing(p_vendor_id, p_delivery_location_id, p_items);';
    v_price_new text :=
         'IF p_dropoff_lat IS NULL AND p_delivery_location_id IS NULL THEN'
      || E'\n        RAISE EXCEPTION ''An order needs either a campus drop-off point or a map pin.'';'
      || E'\n    END IF;'
      || E'\n'
      || E'\n    IF p_dropoff_lat IS NOT NULL AND NOT public.is_within_delivery_zone(p_dropoff_lat, p_dropoff_lng) THEN'
      || E'\n        RAISE EXCEPTION ''That spot is outside the UCLM delivery area. Choose a point inside the circle.'';'
      || E'\n    END IF;'
      || E'\n'
      || E'\n    v_pricing := public.compute_order_pricing(p_vendor_id, p_delivery_location_id, p_items, p_dropoff_lat, p_dropoff_lng);';
    v_ret_old  text := ') RETURNING id INTO v_order_id;';
    v_ret_new  text := ') RETURNING id INTO v_order_id;'
                    || E'\n'
                    || E'\n    IF p_dropoff_lat IS NOT NULL THEN'
                    || E'\n        UPDATE public.orders'
                    || E'\n        SET custom_dropoff_lat   = p_dropoff_lat,'
                    || E'\n            custom_dropoff_lng   = p_dropoff_lng,'
                    || E'\n            custom_dropoff_label = nullif(btrim(coalesce(p_dropoff_label, '''')), '''')'
                    || E'\n        WHERE id = v_order_id;'
                    || E'\n    END IF;';
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'place_order'
      AND pg_get_function_identity_arguments(p.oid) =
          'p_vendor_id uuid, p_delivery_location_id uuid, p_subtotal numeric, '
          'p_delivery_fee numeric, p_total_amount numeric, p_payment_method text, '
          'p_items jsonb, p_notes text';

    IF v_def IS NULL THEN
        RAISE EXCEPTION
            'The 8-argument place_order was not found. Either migrations 31 and 33 '
            'were never applied, or this migration has already run.';
    END IF;

    IF position(v_sig_old IN v_def) = 0 THEN
        RAISE EXCEPTION 'Could not find the end of place_order''s argument list. Patch by hand.';
    END IF;
    IF position(v_price_old IN v_def) = 0 THEN
        RAISE EXCEPTION
            'Could not find place_order''s call to compute_order_pricing. It has '
            'drifted from migration 31; patch by hand.';
    END IF;
    IF position(v_ret_old IN v_def) = 0 THEN
        RAISE EXCEPTION 'Could not find the order INSERT''s RETURNING clause. Patch by hand.';
    END IF;

    v_def := replace(v_def, v_sig_old,   v_sig_new);
    v_def := replace(v_def, v_price_old, v_price_new);
    v_def := replace(v_def, v_ret_old,   v_ret_new);

    -- The old one goes first: PostgREST resolves by argument name, and with
    -- defaults in play an 8-argument call would match both.
    DROP FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text);
    EXECUTE v_def;

    RAISE NOTICE 'place_order now accepts a custom drop-off pin.';
END;
$migration$;

REVOKE ALL ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text, numeric, numeric, text)
    FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.place_order(uuid, uuid, numeric, numeric, numeric, text, jsonb, text, numeric, numeric, text)
    TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. A pinned order can be dispatched
--
-- vendor_mark_order_ready refuses an order whose delivery_location_id is
-- NULL. For a pinned order that is the normal state, so without this change
-- the customer could pay and the vendor could never send it.
-- ----------------------------------------------------------------------------
DO $migration$
DECLARE
    v_def text;
    -- A SINGLE-LINE anchor, deliberately. The first version of this migration
    -- matched the whole three-line IF block and failed: multi-line matching
    -- breaks on a different indentation or on CRLF line endings, and
    -- pg_get_functiondef returns the body exactly as it was created.
    --
    -- Wrapping just the RAISE in an inner guard is equivalent: the outer IF
    -- still fires when there is no location id, and the exception is now
    -- raised only when there is no pin either.
    v_old text := 'RAISE EXCEPTION ''Order dropoff location not configured'';';
    v_new text := 'IF NOT EXISTS (SELECT 1 FROM public.orders WHERE id = p_order_id AND custom_dropoff_lat IS NOT NULL) THEN RAISE EXCEPTION ''Order dropoff location not configured''; END IF;';
    v_hits integer;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'vendor_mark_order_ready';

    IF v_def IS NULL THEN
        RAISE EXCEPTION 'vendor_mark_order_ready not found.';
    END IF;

    IF position('custom_dropoff_lat IS NOT NULL' IN v_def) > 0 THEN
        RAISE NOTICE 'vendor_mark_order_ready already allows a pinned drop-off; nothing to do.';
        RETURN;
    END IF;

    v_hits := (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old);

    IF v_hits = 0 THEN
        RAISE EXCEPTION
            'Could not find the dropoff guard in vendor_mark_order_ready. Send me '
            'the output of: select pg_get_functiondef(oid) from pg_proc where '
            'proname = ''vendor_mark_order_ready'';';
    END IF;

    IF v_hits > 1 THEN
        RAISE EXCEPTION
            'The dropoff guard appears % times in vendor_mark_order_ready; '
            'patch by hand rather than replacing all of them.', v_hits;
    END IF;

    EXECUTE replace(v_def, v_old, v_new);
    RAISE NOTICE 'vendor_mark_order_ready now dispatches orders with a map pin.';
END;
$migration$;

-- ----------------------------------------------------------------------------
-- 3. The delivery carries the pin
--
-- The app's flight simulation reads the delivery row on every tick. Copying
-- the pin here means it never has to join back to the order, and it stays
-- correct for any future code path that creates a delivery.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.copy_custom_dropoff_to_delivery()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.custom_dropoff_lat IS NULL AND NEW.order_id IS NOT NULL THEN
        SELECT o.custom_dropoff_lat, o.custom_dropoff_lng
        INTO NEW.custom_dropoff_lat, NEW.custom_dropoff_lng
        FROM public.orders o WHERE o.id = NEW.order_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_copy_custom_dropoff ON public.deliveries;
CREATE TRIGGER trg_copy_custom_dropoff
    BEFORE INSERT OR UPDATE OF order_id ON public.deliveries
    FOR EACH ROW
    EXECUTE FUNCTION public.copy_custom_dropoff_to_delivery();

REVOKE ALL ON FUNCTION public.copy_custom_dropoff_to_delivery() FROM PUBLIC, anon, authenticated;

-- Backfill any delivery already attached to a pinned order.
UPDATE public.deliveries d
SET custom_dropoff_lat = o.custom_dropoff_lat,
    custom_dropoff_lng = o.custom_dropoff_lng
FROM public.orders o
WHERE o.id = d.order_id
  AND o.custom_dropoff_lat IS NOT NULL
  AND d.custom_dropoff_lat IS NULL;

-- ----------------------------------------------------------------------------
-- 4. The flight plan returns the pin
--
-- Restated in full rather than patched: migration 38 is recent, short, and
-- entirely ours, so there is no older definition to drift from.
--
-- A pinned drop-off reports location_code 'CUSTOM' and carries the customer's
-- own words in 'label'. is_custom_dropoff is explicit at the top level so the
-- drone side never has to infer it.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_order_flight_plan(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_role text;
    v_order     record;
    v_hub       record;
    v_pickup    record;
    v_dropoff   record;
    v_alt       numeric;
    v_grams     integer;
    v_items     jsonb;
    v_trips     integer;
    v_custom    boolean;
    v_dz_lat    double precision;
    v_dz_lng    double precision;
    v_dz_name   text;
    v_dz_code   text;
    v_d_pd      numeric;
    v_d_dh      numeric;
    v_drop_json jsonb;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT o.id, o.user_id, o.vendor_id, o.order_status, o.payment_status,
           o.created_at, o.delivery_location_id,
           o.custom_dropoff_lat, o.custom_dropoff_lng, o.custom_dropoff_label,
           v.full_name          AS vendor_name,
           v.campus_location_id AS vendor_location_id,
           c.full_name          AS customer_name,
           d.id                 AS delivery_id,
           d.status             AS delivery_status,
           d.drone_id,
           d.progress,
           coalesce(d.trips_required, 1)  AS trips_required,
           coalesce(d.trips_completed, 0) AS trips_completed,
           d.pickup_location_id,
           d.dropoff_location_id
    INTO v_order
    FROM public.orders o
    LEFT JOIN public.users      v ON v.id = o.vendor_id
    LEFT JOIN public.users      c ON c.id = o.user_id
    LEFT JOIN public.deliveries d ON d.order_id = o.id
    WHERE o.id = p_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    SELECT role INTO v_user_role FROM public.users WHERE id = auth.uid();

    IF v_user_role IS DISTINCT FROM 'admin'
       AND auth.uid() IS DISTINCT FROM v_order.vendor_id
       AND auth.uid() IS DISTINCT FROM v_order.user_id THEN
        RAISE EXCEPTION 'Unauthorized: caller cannot read this order';
    END IF;

    SELECT * INTO v_hub FROM public.campus_locations WHERE location_code = 'BASE-HUB';

    SELECT * INTO v_pickup FROM public.campus_locations
    WHERE id = coalesce(v_order.pickup_location_id, v_order.vendor_location_id);

    v_custom := v_order.custom_dropoff_lat IS NOT NULL;

    IF v_custom THEN
        v_dz_lat  := v_order.custom_dropoff_lat;
        v_dz_lng  := v_order.custom_dropoff_lng;
        v_dz_code := 'CUSTOM';
        v_dz_name := coalesce(v_order.custom_dropoff_label, 'Customer-chosen point');
        v_d_pd := public.campus_to_point_distance_km(v_pickup.id, v_dz_lat, v_dz_lng);
        v_d_dh := public.point_distance_km(v_dz_lat, v_dz_lng, v_hub.latitude, v_hub.longitude);
    ELSE
        SELECT * INTO v_dropoff FROM public.campus_locations
        WHERE id = coalesce(v_order.dropoff_location_id, v_order.delivery_location_id);
        v_dz_lat  := v_dropoff.latitude;
        v_dz_lng  := v_dropoff.longitude;
        v_dz_code := v_dropoff.location_code;
        v_dz_name := v_dropoff.name;
        v_d_pd := public.campus_distance_km(v_pickup.id,  v_dropoff.id);
        v_d_dh := public.campus_distance_km(v_dropoff.id, v_hub.id);
    END IF;

    SELECT coalesce(cruise_altitude_m, 20) INTO v_alt
    FROM public.drones WHERE id = v_order.drone_id;
    IF v_alt IS NULL THEN
        SELECT coalesce(min(cruise_altitude_m), 20) INTO v_alt FROM public.drones;
    END IF;

    SELECT sum(oi.weight_grams * oi.quantity),
           jsonb_agg(jsonb_build_object(
               'product_name', oi.product_name,
               'quantity',     oi.quantity,
               'weight_grams', oi.weight_grams
           ) ORDER BY oi.product_name)
    INTO v_grams, v_items
    FROM public.order_items oi WHERE oi.order_id = p_order_id;

    v_trips := v_order.trips_required;

    v_drop_json := jsonb_build_object(
        'location_code', v_dz_code, 'name', v_dz_name,
        'latitude', v_dz_lat, 'longitude', v_dz_lng, 'altitude_m_agl', v_alt
    );

    RETURN jsonb_build_object(
        'order_id',          v_order.id,
        'order_status',      v_order.order_status,
        'payment_status',    v_order.payment_status,
        'placed_at',         v_order.created_at,
        'is_custom_dropoff', v_custom,

        'vendor', jsonb_build_object(
            'name', v_order.vendor_name,
            'location_code', v_pickup.location_code,
            'building', v_pickup.name
        ),
        'customer', jsonb_build_object(
            'name', v_order.customer_name,
            'location_code', v_dz_code,
            'building', v_dz_name,
            'custom_label', v_order.custom_dropoff_label
        ),

        'payload', jsonb_build_object(
            'total_weight_grams', coalesce(v_grams, 0),
            'total_weight_kg',    round(coalesce(v_grams, 0) / 1000.0, 3),
            'max_payload_kg',     0.5,
            'trips_required',     v_trips,
            'items',              coalesce(v_items, '[]'::jsonb)
        ),

        'altitude_m_agl', v_alt,

        'waypoints', CASE
            WHEN v_trips > 1 THEN jsonb_build_array(
                jsonb_build_object('seq', 1, 'role', 'launch',  'location_code', v_hub.location_code,    'name', v_hub.name,    'latitude', v_hub.latitude,    'longitude', v_hub.longitude,    'altitude_m_agl', 0),
                jsonb_build_object('seq', 2, 'role', 'pickup',  'location_code', v_pickup.location_code, 'name', v_pickup.name, 'latitude', v_pickup.latitude, 'longitude', v_pickup.longitude, 'altitude_m_agl', v_alt),
                v_drop_json  || jsonb_build_object('seq', 3, 'role', 'dropoff'),
                jsonb_build_object('seq', 4, 'role', 'pickup_2','location_code', v_pickup.location_code, 'name', v_pickup.name, 'latitude', v_pickup.latitude, 'longitude', v_pickup.longitude, 'altitude_m_agl', v_alt),
                v_drop_json  || jsonb_build_object('seq', 5, 'role', 'dropoff_2'),
                jsonb_build_object('seq', 6, 'role', 'return',  'location_code', v_hub.location_code,    'name', v_hub.name,    'latitude', v_hub.latitude,    'longitude', v_hub.longitude,    'altitude_m_agl', 0)
            )
            ELSE jsonb_build_array(
                jsonb_build_object('seq', 1, 'role', 'launch',  'location_code', v_hub.location_code,    'name', v_hub.name,    'latitude', v_hub.latitude,    'longitude', v_hub.longitude,    'altitude_m_agl', 0),
                jsonb_build_object('seq', 2, 'role', 'pickup',  'location_code', v_pickup.location_code, 'name', v_pickup.name, 'latitude', v_pickup.latitude, 'longitude', v_pickup.longitude, 'altitude_m_agl', v_alt),
                v_drop_json  || jsonb_build_object('seq', 3, 'role', 'dropoff'),
                jsonb_build_object('seq', 4, 'role', 'return',  'location_code', v_hub.location_code,    'name', v_hub.name,    'latitude', v_hub.latitude,    'longitude', v_hub.longitude,    'altitude_m_agl', 0)
            )
        END,

        'distance_km', jsonb_build_object(
            'hub_to_pickup',     public.campus_distance_km(v_hub.id, v_pickup.id),
            'pickup_to_dropoff', v_d_pd,
            'dropoff_to_hub',    v_d_dh
        ),

        'delivery', jsonb_build_object(
            'delivery_id',     v_order.delivery_id,
            'status',          v_order.delivery_status,
            'drone_id',        v_order.drone_id,
            'trips_completed', v_order.trips_completed,
            'progress',        v_order.progress
        ),

        '_notes', jsonb_build_array(
            CASE WHEN v_custom
                 THEN 'This drop-off is a point the CUSTOMER chose on a map. Nobody has surveyed it and it may not be a safe landing spot. Treat the label as the only description of it.'
                 ELSE 'Coordinates are map estimates, not surveyed points. Not accurate enough to land on.' END,
            'altitude_m_agl comes from drones.cruise_altitude_m, whose default of 20 is a placeholder.',
            'No obstacle data exists and public.no_fly_zones is empty. Nothing here clears a flight.',
            'pickup falls back to the vendor''s building until the vendor marks the order ready.'
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_order_flight_plan(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_order_flight_plan(uuid) TO authenticated;
