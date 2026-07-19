class OrderItemModel {
  final String productName;
  final int quantity;
  final double unitPrice;

  OrderItemModel({
    required this.productName,
    required this.quantity,
    this.unitPrice = 0,
  });
}

class OrderModel {
  final String id;
  final String userId;
  final String vendorId;
  final String vendorName;
  final String customerName;
  final String customerPhone;
  final String orderStatus; // plain text: pending, confirmed, preparing, …
  final String dropoffLocationId;
  final String? dropoffLocationName;
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final String paymentMethod; // plain text: cash, gcash_simulated, …
  final String paymentStatus; // plain text: pending, paid, …
  final String? paymentReference;
  final String? notes;
  final DateTime createdAt;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.userId,
    required this.vendorId,
    this.vendorName = 'Unknown Vendor',
    this.customerName = 'Me',
    this.customerPhone = '',
    required this.orderStatus,
    required this.dropoffLocationId,
    this.dropoffLocationName,
    this.subtotal = 0,
    this.deliveryFee = 0,
    required this.totalAmount,
    this.paymentMethod = 'cash',
    this.paymentStatus = 'pending',
    this.paymentReference,
    this.notes,
    required this.createdAt,
    required this.items,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final itemsList =
        (map['order_items'] as List?)
            ?.map(
              (i) => OrderItemModel(
                productName: i['product_name']?.toString() ?? 'Item',
                quantity: (i['quantity'] as num?)?.toInt() ?? 1,
                unitPrice: (i['unit_price'] as num?)?.toDouble() ?? 0.0,
              ),
            )
            .toList() ??
        [];

    // Vendor name: join from users(full_name, business_name) or fallback
    final vendorMap =
        map['vendor'] as Map<String, dynamic>? ??
        map['users'] as Map<String, dynamic>?;
    final vendorName =
        vendorMap?['business_name']?.toString() ??
        vendorMap?['full_name']?.toString() ??
        'Unknown Vendor';

    // Customer name & phone
    final customerMap = map['customer'] as Map<String, dynamic>?;
    final customerName = customerMap?['full_name']?.toString() ?? 'Me';
    final customerPhone = customerMap?['phone_number']?.toString() ?? '';

    // Location: join from campus_locations or inline name
    final locMap = map['campus_locations'] as Map<String, dynamic>?;
    final locName = locMap?['name']?.toString();

    return OrderModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      vendorId: map['vendor_id']?.toString() ?? '',
      vendorName: vendorName,
      customerName: customerName,
      customerPhone: customerPhone,
      orderStatus: map['order_status']?.toString() ?? 'pending',
      dropoffLocationId: map['delivery_location_id']?.toString() ?? '',
      dropoffLocationName: locName,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['payment_method']?.toString() ?? 'cash',
      paymentStatus: map['payment_status']?.toString() ?? 'pending',
      paymentReference: map['payment_reference']?.toString(),
      notes: map['notes']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
      items: itemsList,
    );
  }
}
