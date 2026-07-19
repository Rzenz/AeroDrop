-- 03_rls_policies.sql
-- Enables RLS and sets policies for basic access control.

-- Helper to check if user has admin role
CREATE OR REPLACE FUNCTION public.is_admin(p_user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.user_credentials uc
    JOIN public.user_roles ur ON uc.role_id = ur.role_id
    WHERE uc.user_id = p_user_id AND ur.role_name = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable RLS on all tables
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drone_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.priority_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.safety_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.telemetry_event_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package_verification_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weather_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.no_fly_zone_statuses ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campus_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_safety_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_status_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drone_telemetry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weather_safety ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.no_fly_zones ENABLE ROW LEVEL SECURITY;

-- 1. READ ONLY LOOKUP TABLES FOR ALL USERS
CREATE POLICY select_lookups ON public.user_roles FOR SELECT USING (true);
CREATE POLICY select_vendor_statuses ON public.vendor_statuses FOR SELECT USING (true);
CREATE POLICY select_order_statuses ON public.order_statuses FOR SELECT USING (true);
CREATE POLICY select_payment_methods ON public.payment_methods FOR SELECT USING (true);
CREATE POLICY select_payment_statuses ON public.payment_statuses FOR SELECT USING (true);
CREATE POLICY select_drone_statuses ON public.drone_statuses FOR SELECT USING (true);
CREATE POLICY select_delivery_statuses ON public.delivery_statuses FOR SELECT USING (true);
CREATE POLICY select_priority_levels ON public.priority_levels FOR SELECT USING (true);
CREATE POLICY select_safety_statuses ON public.safety_statuses FOR SELECT USING (true);
CREATE POLICY select_package_types ON public.package_types FOR SELECT USING (true);
CREATE POLICY select_telemetry_event_types ON public.telemetry_event_types FOR SELECT USING (true);
CREATE POLICY select_notification_types ON public.notification_types FOR SELECT USING (true);
CREATE POLICY select_notification_statuses ON public.notification_statuses FOR SELECT USING (true);
CREATE POLICY select_package_verification_statuses ON public.package_verification_statuses FOR SELECT USING (true);
CREATE POLICY select_weather_statuses ON public.weather_statuses FOR SELECT USING (true);
CREATE POLICY select_no_fly_zone_statuses ON public.no_fly_zone_statuses FOR SELECT USING (true);

-- 2. PUBLIC READ TABLES
CREATE POLICY select_campus_locations ON public.campus_locations FOR SELECT USING (true);
CREATE POLICY select_vendors ON public.vendors FOR SELECT USING (true);
CREATE POLICY select_products ON public.products FOR SELECT USING (true);
CREATE POLICY select_categories ON public.product_categories FOR SELECT USING (true);
CREATE POLICY select_weather_safety ON public.weather_safety FOR SELECT USING (true);
CREATE POLICY select_no_fly_zones ON public.no_fly_zones FOR SELECT USING (true);

-- 3. WRITE ONLY BY SERVICE ROLE OR ADMIN FOR LOOKUPS
-- (Postgres default permits superuser/service_role to bypass RLS, so no explicit admin policy required for service_role)

-- 4. USER SPECIFIC PROFILE & CREDENTIAL POLICIES
CREATE POLICY select_user_credentials ON public.user_credentials FOR SELECT USING (auth.uid() = user_id OR public.is_admin(auth.uid()));
CREATE POLICY select_user_profiles ON public.user_profiles FOR SELECT USING (true);
CREATE POLICY update_own_profile ON public.user_profiles FOR UPDATE USING (auth.uid() = user_id);

-- 5. ORDER POLICIES
CREATE POLICY select_own_orders ON public.orders FOR SELECT USING (auth.uid() = user_id OR public.is_admin(auth.uid()) OR EXISTS (
  SELECT 1 FROM public.vendors v WHERE v.user_id = auth.uid() AND v.id = orders.vendor_id
));
CREATE POLICY insert_own_orders ON public.orders FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 6. DELIVERY POLICIES
CREATE POLICY select_deliveries ON public.deliveries FOR SELECT USING (true);
CREATE POLICY insert_deliveries ON public.deliveries FOR INSERT WITH CHECK (auth.uid() = user_id OR public.is_admin(auth.uid()));
CREATE POLICY update_deliveries ON public.deliveries FOR UPDATE USING (auth.uid() = user_id OR public.is_admin(auth.uid()));
