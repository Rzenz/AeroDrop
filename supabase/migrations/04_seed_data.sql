-- 04_seed_data.sql
-- Seeds product categories, default vendors, and products.

-- 1. SEED PRODUCT CATEGORIES
INSERT INTO public.product_categories (id, name) VALUES
  ('c1000000-0000-0000-0000-000000000001', 'Food'),
  ('c1000000-0000-0000-0000-000000000002', 'Drinks'),
  ('c1000000-0000-0000-0000-000000000003', 'Snacks'),
  ('c1000000-0000-0000-0000-000000000004', 'Electronics'),
  ('c1000000-0000-0000-0000-000000000005', 'Stationery'),
  ('c1000000-0000-0000-0000-000000000006', 'Books'),
  ('c1000000-0000-0000-0000-000000000007', 'Reviewers'),
  ('c1000000-0000-0000-0000-000000000008', 'Maritime Supplies'),
  ('c1000000-0000-0000-0000-000000000009', 'Equipment'),
  ('c1000000-0000-0000-0000-000000000010', 'Healthy Food'),
  ('c1000000-0000-0000-0000-000000000011', 'Juices'),
  ('c1000000-0000-0000-0000-000000000012', 'Organic')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 2. SEED DUMMY VENDOR USERS (so foreign key constraints are satisfied)
INSERT INTO public.users (id) VALUES
  ('70000000-0000-0000-0000-000000000001'),
  ('70000000-0000-0000-0000-000000000002'),
  ('70000000-0000-0000-0000-000000000003'),
  ('70000000-0000-0000-0000-000000000004'),
  ('70000000-0000-0000-0000-000000000005'),
  ('70000000-0000-0000-0000-000000000006')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_credentials (user_id, email, role_id, account_status) VALUES
  ('70000000-0000-0000-0000-000000000001', 'campusbites@gmail.com', 'b1b2a92e-3d14-41d1-817d-2b4a39b348d3', 'active'),
  ('70000000-0000-0000-0000-000000000002', 'techzone@gmail.com', 'b1b2a92e-3d14-41d1-817d-2b4a39b348d3', 'active'),
  ('70000000-0000-0000-0000-000000000003', 'booknook@gmail.com', 'b1b2a92e-3d14-41d1-817d-2b4a39b348d3', 'active'),
  ('70000000-0000-0000-0000-000000000004', 'meriendahub@gmail.com', 'b1b2a92e-3d14-41d1-817d-2b4a39b348d3', 'active'),
  ('70000000-0000-0000-0000-000000000005', 'maritimemart@gmail.com', 'b1b2a92e-3d14-41d1-817d-2b4a39b348d3', 'active'),
  ('70000000-0000-0000-0000-000000000006', 'healthycorner@gmail.com', 'b1b2a92e-3d14-41d1-817d-2b4a39b348d3', 'active')
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.user_profiles (user_id, full_name, phone_number) VALUES
  ('70000000-0000-0000-0000-000000000001', 'Maria Santos', '09171234567'),
  ('70000000-0000-0000-0000-000000000002', 'Jose Cruz', '09182345678'),
  ('70000000-0000-0000-0000-000000000003', 'Ana Reyes', '09193456789'),
  ('70000000-0000-0000-0000-000000000004', 'Carlo Dela Cruz', '09204567890'),
  ('70000000-0000-0000-0000-000000000005', 'Paolo Bautista', '09215678901'),
  ('70000000-0000-0000-0000-000000000006', 'Liza Gonzales', '09226789012')
ON CONFLICT (user_id) DO NOTHING;

-- 3. SEED VENDORS
INSERT INTO public.vendors (id, user_id, business_name, status_id, campus_location_id, logo_url, banner_url, description) VALUES
  ('v0000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', 'Campus Bites', 'e2a23b4e-5d9e-5b22-c1f2-23456789abcd', '10000000-0000-0000-0000-000000000001', 'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=100', 'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=400', 'Your go-to campus canteen for hot meals, snacks, and refreshments.'),
  ('v0000000-0000-0000-0000-000000000002', '70000000-0000-0000-0000-000000000002', 'TechZone Supplies', 'e2a23b4e-5d9e-5b22-c1f2-23456789abcd', '10000000-0000-0000-0000-000000000002', 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=100', 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400', 'Electronic accessories, stationery, and tech gadgets for students.'),
  ('v0000000-0000-0000-0000-000000000003', '70000000-0000-0000-0000-000000000003', 'Book Nook', 'e2a23b4e-5d9e-5b22-c1f2-23456789abcd', '10000000-0000-0000-0000-000000000003', 'https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=100', 'https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=400', 'Academic books, reviewers, and school supplies.'),
  ('v0000000-0000-0000-0000-000000000004', '70000000-0000-0000-0000-000000000004', 'Merienda Hub', 'e2a23b4e-5d9e-5b22-c1f2-23456789abcd', '10000000-0000-0000-0000-000000000003', 'https://images.unsplash.com/photo-1546241072-48010ad2862c?w=100', 'https://images.unsplash.com/photo-1546241072-48010ad2862c?w=400', 'Affordable merienda, rice meals, and cold beverages.'),
  ('v0000000-0000-0000-0000-000000000005', '70000000-0000-0000-0000-000000000005', 'Maritime Mart', 'e2a23b4e-5d9e-5b22-c1f2-23456789abcd', '10000000-0000-0000-0000-000000000005', 'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=100', 'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=400', 'Specialized supplies for maritime students: nautical instruments, safety equipment, and uniforms.'),
  ('v0000000-0000-0000-0000-000000000006', '70000000-0000-0000-0000-000000000006', 'Healthy Corner', 'e2a23b4e-5d9e-5b22-c1f2-23456789abcd', '10000000-0000-0000-0000-000000000004', 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=100', 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=400', 'Healthy food options including fresh juices, salads, and organic snacks.')
ON CONFLICT (id) DO UPDATE SET business_name = EXCLUDED.business_name, description = EXCLUDED.description;

-- 4. SEED PRODUCTS
INSERT INTO public.products (id, vendor_id, name, description, price, stock, category_id, weight_grams, image_url, is_available) VALUES
  ('p0000000-0000-0000-0000-000000000001', 'v0000000-0000-0000-0000-000000000001', 'Chicken Adobo Rice Meal', 'Classic Filipino chicken adobo served with steamed white rice.', 75.00, 30, 'c1000000-0000-0000-0000-000000000001', 400, 'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=400', true),
  ('p0000000-0000-0000-0000-000000000002', 'v0000000-0000-0000-0000-000000000001', 'Iced Coffee', 'Cold brewed coffee with milk and a hint of sugar.', 45.00, 50, 'c1000000-0000-0000-0000-000000000002', 350, 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400', true),
  ('p0000000-0000-0000-0000-000000000003', 'v0000000-0000-0000-0000-000000000001', 'Pork Sinigang Set', 'Sour tamarind-based pork soup with fresh vegetables.', 85.00, 20, 'c1000000-0000-0000-0000-000000000001', 500, 'https://images.unsplash.com/photo-1604909052743-94e838986d24?w=400', true),
  ('p0000000-0000-0000-0000-000000000004', 'v0000000-0000-0000-0000-000000000002', 'USB-C Charging Cable', 'Braided nylon USB-C cable with fast charging support.', 180.00, 45, 'c1000000-0000-0000-0000-000000000004', 80, 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400', true),
  ('p0000000-0000-0000-0000-000000000005', 'v0000000-0000-0000-0000-000000000002', 'Wireless Earphones', 'Bluetooth 5.0 earphones with 6-hour battery life.', 650.00, 15, 'c1000000-0000-0000-0000-000000000004', 60, 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=400', true),
  ('p0000000-0000-0000-0000-000000000006', 'v0000000-0000-0000-0000-000000000002', 'Ballpen Set (10pcs)', 'Smooth-writing ballpens in black and blue.', 65.00, 100, 'c1000000-0000-0000-0000-000000000005', 50, 'https://images.unsplash.com/photo-1589998059171-988d887df646?w=400', true),
  ('p0000000-0000-0000-0000-000000000007', 'v0000000-0000-0000-0000-000000000003', 'Engineering Math Reviewer', 'Comprehensive board exam reviewer for engineering students.', 350.00, 25, 'c1000000-0000-0000-0000-000000000007', 450, 'https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=400', true),
  ('p0000000-0000-0000-0000-000000000008', 'v0000000-0000-0000-0000-000000000003', 'Spiral Notebook (200 leaves)', 'College-ruled spiral notebook with perforated pages.', 95.00, 60, 'c1000000-0000-0000-0000-000000000005', 300, 'https://images.unsplash.com/photo-1531346878377-a5be20888e57?w=400', true),
  ('p0000000-0000-0000-0000-000000000009', 'v0000000-0000-0000-0000-000000000004', 'Turon with Langka', 'Crispy banana spring rolls with jackfruit filling.', 30.00, 40, 'c1000000-0000-0000-0000-000000000001', 150, 'https://images.unsplash.com/photo-1546241072-48010ad2862c?w=400', true),
  ('p0000000-0000-0000-0000-000000000010', 'v0000000-0000-0000-0000-000000000004', 'Buko Juice (Large)', 'Fresh young coconut juice served cold.', 40.00, 35, 'c1000000-0000-0000-0000-000000000002', 400, 'https://images.unsplash.com/photo-1599599810769-bcde5a160d32?w=400', true),
  ('p0000000-0000-0000-0000-000000000011', 'v0000000-0000-0000-0000-000000000005', 'Marine Navigation Chart', 'Official Philippine coastal navigation chart for maritime students.', 280.00, 12, 'c1000000-0000-0000-0000-000000000008', 200, 'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=400', true),
  ('p0000000-0000-0000-0000-000000000012', 'v0000000-0000-0000-0000-000000000005', 'Life Vest (Training)', 'Approved training life vest for maritime safety drills.', 850.00, 8, 'c1000000-0000-0000-0000-000000000009', 600, 'https://images.unsplash.com/photo-1566024349271-b2eb0f0a8e95?w=400', true),
  ('p0000000-0000-0000-0000-000000000013', 'v0000000-0000-0000-0000-000000000006', 'Fresh Mango Shake', 'Blended fresh Philippine mangoes with milk.', 60.00, 25, 'c1000000-0000-0000-0000-000000000011', 400, 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=400', true),
  ('p0000000-0000-0000-0000-000000000014', 'v0000000-0000-0000-0000-000000000006', 'Caesar Salad', 'Fresh romaine lettuce with Caesar dressing.', 120.00, 15, 'c1000000-0000-0000-0000-000000000010', 300, 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400', true),
  ('p0000000-0000-0000-0000-000000000015', 'v0000000-0000-0000-0000-000000000006', 'Granola Energy Bar', 'Oats, honey, and mixed nuts packed into a portable energy bar.', 55.00, 50, 'c1000000-0000-0000-0000-000000000012', 80, 'https://images.unsplash.com/photo-1558024920-b41e1887dc32?w=400', true)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, price = EXCLUDED.price, stock = EXCLUDED.stock;
