-- ============================================================================
-- MIGRATION 15: LIVE CAMPUS WEATHER (OPEN-METEO) & ADMIN OVERRIDE
-- ============================================================================

BEGIN;

-- 1. EXTENSIONS (Safely handled; can also be enabled in Dashboard: Database -> Extensions)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS "pg_net";
    CREATE EXTENSION IF NOT EXISTS "pg_cron";
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Extension enablement note: %', SQLERRM;
END $$;

-- 2. SCHEMA ALTERATIONS FOR WEATHER_SAFETY
-- ----------------------------------------------------------------------------
ALTER TABLE public.weather_safety
    -- Real sensor readings (authoritative; never overwritten by simulation)
    ADD COLUMN IF NOT EXISTS wind_gusts numeric(8, 2),
    ADD COLUMN IF NOT EXISTS precipitation numeric(8, 2) DEFAULT 0.0,
    ADD COLUMN IF NOT EXISTS weather_code integer,
    ADD COLUMN IF NOT EXISTS visibility numeric(10, 2),
    ADD COLUMN IF NOT EXISTS last_fetched_at timestamptz,
    ADD COLUMN IF NOT EXISTS last_fetch_error text,
    ADD COLUMN IF NOT EXISTS pending_request_id bigint,
    ADD COLUMN IF NOT EXISTS pending_requested_at timestamptz,
    ADD COLUMN IF NOT EXISTS real_safety_status text DEFAULT 'safe',
    ADD COLUMN IF NOT EXISTS real_condition text,
    ADD COLUMN IF NOT EXISTS real_message text,

    -- Simulated values (used solely for admin demo display)
    ADD COLUMN IF NOT EXISTS simulated_temperature numeric(6, 2),
    ADD COLUMN IF NOT EXISTS simulated_wind_speed numeric(8, 2),
    ADD COLUMN IF NOT EXISTS simulated_condition text,
    ADD COLUMN IF NOT EXISTS simulated_message text,

    -- Override control
    ADD COLUMN IF NOT EXISTS override_status text,
    ADD COLUMN IF NOT EXISTS override_until timestamptz,
    ADD COLUMN IF NOT EXISTS override_by uuid REFERENCES public.users(id) ON DELETE SET NULL;

-- 3. PURE WEATHER THRESHOLD EVALUATOR
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.evaluate_weather_safety(
    p_temperature numeric,
    p_wind_speed numeric,
    p_wind_gusts numeric,
    p_precipitation numeric,
    p_weather_code integer,
    p_visibility numeric
)
RETURNS TABLE (
    safety_status text,
    condition text,
    message text
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    -- TUNABLE OPERATING LIMITS (Small multirotor ~12 m/s limit, unsealed, <=0.5kg payload)
    c_max_safe_wind       CONSTANT numeric := 15.0;   -- km/h
    c_max_caution_wind    CONSTANT numeric := 28.0;   -- km/h (~7.8 m/s)
    c_max_safe_gusts      CONSTANT numeric := 25.0;   -- km/h
    c_max_caution_gusts   CONSTANT numeric := 40.0;   -- km/h (~11.1 m/s)
    c_min_grounded_precip CONSTANT numeric :=  0.5;   -- mm/h
    c_min_safe_vis        CONSTANT numeric := 1000.0;  -- meters
    c_max_safe_temp       CONSTANT numeric := 40.0;   -- deg C
    
    v_is_thunderstorm boolean;
    v_weather_desc text;
BEGIN
    v_is_thunderstorm := (p_weather_code IN (95, 96, 99) OR p_weather_code >= 95);

    CASE p_weather_code
        WHEN 0 THEN v_weather_desc := 'Clear Sky';
        WHEN 1 THEN v_weather_desc := 'Mainly Clear';
        WHEN 2 THEN v_weather_desc := 'Partly Cloudy';
        WHEN 3 THEN v_weather_desc := 'Overcast';
        WHEN 45, 48 THEN v_weather_desc := 'Fog';
        WHEN 51, 53, 55 THEN v_weather_desc := 'Drizzle';
        WHEN 56, 57 THEN v_weather_desc := 'Freezing Drizzle';
        WHEN 61, 63, 65 THEN v_weather_desc := 'Rain';
        WHEN 66, 67 THEN v_weather_desc := 'Freezing Rain';
        WHEN 71, 73, 75, 77 THEN v_weather_desc := 'Snow';
        WHEN 80, 81, 82 THEN v_weather_desc := 'Rain Showers';
        WHEN 85, 86 THEN v_weather_desc := 'Snow Showers';
        WHEN 95 THEN v_weather_desc := 'Thunderstorm';
        WHEN 96, 99 THEN v_weather_desc := 'Severe Thunderstorm';
        ELSE v_weather_desc := 'Variable Conditions';
    END CASE;

    -- 1. GROUNDED (Priority checks: any fatal condition grounds flights)
    IF v_is_thunderstorm THEN
        RETURN QUERY SELECT 
            'grounded'::text,
            'Thunderstorm'::text,
            'Thunderstorm detected — all campus drone operations are grounded.'::text;
        RETURN;
    ELSIF p_precipitation >= c_min_grounded_precip THEN
        RETURN QUERY SELECT 
            'grounded'::text,
            'Rain (' || round(p_precipitation, 1)::text || ' mm/h)',
            'Rain exceeds water resistance threshold — campus flights grounded.'::text;
        RETURN;
    ELSIF p_wind_speed > c_max_caution_wind THEN
        RETURN QUERY SELECT 
            'grounded'::text,
            'High Winds (' || round(p_wind_speed, 1)::text || ' km/h)',
            'Wind speed exceeds drone aerodynamic limits — flights grounded.'::text;
        RETURN;
    ELSIF p_wind_gusts > c_max_caution_gusts THEN
        RETURN QUERY SELECT 
            'grounded'::text,
            'Severe Gusts (' || round(p_wind_gusts, 1)::text || ' km/h)',
            'Turbulent wind gusts exceed safe flight margins — flights grounded.'::text;
        RETURN;
    ELSIF p_visibility < c_min_safe_vis THEN
        RETURN QUERY SELECT 
            'grounded'::text,
            'Low Visibility (' || round(p_visibility, 0)::text || ' m)',
            'Visibility below campus VFR operating limits (<1000m) — flights grounded.'::text;
        RETURN;
    ELSIF p_temperature > c_max_safe_temp THEN
        RETURN QUERY SELECT 
            'grounded'::text,
            'Extreme Heat (' || round(p_temperature, 1)::text || '°C)',
            'Ambient temperature exceeds safe motor and battery limits (>40°C) — flights grounded.'::text;
        RETURN;

    -- 2. CAUTION
    ELSIF (p_wind_speed > c_max_safe_wind AND p_wind_speed <= c_max_caution_wind)
       OR (p_wind_gusts > c_max_safe_gusts AND p_wind_gusts <= c_max_caution_gusts)
       OR (p_precipitation > 0 AND p_precipitation < c_min_grounded_precip) THEN
       
        IF p_precipitation > 0 THEN
            RETURN QUERY SELECT 
                'caution'::text,
                'Light Rain',
                'Light rain detected — deliveries may experience minor delays.'::text;
        ELSIF p_wind_gusts > c_max_safe_gusts THEN
            RETURN QUERY SELECT 
                'caution'::text,
                'Gusty Winds (' || round(p_wind_gusts, 1)::text || ' km/h)',
                'Gusty winds detected — drone delivery speeds may be throttled.'::text;
        ELSE
            RETURN QUERY SELECT 
                'caution'::text,
                'Moderate Winds (' || round(p_wind_speed, 1)::text || ' km/h)',
                'Moderate wind speeds — deliveries may take slightly longer.'::text;
        END IF;
        RETURN;

    -- 3. SAFE
    ELSE
        RETURN QUERY SELECT 
            'safe'::text,
            v_weather_desc,
            'Weather conditions are safe for campus drone dispatch.'::text;
        RETURN;
    END IF;
END;
$$;

-- 4. HTTP REQUEST DISPATCHER (PG_NET)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_campus_weather()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_url text := 'https://api.open-meteo.com/v1/forecast?latitude=10.3252&longitude=123.9532&current=temperature_2m,precipitation,weather_code,wind_speed_10m,wind_gusts_10m,visibility&wind_speed_unit=kmh&timezone=Asia%2FManila';
    v_req_id bigint;
    v_weather_id uuid;
BEGIN
    SELECT id INTO v_weather_id
    FROM public.weather_safety
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_weather_id IS NULL THEN
        INSERT INTO public.weather_safety (safety_status, condition, message)
        VALUES ('safe', 'Clear Sky', 'Campus weather initialized.')
        RETURNING id INTO v_weather_id;
    END IF;

    -- Dispatch async GET via pg_net
    v_req_id := net.http_get(
        url := v_url,
        timeout_milliseconds := 8000
    );

    UPDATE public.weather_safety
    SET pending_request_id = v_req_id,
        pending_requested_at = now()
    WHERE id = v_weather_id;

    RETURN v_req_id;
END;
$$;

-- 5. HTTP RESPONSE COLLECTOR & STATE EVALUATOR
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.process_campus_weather_response()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_weather public.weather_safety%ROWTYPE;
    v_resp record;
    v_json jsonb;
    v_current jsonb;
    v_temp numeric;
    v_wind numeric;
    v_gusts numeric;
    v_precip numeric;
    v_code integer;
    v_vis numeric;
    v_eval record;
    v_is_override boolean;
BEGIN
    SELECT * INTO v_weather
    FROM public.weather_safety
    ORDER BY updated_at DESC
    LIMIT 1
    FOR UPDATE;

    IF v_weather.id IS NULL OR v_weather.pending_request_id IS NULL THEN
        RETURN false;
    END IF;

    -- Query pg_net response table
    SELECT * INTO v_resp
    FROM net._http_response
    WHERE id = v_weather.pending_request_id;

    -- If response not yet recorded by worker, check for timeout
    IF NOT FOUND THEN
        IF v_weather.pending_requested_at < now() - interval '2 minutes' THEN
            UPDATE public.weather_safety
            SET last_fetch_error = 'Open-Meteo request timed out (>2m)',
                pending_request_id = NULL
            WHERE id = v_weather.id;
        END IF;
        RETURN false;
    END IF;

    -- If request failed, keep last known values and record error
    IF v_resp.status_code <> 200 OR v_resp.timed_out OR v_resp.error_msg IS NOT NULL THEN
        UPDATE public.weather_safety
        SET last_fetch_error = coalesce(v_resp.error_msg, 'HTTP error ' || v_resp.status_code::text),
            pending_request_id = NULL
        WHERE id = v_weather.id;
        RETURN false;
    END IF;

    -- Parse JSON response
    BEGIN
        v_json := v_resp.content::jsonb;
        v_current := v_json->'current';
        
        v_temp   := (v_current->>'temperature_2m')::numeric;
        v_wind   := (v_current->>'wind_speed_10m')::numeric;
        v_gusts  := coalesce((v_current->>'wind_gusts_10m')::numeric, v_wind);
        v_precip := coalesce((v_current->>'precipitation')::numeric, 0.0);
        v_code   := (v_current->>'weather_code')::integer;
        v_vis    := coalesce((v_current->>'visibility')::numeric, 10000.0);
    EXCEPTION WHEN OTHERS THEN
        UPDATE public.weather_safety
        SET last_fetch_error = 'JSON parse error: ' || SQLERRM,
            pending_request_id = NULL
        WHERE id = v_weather.id;
        RETURN false;
    END;

    -- Evaluate thresholds on actual sensor values
    SELECT * INTO v_eval
    FROM public.evaluate_weather_safety(v_temp, v_wind, v_gusts, v_precip, v_code, v_vis);

    v_is_override := (v_weather.override_until IS NOT NULL AND v_weather.override_until > now());

    IF v_is_override THEN
        -- Override active: update real telemetry & real status; do NOT touch safety_status
        UPDATE public.weather_safety
        SET temperature = v_temp,
            wind_speed = v_wind,
            wind_gusts = v_gusts,
            precipitation = v_precip,
            weather_code = v_code,
            visibility = v_vis,
            real_safety_status = v_eval.safety_status,
            real_condition = v_eval.condition,
            real_message = v_eval.message,
            last_fetched_at = now(),
            last_fetch_error = NULL,
            pending_request_id = NULL
        WHERE id = v_weather.id;
    ELSE
        -- No active override: update real telemetry and operational status
        UPDATE public.weather_safety
        SET temperature = v_temp,
            wind_speed = v_wind,
            wind_gusts = v_gusts,
            precipitation = v_precip,
            weather_code = v_code,
            visibility = v_vis,
            real_safety_status = v_eval.safety_status,
            real_condition = v_eval.condition,
            real_message = v_eval.message,
            safety_status = v_eval.safety_status,
            condition = v_eval.condition,
            message = v_eval.message,
            override_status = NULL,
            override_until = NULL,
            override_by = NULL,
            simulated_temperature = NULL,
            simulated_wind_speed = NULL,
            simulated_condition = NULL,
            simulated_message = NULL,
            last_fetched_at = now(),
            last_fetch_error = NULL,
            pending_request_id = NULL,
            updated_at = CASE 
                WHEN v_weather.safety_status IS DISTINCT FROM v_eval.safety_status THEN now() 
                ELSE v_weather.updated_at 
            END
        WHERE id = v_weather.id;
    END IF;

    RETURN true;
END;
$$;

-- 6. UNIFIED CRON TICKER (Checks override expiry & 15m fetch every minute)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_campus_weather()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_weather public.weather_safety%ROWTYPE;
    v_real_status text;
    v_real_cond text;
    v_real_msg text;
    v_eval record;
BEGIN
    SELECT *
    INTO v_weather
    FROM public.weather_safety
    ORDER BY updated_at DESC
    LIMIT 1
    FOR UPDATE;

    IF v_weather.id IS NULL THEN
        PERFORM public.request_campus_weather();
        RETURN;
    END IF;

    -- 1. INSTANT EXPIRATION CHECK: If override expired, clear and restore real weather immediately
    IF v_weather.override_until IS NOT NULL AND v_weather.override_until <= now() THEN
        IF v_weather.temperature IS NOT NULL AND v_weather.wind_speed IS NOT NULL THEN
            SELECT * INTO v_eval
            FROM public.evaluate_weather_safety(
                v_weather.temperature,
                v_weather.wind_speed,
                coalesce(v_weather.wind_gusts, v_weather.wind_speed),
                coalesce(v_weather.precipitation, 0.0),
                coalesce(v_weather.weather_code, 0),
                coalesce(v_weather.visibility, 10000.0)
            );
            v_real_status := v_eval.safety_status;
            v_real_cond := v_eval.condition;
            v_real_msg := v_eval.message;
        ELSE
            v_real_status := coalesce(v_weather.real_safety_status, 'safe');
            v_real_cond := coalesce(v_weather.real_condition, 'Clear Sky');
            v_real_msg := coalesce(v_weather.real_message, 'Weather conditions are safe for campus drone dispatch.');
        END IF;

        UPDATE public.weather_safety
        SET
            override_status = NULL,
            override_until = NULL,
            override_by = NULL,
            simulated_temperature = NULL,
            simulated_wind_speed = NULL,
            simulated_condition = NULL,
            simulated_message = NULL,
            safety_status = v_real_status,
            condition = v_real_cond,
            message = v_real_msg,
            updated_at = CASE 
                WHEN v_weather.safety_status IS DISTINCT FROM v_real_status THEN now() 
                ELSE v_weather.updated_at 
            END
        WHERE id = v_weather.id;

        -- Refresh local variable for fetch decision below
        SELECT * INTO v_weather FROM public.weather_safety WHERE id = v_weather.id;
    END IF;

    -- 2. COLLECT PENDING ASYNC RESPONSE
    IF v_weather.pending_request_id IS NOT NULL THEN
        PERFORM public.process_campus_weather_response();
        RETURN;
    END IF;

    -- 3. SCHEDULED DISPATCH: Fetch every 15 minutes (or immediately if never fetched)
    IF v_weather.last_fetched_at IS NULL OR v_weather.last_fetched_at < now() - interval '15 minutes' THEN
        PERFORM public.request_campus_weather();
    END IF;
END;
$$;

-- 7. ADMIN OVERRIDE RPCS
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.set_simulated_weather(text);
DROP FUNCTION IF EXISTS public.set_simulated_weather(text, numeric);

CREATE OR REPLACE FUNCTION public.set_simulated_weather(
    p_safety_status text,
    p_duration_hours numeric DEFAULT 2.0
)
RETURNS public.weather_safety
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_status text;
    v_sim_cond text;
    v_sim_msg text;
    v_sim_temp numeric(6, 2);
    v_sim_wind numeric(8, 2);
    v_duration numeric;
    v_weather public.weather_safety%ROWTYPE;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Only administrators may change weather safety.';
    END IF;

    v_status := lower(trim(coalesce(p_safety_status, '')));
    v_duration := coalesce(p_duration_hours, 2.0);

    CASE v_status
        WHEN 'safe' THEN
            v_sim_cond := 'Clear Skies (Simulated)';
            v_sim_temp := 30.0;
            v_sim_wind := 10.0;
            v_sim_msg := 'Weather conditions are safe for campus drone dispatch (Admin Override).';
        WHEN 'caution' THEN
            v_sim_cond := 'High Winds (Simulated)';
            v_sim_temp := 32.0;
            v_sim_wind := 28.0;
            v_sim_msg := 'Delivery may be delayed due to caution-level weather conditions (Admin Override).';
        WHEN 'grounded' THEN
            v_sim_cond := 'Heavy Rain (Simulated)';
            v_sim_temp := 22.0;
            v_sim_wind := 40.0;
            v_sim_msg := 'Weather is currently unsafe for drone delivery. Please try again later (Admin Override).';
        ELSE
            RAISE EXCEPTION 'Invalid weather status. Use safe, caution, or grounded.';
    END CASE;

    SELECT *
    INTO v_weather
    FROM public.weather_safety
    ORDER BY updated_at DESC
    LIMIT 1
    FOR UPDATE;

    -- Real telemetry columns (temperature, wind_speed, wind_gusts, etc.) are NOT touched
    IF FOUND THEN
        UPDATE public.weather_safety
        SET
            safety_status = v_status,
            condition = v_sim_cond,
            message = v_sim_msg,
            override_status = v_status,
            override_until = now() + (v_duration || ' hours')::interval,
            override_by = auth.uid(),
            simulated_temperature = v_sim_temp,
            simulated_wind_speed = v_sim_wind,
            simulated_condition = v_sim_cond,
            simulated_message = v_sim_msg,
            updated_at = now()
        WHERE id = v_weather.id
        RETURNING *
        INTO v_weather;
    ELSE
        INSERT INTO public.weather_safety (
            safety_status,
            condition,
            message,
            override_status,
            override_until,
            override_by,
            simulated_temperature,
            simulated_wind_speed,
            simulated_condition,
            simulated_message,
            updated_at
        ) VALUES (
            v_status,
            v_sim_cond,
            v_sim_msg,
            v_status,
            now() + (v_duration || ' hours')::interval,
            auth.uid(),
            v_sim_temp,
            v_sim_wind,
            v_sim_cond,
            v_sim_msg,
            now()
        )
        RETURNING *
        INTO v_weather;
    END IF;

    RETURN v_weather;
END;
$$;

CREATE OR REPLACE FUNCTION public.clear_weather_override()
RETURNS public.weather_safety
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_weather public.weather_safety%ROWTYPE;
    v_real_status text;
    v_real_cond text;
    v_real_msg text;
    v_eval record;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Only administrators may clear weather override.';
    END IF;

    SELECT * INTO v_weather
    FROM public.weather_safety
    ORDER BY updated_at DESC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No weather safety record found.';
    END IF;

    -- Evaluate from authoritative real physical readings (never polluted by simulation)
    IF v_weather.temperature IS NOT NULL AND v_weather.wind_speed IS NOT NULL THEN
        SELECT * INTO v_eval
        FROM public.evaluate_weather_safety(
            v_weather.temperature,
            v_weather.wind_speed,
            coalesce(v_weather.wind_gusts, v_weather.wind_speed),
            coalesce(v_weather.precipitation, 0.0),
            coalesce(v_weather.weather_code, 0),
            coalesce(v_weather.visibility, 10000.0)
        );
        v_real_status := v_eval.safety_status;
        v_real_cond := v_eval.condition;
        v_real_msg := v_eval.message;
    ELSE
        v_real_status := coalesce(v_weather.real_safety_status, 'safe');
        v_real_cond := coalesce(v_weather.real_condition, 'Clear Sky');
        v_real_msg := coalesce(v_weather.real_message, 'Weather conditions are safe for campus drone dispatch.');
    END IF;

    UPDATE public.weather_safety
    SET
        override_status = NULL,
        override_until = NULL,
        override_by = NULL,
        simulated_temperature = NULL,
        simulated_wind_speed = NULL,
        simulated_condition = NULL,
        simulated_message = NULL,
        safety_status = v_real_status,
        condition = v_real_cond,
        message = v_real_msg,
        updated_at = CASE 
            WHEN v_weather.safety_status IS DISTINCT FROM v_real_status THEN now() 
            ELSE v_weather.updated_at 
        END
    WHERE id = v_weather.id
    RETURNING * INTO v_weather;

    RETURN v_weather;
END;
$$;

-- 8. SECURITY & PERMISSIONS
-- ----------------------------------------------------------------------------
-- Strip client access from internal pipeline RPCs
REVOKE ALL ON FUNCTION public.request_campus_weather() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.process_campus_weather_response() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_campus_weather() FROM PUBLIC, anon, authenticated;

-- Allow execution by background worker and service backend only
GRANT EXECUTE ON FUNCTION public.request_campus_weather() TO postgres, service_role;
GRANT EXECUTE ON FUNCTION public.process_campus_weather_response() TO postgres, service_role;
GRANT EXECUTE ON FUNCTION public.sync_campus_weather() TO postgres, service_role;

-- Admin override RPCs accessible to authenticated users (admin check enforced internally)
REVOKE ALL ON FUNCTION public.set_simulated_weather(text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_simulated_weather(text, numeric) TO authenticated;

REVOKE ALL ON FUNCTION public.clear_weather_override() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.clear_weather_override() TO authenticated;

-- 9. PG_CRON SCHEDULE REGISTRATION
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'sync-campus-weather') THEN
        PERFORM cron.unschedule('sync-campus-weather');
    END IF;
END $$;

SELECT cron.schedule(
    'sync-campus-weather',
    '* * * * *',
    $$SELECT public.sync_campus_weather();$$
);

COMMIT;
