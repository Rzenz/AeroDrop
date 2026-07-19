-- 07_vendors_status.sql
-- Add status_id column to vendors table if it doesn't exist
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS status_id uuid REFERENCES public.vendor_statuses(id);

-- Update existing vendors to active status dynamically
UPDATE public.vendors 
SET status_id = (SELECT id FROM public.vendor_statuses WHERE name = 'active') 
WHERE status_id IS NULL;
