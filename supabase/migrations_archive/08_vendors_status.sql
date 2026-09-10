-- 08_vendors_status.sql
-- In current architecture, vendor_status is stored directly on public.users ('pending', 'active', 'suspended', 'rejected').
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS vendor_status text;

-- Ensure existing vendor accounts default to active status if not set
UPDATE public.users 
SET vendor_status = 'active'
WHERE role = 'vendor' AND vendor_status IS NULL;
