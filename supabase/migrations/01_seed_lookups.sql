-- 01_seed_lookups.sql
-- Seeds all lookup tables, status codes, default drone, and campus locations.

-- 1. USER ROLES
INSERT INTO public.user_roles (role_id, role_name) VALUES
  ('d3b07384-d113-4956-a5db-e1c300c8f5bb', 'student'),
  ('c2c191a3-2c1b-4d7a-8f1b-252ea93ad805', 'faculty_staff'),
  ('b1b2a92e-3d14-41d1-817d-2b4a39b348d3', 'vendor'),
  ('a0a1a82f-4d15-41e1-827d-2b4a39b348d4', 'admin')
ON CONFLICT (role_id) DO UPDATE SET role_name = EXCLUDED.role_name;

-- 2. VENDOR STATUSES
INSERT INTO public.vendor_statuses (id, name) VALUES
  ('e1a12a3d-4c8d-4a11-b0e1-123456789abc', 'pending'),
  ('e2a23b4e-5d9e-5b22-c1f2-23456789abcd', 'active'),
  ('e3a34c5f-6e0f-6c33-d2a3-3456789abcde', 'suspended'),
  ('e4a45d6a-7f1a-7d44-e3b4-456789abcdef', 'rejected')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 3. ORDER STATUSES
INSERT INTO public.order_statuses (id, name) VALUES
  ('f1b12a3d-4c8d-4a11-b0e1-123456789abc', 'pending'),
  ('f2b23b4e-5d9e-5b22-c1f2-23456789abcd', 'confirmed'),
  ('f3b34c5f-6e0f-6c33-d2a3-3456789abcde', 'preparing'),
  ('f4b45d6a-7f1a-7d44-e3b4-456789abcdef', 'ready_for_delivery'),
  ('f5b56e7b-8a2b-8e55-f4c5-56789abcdef0', 'out_for_delivery'),
  ('f6b67f8c-9b3c-9f66-05d6-6789abcdef01', 'delivered'),
  ('f7b78a9d-0c4d-0a77-16e7-789abcdef012', 'cancelled'),
  ('f8b89b0e-1d5e-1b88-27f8-89abcdef0123', 'rejected')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 4. PAYMENT METHODS
INSERT INTO public.payment_methods (id, name) VALUES
  ('11c12a3d-4c8d-4a11-b0e1-123456789abc', 'cash_on_delivery'),
  ('12c23b4e-5d9e-5b22-c1f2-23456789abcd', 'gcash_simulated')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 5. PAYMENT STATUSES
INSERT INTO public.payment_statuses (id, name) VALUES
  ('21d12a3d-4c8d-4a11-b0e1-123456789abc', 'pending'),
  ('22d23b4e-5d9e-5b22-c1f2-23456789abcd', 'paid'),
  ('23d34c5f-6e0f-6c33-d2a3-3456789abcde', 'failed'),
  ('24d45d6a-7f1a-7d44-e3b4-456789abcdef', 'refunded')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 6. DRONE STATUSES
INSERT INTO public.drone_statuses (id, name) VALUES
  ('31e12a3d-4c8d-4a11-b0e1-123456789abc', 'available'),
  ('32e23b4e-5d9e-5b22-c1f2-23456789abcd', 'assigned'),
  ('33e34c5f-6e0f-6c33-d2a3-3456789abcde', 'busy'),
  ('34e45d6a-7f1a-7d44-e3b4-456789abcdef', 'charging'),
  ('35e56e7b-8a2b-8e55-f4c5-56789abcdef0', 'maintenance'),
  ('36e67f8c-9b3c-9f66-05d6-6789abcdef01', 'offline')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 7. DELIVERY STATUSES
INSERT INTO public.delivery_statuses (id, name) VALUES
  ('41f12a3d-4c8d-4a11-b0e1-123456789abc', 'pending'),
  ('42f23b4e-5d9e-5b22-c1f2-23456789abcd', 'assigning'),
  ('43f34c5f-6e0f-6c33-d2a3-3456789abcde', 'in_transit'),
  ('44f45d6a-7f1a-7d44-e3b4-456789abcdef', 'delivered'),
  ('45f56e7b-8a2b-8e55-f4c5-56789abcdef0', 'cancelled'),
  ('46f67f8c-9b3c-9f66-05d6-6789abcdef01', 'rejected')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 8. PRIORITY LEVELS
INSERT INTO public.priority_levels (id, name) VALUES
  ('51a12a3d-4c8d-4a11-b0e1-123456789abc', 'standard'),
  ('52a23b4e-5d9e-5b22-c1f2-23456789abcd', 'express'),
  ('53a34c5f-6e0f-6c33-d2a3-3456789abcde', 'scheduled')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 9. SAFETY STATUSES
INSERT INTO public.safety_statuses (id, name) VALUES
  ('61b12a3d-4c8d-4a11-b0e1-123456789abc', 'safe'),
  ('62b23b4e-5d9e-5b22-c1f2-23456789abcd', 'caution'),
  ('63b34c5f-6e0f-6c33-d2a3-3456789abcde', 'grounded'),
  ('64b45d6a-7f1a-7d44-e3b4-456789abcdef', 'aborted')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 10. PACKAGE TYPES
INSERT INTO public.package_types (id, name) VALUES
  ('71c12a3d-4c8d-4a11-b0e1-123456789abc', 'documents'),
  ('72c23b4e-5d9e-5b22-c1f2-23456789abcd', 'medicine'),
  ('73c34c5f-6e0f-6c33-d2a3-3456789abcde', 'food'),
  ('74c45d6a-7f1a-7d44-e3b4-456789abcdef', 'electronics'),
  ('75c56e7b-8a2b-8e55-f4c5-56789abcdef0', 'other')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 11. TELEMETRY EVENT TYPES
INSERT INTO public.telemetry_event_types (id, name) VALUES
  ('81d12a3d-4c8d-4a11-b0e1-123456789abc', 'docked'),
  ('82d23b4e-5d9e-5b22-c1f2-23456789abcd', 'assigned'),
  ('83d34c5f-6e0f-6c33-d2a3-3456789abcde', 'takeoff'),
  ('84d45d6a-7f1a-7d44-e3b4-456789abcdef', 'in_flight'),
  ('85d56e7b-8a2b-8e55-f4c5-56789abcdef0', 'arrived'),
  ('86d67f8c-9b3c-9f66-05d6-6789abcdef01', 'landed'),
  ('87d78a9d-0c4d-0a77-16e7-789abcdef012', 'charging')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 12. NOTIFICATION TYPES
INSERT INTO public.notification_types (id, name) VALUES
  ('91e12a3d-4c8d-4a11-b0e1-123456789abc', 'order'),
  ('92e23b4e-5d9e-5b22-c1f2-23456789abcd', 'payment'),
  ('93e34c5f-6e0f-6c33-d2a3-3456789abcde', 'vendor'),
  ('94e45d6a-7f1a-7d44-e3b4-456789abcdef', 'delivery'),
  ('95e56e7b-8a2b-8e55-f4c5-56789abcdef0', 'account'),
  ('96e67f8c-9b3c-9f66-05d6-6789abcdef01', 'weather'),
  ('97e78a9d-0c4d-0a77-16e7-789abcdef012', 'system')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 13. NOTIFICATION STATUSES
INSERT INTO public.notification_statuses (id, name) VALUES
  ('a1f12a3d-4c8d-4a11-b0e1-123456789abc', 'unread'),
  ('a2f23b4e-5d9e-5b22-c1f2-23456789abcd', 'read')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 14. PACKAGE VERIFICATION STATUSES
INSERT INTO public.package_verification_statuses (id, name) VALUES
  ('b1f12a3d-4c8d-4a11-b0e1-123456789abc', 'pending'),
  ('b2f23b4e-5d9e-5b22-c1f2-23456789abcd', 'verified'),
  ('b3f34c5f-6e0f-6c33-d2a3-3456789abcde', 'rejected')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 15. WEATHER STATUSES
INSERT INTO public.weather_statuses (id, name) VALUES
  ('c1f12a3d-4c8d-4a11-b0e1-123456789abc', 'safe'),
  ('c2f23b4e-5d9e-5b22-c1f2-23456789abcd', 'caution'),
  ('c3f34c5f-6e0f-6c33-d2a3-3456789abcde', 'grounded')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 16. NO-FLY ZONE STATUSES
INSERT INTO public.no_fly_zone_statuses (id, name) VALUES
  ('d1f12a3d-4c8d-4a11-b0e1-123456789abc', 'active'),
  ('d2f23b4e-5d9e-5b22-c1f2-23456789abcd', 'inactive')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;


-- 17. SEED DEFAULT CAMPUS LOCATIONS
-- Let's check campus_locations table columns. 
-- In our test, campus_locations has [id, name, latitude, longitude, created_at, updated_at].
-- Note: It does not have campus_location_types linked by column, so we just seed the 5 standard locations.
INSERT INTO public.campus_locations (id, name, latitude, longitude) VALUES
  ('10000000-0000-0000-0000-000000000001', 'Old Building', 10.3156, 123.9016),
  ('10000000-0000-0000-0000-000000000002', 'Annex 1 Building', 10.3159, 123.9019),
  ('10000000-0000-0000-0000-000000000003', 'Annex 2 Building', 10.3154, 123.9021),
  ('10000000-0000-0000-0000-000000000004', 'Basic Education Building', 10.3148, 123.9014),
  ('10000000-0000-0000-0000-000000000005', 'Maritime Building', 10.3163, 123.9025)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, latitude = EXCLUDED.latitude, longitude = EXCLUDED.longitude;

-- 18. SEED DEFAULT WEATHER SAFETY
-- In our test, weather_safety has [id, weather_status_id, dispatch_enabled, advisory_message, delay_minutes, updated_at].
INSERT INTO public.weather_safety (id, weather_status_id, dispatch_enabled, advisory_message, delay_minutes) VALUES
  ('90000000-0000-0000-0000-000000000001', 'c1f12a3d-4c8d-4a11-b0e1-123456789abc', true, 'Clear skies. Conditions are optimal for drone operations.', 0)
ON CONFLICT (id) DO UPDATE SET weather_status_id = EXCLUDED.weather_status_id, dispatch_enabled = EXCLUDED.dispatch_enabled, advisory_message = EXCLUDED.advisory_message, delay_minutes = EXCLUDED.delay_minutes;

-- 19. SEED PROTOTYPE DRONE
-- In our test, drones has [id, drone_code, name, model_type, max_payload, battery_level, status_id, created_at, updated_at].
INSERT INTO public.drones (id, drone_code, name, model_type, max_payload, battery_level, status_id) VALUES
  ('80000000-0000-0000-0000-000000000001', 'DRN-001', 'AeroCarrier Alpha', 'Prototype 001', 0.5, 100.0, '31e12a3d-4c8d-4a11-b0e1-123456789abc')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, model_type = EXCLUDED.model_type, max_payload = EXCLUDED.max_payload, battery_level = EXCLUDED.battery_level, status_id = EXCLUDED.status_id;
