-- Create the secure weather simulation RPC function
CREATE OR REPLACE FUNCTION public.set_simulated_weather(
  p_safety_status text
)
RETURNS public.weather_safety
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_condition text;
  v_temperature numeric;
  v_wind_speed numeric;
  v_message text;
  v_row public.weather_safety;
BEGIN
  -- Require authenticated user
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- Validate safety status
  IF p_safety_status IS NULL OR p_safety_status NOT IN ('safe', 'caution', 'grounded') THEN
    RAISE EXCEPTION 'Invalid safety status. Allowed values: safe, caution, grounded';
  END IF;

  -- Map safety status to weather parameters
  IF p_safety_status = 'safe' THEN
    v_condition := 'Clear';
    v_temperature := 30;
    v_wind_speed := 8;
    v_message := 'Weather is safe for drone delivery.';
  ELSIF p_safety_status = 'caution' THEN
    v_condition := 'High Winds';
    v_temperature := 28;
    v_wind_speed := 25;
    v_message := 'Drone delivery may be delayed due to strong winds.';
  ELSE
    v_condition := 'Heavy Rain';
    v_temperature := 22;
    v_wind_speed := 40;
    v_message := 'Drone delivery is grounded due to unsafe weather.';
  END IF;

  -- Select single latest row
  SELECT * INTO v_row
  FROM public.weather_safety
  ORDER BY updated_at DESC
  LIMIT 1;

  IF v_row.id IS NOT NULL THEN
    -- Update existing row (do not create multiple rows)
    UPDATE public.weather_safety
    SET
      condition = v_condition,
      temperature = v_temperature,
      wind_speed = v_wind_speed,
      safety_status = p_safety_status,
      message = v_message,
      updated_at = now()
    WHERE id = v_row.id
    RETURNING * INTO v_row;
  ELSE
    -- Insert new row if none exists
    INSERT INTO public.weather_safety (
      id,
      condition,
      temperature,
      wind_speed,
      safety_status,
      message,
      updated_at
    )
    VALUES (
      gen_random_uuid(),
      v_condition,
      v_temperature,
      v_wind_speed,
      p_safety_status,
      v_message,
      now()
    )
    RETURNING * INTO v_row;
  END IF;

  -- Notify PostgREST to reload schema
  NOTIFY pgrst, 'reload schema';

  RETURN v_row;
END;
$$;

-- Revoke access from PUBLIC and anon
REVOKE ALL ON FUNCTION public.set_simulated_weather(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_simulated_weather(text) FROM anon;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.set_simulated_weather(text) TO authenticated;
