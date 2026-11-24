// In-memory AeroDrop backend for the mobile integration tests.
//
// One shared store stands in for the Supabase tables, and the notifiers
// below read and write it with the same rules as the database functions the
// app calls (place_order, vendor_mark_order_ready, the order-status
// notification triggers, complete_delivery_order). A screen pumped for one
// account changes the store; the next screen, pumped for another account,
// reads the change.
import 'package:aerodrop/core/models/cart_model.dart';
import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/models/notification_model.dart';
import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/core/models/product_model.dart';
import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/providers/delivery_provider.dart';
import 'package:aerodrop/core/providers/notification_provider.dart';
import 'package:aerodrop/core/providers/order_provider.dart';
import 'package:aerodrop/core/providers/product_provider.dart';
import 'package:aerodrop/core/providers/vendor_provider.dart';
import 'package:aerodrop/core/providers/weather_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StoredOrder {
  StoredOrder(this.id, this.userId, this.vendorId, this.items, this.paymentMethod, this.subtotal, this.deliveryFee, this.createdAt);
  final String id, userId, vendorId, paymentMethod;
  final List<CartItem> items;
  final double subtotal, deliveryFee;
  final DateTime createdAt;
  String status = 'pending';
  String paymentStatus = 'paid';
  String? cancellationReason;
  double get total => subtotal + deliveryFee;
}

class StoredDelivery {
  StoredDelivery(this.id, this.orderId, this.droneId, this.createdAt);
  final String id, orderId;
  final String? droneId;
  final DateTime createdAt;
  String status = 'assigning';
  double progress = 0;
}

class Backend {
  final names = <String, String>{'maria': 'Maria Santos', 'kape': 'Kape Kanto', 'admin': 'AeroDrop Admin'};
  final products = <ProductModel>[
    _product('latte', 'Iced Spanish Latte', 120, 0.38, 24, 'Coffee'),
    _product('americano', 'Americano', 85, 0.35, 30, 'Coffee'),
    _product('croissant', 'Butter Croissant', 65, 0.09, 12, 'Pastry'),
  ];
  final orders = <StoredOrder>[];
  final deliveries = <StoredDelivery>[];
  final notifications = <String, List<NotificationModel>>{};
  String weather = 'safe';
  String droneStatus = 'available';
  int _seq = 0;

  String nextId(String p) => '${p}0000-0000-4000-a000-${(++_seq).toString().padLeft(12, '0')}';

  void notify(String userId, String title, String message, String type) {
    notifications.putIfAbsent(userId, () => []).insert(
      0,
      NotificationModel(id: nextId('n'), title: title, message: message, type: type, isRead: false, createdAt: DateTime.now().subtract(Duration(seconds: 60 - _seq))),
    );
  }

  /// place_order: stock is reserved, the vendor is told about the order.
  String placeOrder(String userId, List<CartItem> items, String paymentMethod, double deliveryFee) {
    if (weather == 'grounded') throw StateError('Ordering blocked: Campus drone delivery is currently grounded due to unsafe weather.');
    final id = nextId('o');
    for (final i in items) {
      final p = products.indexWhere((x) => x.id == i.productId);
      products[p] = _withStock(products[p], products[p].stock - i.quantity);
    }
    final subtotal = items.fold<double>(0, (s, i) => s + i.unitPrice * i.quantity);
    orders.insert(0, StoredOrder(id, userId, items.first.vendorId, List.of(items), paymentMethod, subtotal, deliveryFee, DateTime.now().subtract(const Duration(minutes: 1))));
    notify(items.first.vendorId, 'New Order Received', '${names[userId]} placed a new order.', 'new_order');
    return id;
  }

  /// The orders table update plus the order-status notification trigger.
  void setStatus(String orderId, String status, {String? reason}) {
    final o = orders.firstWhere((x) => x.id == orderId);
    o.status = status;
    if (status == 'confirmed') notify(o.userId, 'Order Confirmed', 'The vendor has accepted your order.', 'order_confirmed');
    if (status == 'preparing') notify(o.userId, 'Preparing Your Order', 'The vendor is preparing your order.', 'order_preparing');
    if (status == 'cancelled') {
      o.cancellationReason = reason;
      o.paymentStatus = 'refunded';
      notify(o.userId, 'Order Cancelled', 'The vendor could not accept your order. Your payment was refunded.', 'order_cancelled');
    }
  }

  /// vendor_mark_order_ready.
  ({bool success, bool droneDispatched, String message}) markReady(String vendorId, String orderId) {
    final o = orders.firstWhere((x) => x.id == orderId);
    if (o.vendorId != vendorId) return (success: false, droneDispatched: false, message: 'Unauthorized: Order belongs to another vendor');
    if (!{'confirmed', 'preparing', 'ready_for_delivery'}.contains(o.status)) {
      return (success: false, droneDispatched: false, message: 'Invalid order status: Must be confirmed, preparing, or ready_for_delivery');
    }
    if (weather == 'grounded') return (success: false, droneDispatched: false, message: 'Flight dispatch blocked: Weather is grounded');
    o.status = 'ready_for_delivery';
    final free = droneStatus == 'available';
    final d = StoredDelivery(nextId('d'), orderId, free ? 'drn1' : null, DateTime.now().subtract(const Duration(seconds: 30)));
    if (!free) d.status = 'pending';
    deliveries.insert(0, d);
    if (!free) return (success: true, droneDispatched: false, message: 'Drone currently unavailable. This order is ready and waiting for the next available drone.');
    droneStatus = 'assigned';
    notify(o.userId, 'Drone Dispatched to Vendor', 'DRN-001 is on its way to the vendor to pick up your order.', 'drone_dispatched');
    notify(vendorId, 'Drone Heading to Pickup', 'DRN-001 has been dispatched to pick up the package from your shop.', 'drone_dispatched');
    return (success: true, droneDispatched: true, message: 'Order is ready for delivery. Drone DRN-001 dispatched for pickup.');
  }

  /// confirm_package_pickup.
  void pickUp(String orderId) {
    final d = deliveries.firstWhere((x) => x.orderId == orderId);
    final o = orders.firstWhere((x) => x.id == orderId);
    d.status = 'in_transit';
    d.progress = 0.45;
    o.status = 'in_transit';
    droneStatus = 'busy';
    notify(o.userId, 'Package Picked Up', 'The drone has picked up your order and is on its way.', 'package_picked_up');
  }

  /// complete_delivery_order.
  void complete(String orderId) {
    final d = deliveries.firstWhere((x) => x.orderId == orderId);
    final o = orders.firstWhere((x) => x.id == orderId);
    d.status = 'delivered';
    d.progress = 1;
    o.status = 'delivered';
    droneStatus = 'returning';
    notify(o.userId, 'Order Delivered', 'Your package has arrived at UCLM Maritime Building.', 'order_delivered');
  }

  OrderModel model(StoredOrder o) {
    final d = deliveries.where((x) => x.orderId == o.id).firstOrNull;
    return OrderModel(
      id: o.id,
      userId: o.userId,
      vendorId: o.vendorId,
      vendorName: names[o.vendorId]!,
      customerName: names[o.userId]!,
      orderStatus: o.status,
      paymentStatus: o.paymentStatus,
      paymentMethod: o.paymentMethod,
      dropoffLocationId: 'maritime',
      dropoffLocationName: 'UCLM Maritime Building',
      subtotal: o.subtotal,
      deliveryFee: o.deliveryFee,
      totalAmount: o.total,
      createdAt: o.createdAt,
      items: [for (final i in o.items) OrderItemModel(productName: i.productName, quantity: i.quantity, unitPrice: i.unitPrice)],
      deliveryId: d?.id,
      deliveryStatus: d?.status,
      deliveryProgress: d?.progress,
      droneId: d?.droneId,
    );
  }

  DeliveryModel deliveryModel(StoredDelivery d) {
    final o = orders.firstWhere((x) => x.id == d.orderId);
    return DeliveryModel(
      id: d.id,
      orderId: o.id,
      senderName: names[o.vendorId]!,
      recipientName: names[o.userId]!,
      recipientPhone: '+639171234567',
      deliveryAddress: 'UCLM Maritime Building',
      dropoffLocationName: 'UCLM Maritime Building',
      pickupLocationName: 'UCLM Main Building',
      packageName: o.items.map((i) => '${i.productName} (x${i.quantity})').join(', '),
      packageWeight: o.items.fold<double>(0, (s, i) => s + i.weightKg * i.quantity),
      packageType: 'Food',
      status: DeliveryStatus.values.firstWhere((s) => s.name == {'in_transit': 'inTransit'}[d.status] || s.name == d.status),
      droneId: d.droneId,
      eta: 'TBD',
      createdAt: d.createdAt,
      progress: d.progress,
      orderStatus: o.status,
    );
  }
}

ProductModel _product(String id, String name, double price, double kg, int stock, String category) => ProductModel(
  id: id, vendorId: 'kape', vendorName: 'Kape Kanto', name: name, description: '', price: price, stock: stock, category: category, weightKg: kg, imageUrl: '', isAvailable: true,
);

ProductModel _withStock(ProductModel p, int stock) => ProductModel(
  id: p.id, vendorId: p.vendorId, vendorName: p.vendorName, name: p.name, description: p.description, price: p.price, stock: stock, category: p.category, weightKg: p.weightKg, imageUrl: p.imageUrl, isAvailable: p.isAvailable,
);

/// The store every test starts from; replaced in setUp.
Backend backend = Backend();

// ---------------------------------------------------------------- notifiers

class StoreAuth extends StateNotifier<AuthState> implements AuthNotifier {
  StoreAuth(String id, String role)
    : super(AuthState(
        user: AeroDropUser.fromMap({'id': id, 'email': '$id@uclm.edu.ph', 'full_name': backend.names[id], 'phone_number': '+639171234567', 'role': role, 'email_verified_at': '2026-10-08T08:00:00Z'}),
        isVerified: true,
        sessionUnlocked: true,
      ));
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<bool>.value(false);
}

class StoreCustomerOrders extends StateNotifier<OrderState> implements OrderNotifier {
  StoreCustomerOrders(this.userId) : super(OrderState(orders: const [])) {
    _load();
  }
  final String userId;
  void _load() => state = OrderState(orders: [for (final o in backend.orders.where((o) => o.userId == userId)) backend.model(o)]);

  @override
  Future<void> loadOrders() async => _load();

  @override
  Future<String?> placeOrder({
    required String vendorId,
    required String? dropoffLocationId,
    required double subtotal,
    required double deliveryFee,
    required double totalAmount,
    required String paymentMethod,
    required List<CartItem> items,
    String? notes,
    double? dropoffLat,
    double? dropoffLng,
    String? dropoffLabel,
  }) async {
    try {
      final id = backend.placeOrder(userId, items, paymentMethod, deliveryFee);
      _load();
      return id;
    } on StateError catch (e) {
      state = OrderState(orders: state.orders, errorMessage: e.message);
      return null;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class StoreVendorOrders extends StateNotifier<OrderState> implements VendorOrdersNotifier {
  StoreVendorOrders(this.vendorId) : super(OrderState(orders: const [])) {
    _load();
  }
  final String vendorId;
  void _load() => state = OrderState(orders: [for (final o in backend.orders.where((o) => o.vendorId == vendorId)) backend.model(o)]);

  @override
  Future<void> loadOrders() async => _load();

  @override
  Future<bool> updateOrderStatus(String orderId, String statusName, {String? cancellationReason}) async {
    backend.setStatus(orderId, statusName, reason: cancellationReason);
    _load();
    return true;
  }

  @override
  Future<({bool success, bool droneDispatched, String message})> markOrderReady(String orderId) async {
    final r = backend.markReady(vendorId, orderId);
    _load();
    return r;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class StoreNotifications extends NotificationNotifier {
  StoreNotifications(this.userId) {
    state = List.of(backend.notifications[userId] ?? const []);
  }
  final String userId;
  @override
  Future<void> loadNotifications() async => state = List.of(backend.notifications[userId] ?? const []);
  @override
  Future<void> markAllAsRead() async {}
}

class StoreProducts extends StateNotifier<ProductState> implements ProductNotifier {
  StoreProducts() : super(ProductState(products: List.of(backend.products), categories: const ['All', 'Coffee', 'Pastry']));
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class StoreVendors extends StateNotifier<VendorState> implements VendorNotifier {
  StoreVendors() : super(VendorState.empty());
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class StoreDeliveries extends StateNotifier<List<DeliveryModel>> implements DeliveryNotifier {
  StoreDeliveries() : super([for (final d in backend.deliveries) backend.deliveryModel(d)]);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class StoreWeather extends WeatherNotifier {
  StoreWeather() : super(_NoRef()) {
    state = _reading();
  }
  static WeatherState _reading() => WeatherState(
    id: 'w-1',
    safetyStatus: backend.weather,
    condition: 'Partly cloudy',
    temperature: 30.4,
    windSpeed: 9.2,
    windGusts: 16.8,
    realSafetyStatus: 'safe',
    realCondition: 'Partly cloudy',
    message: backend.weather == 'grounded' ? 'Campus drone delivery is currently grounded due to unsafe weather.' : null,
    lastFetchedAt: DateTime.now().subtract(const Duration(minutes: 7)),
  );
  @override
  Future<void> loadWeatherSafety({bool isSilent = false}) async {}
  @override
  Future<bool> setSimulatedWeather(String selectedStatus, {double durationHours = 2.0}) async {
    backend.weather = selectedStatus;
    state = _reading();
    return true;
  }
}

class _NoRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The provider overrides that connect a screen to the shared store as [who].
List<Override> session(String who) {
  final role = who == 'kape' ? 'vendor' : (who == 'admin' ? 'admin' : 'user');
  return [
    authProvider.overrideWith((ref) => StoreAuth(who, role)),
    orderProvider.overrideWith((ref) => StoreCustomerOrders(who)),
    vendorOrdersProvider.overrideWith((ref) => StoreVendorOrders(who)),
    notificationProvider.overrideWith((ref) => StoreNotifications(who)),
    productProvider.overrideWith((ref) => StoreProducts()),
    vendorProvider.overrideWith((ref) => StoreVendors()),
    deliveryProvider.overrideWith((ref) => StoreDeliveries()),
    weatherProvider.overrideWith((ref) => StoreWeather()),
  ];
}

/// Maria Santos orders [qty] x [productId] from Kape Kanto; returns the order id.
String customerOrders({String productId = 'latte', int qty = 1}) {
  final p = backend.products.firstWhere((x) => x.id == productId);
  return backend.placeOrder('maria', [
    CartItem(productId: p.id, productName: p.name, vendorId: 'kape', vendorName: 'Kape Kanto', imageUrl: '', unitPrice: p.price, weightKg: p.weightKg, quantity: qty),
  ], 'gcash_simulated', 27.19);
}

/// An order Kape Kanto has confirmed and is preparing.
String preparingOrder() {
  final id = customerOrders();
  backend.setStatus(id, 'confirmed');
  backend.setStatus(id, 'preparing');
  return id;
}
