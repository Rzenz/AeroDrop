class OrderItemModel {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  OrderItemModel({
    this.productId = '',
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
  final String orderStatus; // raw order_status in orders table
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

  // Delivery-related fields joined from public.deliveries
  final String? deliveryId;
  final String? deliveryStatus;
  final double? deliveryProgress;
  final String? droneId;
  final int? estimatedDeliverySeconds;
  final DateTime? deliveryStartedAt;
  final DateTime? deliveryCompletedAt;

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
    this.deliveryId,
    this.deliveryStatus,
    this.deliveryProgress,
    this.droneId,
    this.estimatedDeliverySeconds,
    this.deliveryStartedAt,
    this.deliveryCompletedAt,
  });

  /// Authoritative effective status derived from database order & delivery state.
  /// Unifies orders.order_status and deliveries.status so the UI consistently
  /// transitions: pending -> confirmed -> preparing -> ready_for_delivery -> in_transit -> delivered.
  String get effectiveStatus {
    final oStatus = orderStatus.trim().toLowerCase();
    final dStatus = deliveryStatus?.trim().toLowerCase();

    // 1. Cancellation / Rejection always takes precedence
    if (oStatus == 'cancelled' ||
        oStatus == 'rejected' ||
        oStatus == 'failed' ||
        dStatus == 'cancelled' ||
        dStatus == 'rejected') {
      return oStatus.isEmpty ? 'cancelled' : oStatus;
    }

    // 2. Delivered state
    if (oStatus == 'delivered' || dStatus == 'delivered') return 'delivered';

    // 3. Pre-dispatch vendor states: pending, confirmed, preparing.
    // An order in these states MUST NEVER be marked in_transit, because it is still
    // being processed/prepared by the vendor.
    if (oStatus == 'pending') return 'pending';
    if (oStatus == 'confirmed') return 'confirmed';
    if (oStatus == 'preparing') return 'preparing';

    // 4. Pickup phase: drone is assigned/traveling to vendor for pickup.
    // The package is still at the vendor. The order MUST remain in ready_for_delivery!
    if (dStatus == 'assigning' ||
        (dStatus != 'in_transit' &&
            dStatus != 'intransit' &&
            (oStatus == 'ready_for_delivery' ||
                oStatus == 'ready' ||
                oStatus == 'ready_for_pickup'))) {
      return 'ready_for_delivery';
    }

    // 5. In Transit state: only when package pickup has occurred AND delivery is in transit
    if (dStatus == 'in_transit' ||
        dStatus == 'intransit' ||
        oStatus == 'out_for_delivery' ||
        oStatus == 'in_transit' ||
        oStatus == 'picked_up') {
      // Check if simulated delivery duration has elapsed based on timestamps
      if (deliveryStartedAt != null &&
          estimatedDeliverySeconds != null &&
          estimatedDeliverySeconds! > 0) {
        final elapsedSecs = DateTime.now()
            .difference(deliveryStartedAt!)
            .inSeconds;
        if (elapsedSecs >= estimatedDeliverySeconds!) {
          return 'delivered';
        }
      }
      return 'in_transit';
    }

    return oStatus.isEmpty ? 'pending' : oStatus;
  }

  /// User-friendly label corresponding to effectiveStatus
  String get statusDisplay {
    return switch (effectiveStatus) {
      'pending' => 'Pending',
      'confirmed' => 'Confirmed',
      'preparing' => 'Preparing',
      'ready_for_delivery' => 'Ready for Delivery',
      'in_transit' => 'In Transit',
      'delivered' => 'Delivered',
      'cancelled' => 'Cancelled',
      'rejected' => 'Rejected',
      'failed' => 'Failed',
      _ =>
        effectiveStatus.isEmpty
            ? 'Pending'
            : effectiveStatus[0].toUpperCase() + effectiveStatus.substring(1),
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final itemsList =
        (map['order_items'] as List?)
            ?.map(
              (i) => OrderItemModel(
                productId: i['product_id']?.toString() ?? '',
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

    // Delivery join: can be a list or single map
    Map<String, dynamic>? deliveryMap;
    final deliveriesRaw = map['deliveries'];
    if (deliveriesRaw is List && deliveriesRaw.isNotEmpty) {
      final list = List<Map<String, dynamic>>.from(
        deliveriesRaw.whereType<Map<String, dynamic>>(),
      );
      if (list.isNotEmpty) {
        list.sort((a, b) {
          final aDate = a['created_at'] != null
              ? DateTime.tryParse(a['created_at'].toString()) ??
                  DateTime.fromMillisecondsSinceEpoch(0)
              : DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b['created_at'] != null
              ? DateTime.tryParse(b['created_at'].toString()) ??
                  DateTime.fromMillisecondsSinceEpoch(0)
              : DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        deliveryMap = list.first;
      }
    } else if (deliveriesRaw is Map<String, dynamic>) {
      deliveryMap = deliveriesRaw;
    }

    final deliveryId = deliveryMap?['id']?.toString();
    final deliveryStatus = deliveryMap?['status']?.toString();
    final rawProgress = (deliveryMap?['progress'] as num?)?.toDouble();
    final double? deliveryProgress =
        (deliveryStatus?.toLowerCase() == 'delivered')
            ? 1.0
            : rawProgress?.clamp(0.0, 1.0);
    final droneId = deliveryMap?['drone_id']?.toString();
    final estimatedDeliverySeconds =
        (deliveryMap?['estimated_delivery_seconds'] as num?)?.toInt();
    final deliveryStartedAt = deliveryMap?['delivery_started_at'] != null
        ? DateTime.tryParse(deliveryMap!['delivery_started_at'].toString())
        : null;
    final deliveryCompletedAt = deliveryMap?['delivery_completed_at'] != null
        ? DateTime.tryParse(deliveryMap!['delivery_completed_at'].toString())
        : null;

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
      deliveryId: deliveryId,
      deliveryStatus: deliveryStatus,
      deliveryProgress: deliveryProgress,
      droneId: droneId,
      estimatedDeliverySeconds: estimatedDeliverySeconds,
      deliveryStartedAt: deliveryStartedAt,
      deliveryCompletedAt: deliveryCompletedAt,
    );
  }
}
