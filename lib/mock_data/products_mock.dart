class MockProduct {
  final String id;
  final String vendorId;
  final String vendorName;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String category;
  final double weightKg;
  final String imageUrl;
  final bool isAvailable;

  const MockProduct({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.category,
    required this.weightKg,
    required this.imageUrl,
    required this.isAvailable,
  });
}

final List<MockProduct> mockProducts = [
  // Campus Bites (v-001)
  MockProduct(
    id: 'p-001', vendorId: 'v-001', vendorName: 'Campus Bites',
    name: 'Chicken Adobo Rice Meal',
    description: 'Classic Filipino chicken adobo served with steamed white rice. Slow-cooked in soy sauce, vinegar, and garlic. Perfect for a filling lunch.',
    price: 75.00, stock: 30, category: 'Food',
    weightKg: 0.4,
    imageUrl: 'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=400',
    isAvailable: true,
  ),
  MockProduct(
    id: 'p-002', vendorId: 'v-001', vendorName: 'Campus Bites',
    name: 'Iced Coffee',
    description: 'Cold brewed coffee with milk and a hint of sugar. Refreshing and energizing. Available in regular and large sizes.',
    price: 45.00, stock: 50, category: 'Drinks',
    weightKg: 0.35,
    imageUrl: 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400',
    isAvailable: true,
  ),
  MockProduct(
    id: 'p-003', vendorId: 'v-001', vendorName: 'Campus Bites',
    name: 'Pork Sinigang Set',
    description: 'Sour tamarind-based pork soup with fresh vegetables. Served with rice. A warm, comforting Filipino classic.',
    price: 85.00, stock: 20, category: 'Food',
    weightKg: 0.5,
    imageUrl: 'https://images.unsplash.com/photo-1604909052743-94e838986d24?w=400',
    isAvailable: true,
  ),

  // TechZone Supplies (v-002)
  MockProduct(
    id: 'p-004', vendorId: 'v-002', vendorName: 'TechZone Supplies',
    name: 'USB-C Charging Cable',
    description: 'Braided nylon USB-C cable with fast charging support (up to 65W). 1.5m length. Compatible with most modern smartphones and laptops.',
    price: 180.00, stock: 45, category: 'Electronics',
    weightKg: 0.08,
    imageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400',
    isAvailable: true,
  ),
  MockProduct(
    id: 'p-005', vendorId: 'v-002', vendorName: 'TechZone Supplies',
    name: 'Wireless Earphones',
    description: 'Bluetooth 5.0 earphones with 6-hour battery life. Clear sound with passive noise isolation. Compact and lightweight for everyday use.',
    price: 650.00, stock: 15, category: 'Electronics',
    weightKg: 0.06,
    imageUrl: 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=400',
    isAvailable: true,
  ),
  MockProduct(
    id: 'p-006', vendorId: 'v-002', vendorName: 'TechZone Supplies',
    name: 'Ballpen Set (10pcs)',
    description: 'Smooth-writing ballpens in black and blue. Oil-based ink for clean, smear-resistant writing. Ideal for exams and note-taking.',
    price: 65.00, stock: 100, category: 'Stationery',
    weightKg: 0.05,
    imageUrl: 'https://images.unsplash.com/photo-1589998059171-988d887df646?w=400',
    isAvailable: true,
  ),

  // Book Nook (v-003)
  MockProduct(
    id: 'p-007', vendorId: 'v-003', vendorName: 'Book Nook',
    name: 'Engineering Math Reviewer',
    description: 'Comprehensive board exam reviewer for engineering students. Covers algebra, calculus, differential equations, and more. Over 500 practice problems.',
    price: 350.00, stock: 25, category: 'Reviewers',
    weightKg: 0.45,
    imageUrl: 'https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=400',
    isAvailable: true,
  ),
  MockProduct(
    id: 'p-008', vendorId: 'v-003', vendorName: 'Book Nook',
    name: 'Spiral Notebook (200 leaves)',
    description: 'College-ruled spiral notebook with perforated pages. Durable cover with water-resistant coating. Perfect for all subjects.',
    price: 95.00, stock: 60, category: 'Stationery',
    weightKg: 0.3,
    imageUrl: 'https://images.unsplash.com/photo-1531346878377-a5be20888e57?w=400',
    isAvailable: true,
  ),

  // Merienda Hub (v-004)
  MockProduct(
    id: 'p-009', vendorId: 'v-004', vendorName: 'Merienda Hub',
    name: 'Turon with Langka',
    description: 'Crispy banana spring rolls with jackfruit filling, deep-fried to golden perfection. A beloved Filipino merienda snack.',
    price: 30.00, stock: 40, category: 'Food',
    weightKg: 0.15,
    imageUrl: 'https://images.unsplash.com/photo-1546241072-48010ad2862c?w=400',
    isAvailable: false,
  ),
  MockProduct(
    id: 'p-010', vendorId: 'v-004', vendorName: 'Merienda Hub',
    name: 'Buko Juice (Large)',
    description: 'Fresh young coconut juice served cold with coconut strips inside. Naturally refreshing and hydrating.',
    price: 40.00, stock: 35, category: 'Drinks',
    weightKg: 0.4,
    imageUrl: 'https://images.unsplash.com/photo-1599599810769-bcde5a160d32?w=400',
    isAvailable: false,
  ),

  // Maritime Mart (v-005)
  MockProduct(
    id: 'p-011', vendorId: 'v-005', vendorName: 'Maritime Mart',
    name: 'Marine Navigation Chart',
    description: 'Official Philippine coastal navigation chart for maritime students. Required for navigation subjects. Covers major sea lanes and ports.',
    price: 280.00, stock: 12, category: 'Maritime Supplies',
    weightKg: 0.2,
    imageUrl: 'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=400',
    isAvailable: true,
  ),
  MockProduct(
    id: 'p-012', vendorId: 'v-005', vendorName: 'Maritime Mart',
    name: 'Life Vest (Training)',
    description: 'Approved training life vest for maritime safety drills. Meets MARINA specifications. Adjustable straps for all body sizes.',
    price: 850.00, stock: 8, category: 'Equipment',
    weightKg: 0.6,
    imageUrl: 'https://images.unsplash.com/photo-1566024349271-b2eb0f0a8e95?w=400',
    isAvailable: true,
  ),

  // Healthy Corner (v-006)
  MockProduct(
    id: 'p-013', vendorId: 'v-006', vendorName: 'Healthy Corner',
    name: 'Fresh Mango Shake',
    description: 'Blended fresh Philippine mangoes with milk and a touch of honey. No artificial flavoring. Rich in Vitamin C and antioxidants.',
    price: 60.00, stock: 25, category: 'Juices',
    weightKg: 0.4,
    imageUrl: 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=400',
    isAvailable: true,
  ),
  MockProduct(
    id: 'p-014', vendorId: 'v-006', vendorName: 'Healthy Corner',
    name: 'Caesar Salad',
    description: 'Fresh romaine lettuce with Caesar dressing, croutons, and Parmesan shavings. A light, nutritious meal option for health-conscious students.',
    price: 120.00, stock: 15, category: 'Healthy Food',
    weightKg: 0.3,
    imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400',
    isAvailable: true,
  ),
  MockProduct(
    id: 'p-015', vendorId: 'v-006', vendorName: 'Healthy Corner',
    name: 'Granola Energy Bar',
    description: 'Oats, honey, and mixed nuts packed into a portable energy bar. Great pre-exam snack. No artificial preservatives.',
    price: 55.00, stock: 50, category: 'Organic',
    weightKg: 0.08,
    imageUrl: 'https://images.unsplash.com/photo-1558024920-b41e1887dc32?w=400',
    isAvailable: true,
  ),
];

final List<String> productCategories = [
  'All', 'Food', 'Drinks', 'Snacks', 'Electronics', 'Stationery',
  'Books', 'Reviewers', 'Maritime Supplies', 'Equipment', 'Healthy Food',
  'Juices', 'Organic', 'Accessories', 'Uniforms',
];
