class MockOrderItem {
  final String productId;
  final String productName;
  final String vendorName;
  final double unitPrice;
  final int quantity;
  final String imageUrl;

  const MockOrderItem({
    required this.productId,
    required this.productName,
    required this.vendorName,
    required this.unitPrice,
    required this.quantity,
    required this.imageUrl,
  });

  double get subtotal => unitPrice * quantity;
}

enum MockOrderStatus {
  pending,
  preparing,
  ready,
  pickedUp,
  delivered,
  cancelled,
}

enum MockPaymentStatus { pending, paid, failed, refunded }

enum MockPaymentMethod { gcash, cash, creditCard }

class MockOrder {
  final String id;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String vendorId;
  final String vendorName;
  final List<MockOrderItem> items;
  final MockOrderStatus status;
  final MockPaymentStatus paymentStatus;
  final MockPaymentMethod paymentMethod;
  final String dropOffLocation;
  final double totalAmount;
  final String referenceNumber;
  final DateTime createdAt;
  final String? cancelReason;

  const MockOrder({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.vendorId,
    required this.vendorName,
    required this.items,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.dropOffLocation,
    required this.totalAmount,
    required this.referenceNumber,
    required this.createdAt,
    this.cancelReason,
  });
}

final List<MockOrder> mockOrders = [
  MockOrder(
    id: 'ord-001',
    orderNumber: 'AD-20240706-001',
    customerId: 'u-001',
    customerName: 'Juan Dela Cruz',
    customerPhone: '09171234567',
    vendorId: 'v-001',
    vendorName: 'Campus Bites',
    items: const [
      MockOrderItem(
        productId: 'p-001', productName: 'Chicken Adobo Rice Meal',
        vendorName: 'Campus Bites', unitPrice: 75.00, quantity: 2,
        imageUrl: 'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=200',
      ),
      MockOrderItem(
        productId: 'p-002', productName: 'Iced Coffee',
        vendorName: 'Campus Bites', unitPrice: 45.00, quantity: 1,
        imageUrl: 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=200',
      ),
    ],
    status: MockOrderStatus.pending,
    paymentStatus: MockPaymentStatus.pending,
    paymentMethod: MockPaymentMethod.gcash,
    dropOffLocation: 'Old Building – Room 301',
    totalAmount: 195.00,
    referenceNumber: 'GC-2024070601',
    createdAt: DateTime(2024, 7, 6, 14, 30),
  ),
  MockOrder(
    id: 'ord-002',
    orderNumber: 'AD-20240706-002',
    customerId: 'u-001',
    customerName: 'Juan Dela Cruz',
    customerPhone: '09171234567',
    vendorId: 'v-002',
    vendorName: 'TechZone Supplies',
    items: const [
      MockOrderItem(
        productId: 'p-004', productName: 'USB-C Charging Cable',
        vendorName: 'TechZone Supplies', unitPrice: 180.00, quantity: 1,
        imageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=200',
      ),
    ],
    status: MockOrderStatus.preparing,
    paymentStatus: MockPaymentStatus.paid,
    paymentMethod: MockPaymentMethod.gcash,
    dropOffLocation: 'Annex 1 – Room 201',
    totalAmount: 180.00,
    referenceNumber: 'GC-2024070602',
    createdAt: DateTime(2024, 7, 6, 13, 15),
  ),
  MockOrder(
    id: 'ord-003',
    orderNumber: 'AD-20240706-003',
    customerId: 'u-001',
    customerName: 'Juan Dela Cruz',
    customerPhone: '09171234567',
    vendorId: 'v-003',
    vendorName: 'Book Nook',
    items: const [
      MockOrderItem(
        productId: 'p-007', productName: 'Engineering Math Reviewer',
        vendorName: 'Book Nook', unitPrice: 350.00, quantity: 1,
        imageUrl: 'https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=200',
      ),
      MockOrderItem(
        productId: 'p-008', productName: 'Spiral Notebook (200 leaves)',
        vendorName: 'Book Nook', unitPrice: 95.00, quantity: 2,
        imageUrl: 'https://images.unsplash.com/photo-1531346878377-a5be20888e57?w=200',
      ),
    ],
    status: MockOrderStatus.ready,
    paymentStatus: MockPaymentStatus.paid,
    paymentMethod: MockPaymentMethod.cash,
    dropOffLocation: 'Library – Study Hall',
    totalAmount: 540.00,
    referenceNumber: 'CASH-2024070601',
    createdAt: DateTime(2024, 7, 5, 10, 0),
  ),
  MockOrder(
    id: 'ord-004',
    orderNumber: 'AD-20240705-001',
    customerId: 'u-001',
    customerName: 'Juan Dela Cruz',
    customerPhone: '09171234567',
    vendorId: 'v-006',
    vendorName: 'Healthy Corner',
    items: const [
      MockOrderItem(
        productId: 'p-013', productName: 'Fresh Mango Shake',
        vendorName: 'Healthy Corner', unitPrice: 60.00, quantity: 2,
        imageUrl: 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=200',
      ),
      MockOrderItem(
        productId: 'p-015', productName: 'Granola Energy Bar',
        vendorName: 'Healthy Corner', unitPrice: 55.00, quantity: 3,
        imageUrl: 'https://images.unsplash.com/photo-1558024920-b41e1887dc32?w=200',
      ),
    ],
    status: MockOrderStatus.pickedUp,
    paymentStatus: MockPaymentStatus.paid,
    paymentMethod: MockPaymentMethod.gcash,
    dropOffLocation: 'Basic Ed – Room 105',
    totalAmount: 285.00,
    referenceNumber: 'GC-2024070501',
    createdAt: DateTime(2024, 7, 5, 9, 0),
  ),
  MockOrder(
    id: 'ord-005',
    orderNumber: 'AD-20240704-002',
    customerId: 'u-001',
    customerName: 'Juan Dela Cruz',
    customerPhone: '09171234567',
    vendorId: 'v-001',
    vendorName: 'Campus Bites',
    items: const [
      MockOrderItem(
        productId: 'p-003', productName: 'Pork Sinigang Set',
        vendorName: 'Campus Bites', unitPrice: 85.00, quantity: 1,
        imageUrl: 'https://images.unsplash.com/photo-1604909052743-94e838986d24?w=200',
      ),
    ],
    status: MockOrderStatus.delivered,
    paymentStatus: MockPaymentStatus.paid,
    paymentMethod: MockPaymentMethod.creditCard,
    dropOffLocation: 'Old Building – Room 205',
    totalAmount: 85.00,
    referenceNumber: 'CC-2024070401',
    createdAt: DateTime(2024, 7, 4, 12, 0),
  ),
  MockOrder(
    id: 'ord-006',
    orderNumber: 'AD-20240703-001',
    customerId: 'u-001',
    customerName: 'Juan Dela Cruz',
    customerPhone: '09171234567',
    vendorId: 'v-004',
    vendorName: 'Merienda Hub',
    items: const [
      MockOrderItem(
        productId: 'p-009', productName: 'Turon with Langka',
        vendorName: 'Merienda Hub', unitPrice: 30.00, quantity: 3,
        imageUrl: 'https://images.unsplash.com/photo-1546241072-48010ad2862c?w=200',
      ),
    ],
    status: MockOrderStatus.cancelled,
    paymentStatus: MockPaymentStatus.refunded,
    paymentMethod: MockPaymentMethod.gcash,
    dropOffLocation: 'Annex 2 – Canteen',
    totalAmount: 90.00,
    referenceNumber: 'GC-2024070301',
    createdAt: DateTime(2024, 7, 3, 15, 0),
    cancelReason: 'Vendor is currently closed.',
  ),
];

const List<String> campusDropOffLocations = [
  'Old Building – Lobby',
  'Old Building – Room 201',
  'Old Building – Room 301',
  'Annex 1 – Lobby',
  'Annex 1 – Room 102',
  'Annex 1 – Room 201',
  'Annex 2 – Lobby',
  'Annex 2 – Canteen',
  'Library – Study Hall',
  'Library – Ground Floor',
  'Basic Ed – Lobby',
  'Basic Ed – Room 105',
  'Maritime Building – Lobby',
  'Maritime Building – Deck Area',
];
