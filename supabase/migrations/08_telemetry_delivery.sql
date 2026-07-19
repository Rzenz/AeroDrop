-- 08_telemetry_delivery.sql
-- Add delivery_id column to drone_telemetry table if it doesn't exist
ALTER TABLE public.drone_telemetry ADD COLUMN IF NOT EXISTS delivery_id uuid REFERENCES public.deliveries(id);
