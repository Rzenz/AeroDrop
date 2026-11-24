// Stand-ins for the app's data sources, so screens can be tested without the
// live database. Each one holds fixed sample data; the screens only read it.
import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/models/drone_model.dart';
import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/core/models/product_model.dart';
import 'package:aerodrop/core/models/telemetry_model.dart';
import 'package:aerodrop/core/providers/delivery_provider.dart';
import 'package:aerodrop/core/providers/drone_provider.dart';
import 'package:aerodrop/core/providers/order_provider.dart';
import 'package:aerodrop/core/providers/product_provider.dart';
import 'package:aerodrop/core/providers/settings_provider.dart';
import 'package:aerodrop/core/providers/telemetry_provider.dart';
import 'package:aerodrop/core/providers/vendor_provider.dart';
import 'package:aerodrop/core/providers/weather_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FakeCustomerOrders extends StateNotifier<OrderState> implements OrderNotifier {
  FakeCustomerOrders(List<OrderModel> orders) : super(OrderState(orders: orders));
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class FakeVendorOrders extends StateNotifier<OrderState> implements VendorOrdersNotifier {
  FakeVendorOrders(List<OrderModel> orders) : super(OrderState(orders: orders));
  final updates = <String>[];
  @override
  Future<bool> updateOrderStatus(String orderId, String statusName, {String? cancellationReason}) async {
    updates.add('$orderId:$statusName');
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class FakeVendors extends StateNotifier<VendorState> implements VendorNotifier {
  FakeVendors(List<VendorViewModel> vendors) : super(VendorState(vendors: vendors));
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class FakeProducts extends StateNotifier<ProductState> implements ProductNotifier {
  FakeProducts(List<ProductModel> products) : super(ProductState(products: products, categories: const ['All']));
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class FakeVendorProducts extends StateNotifier<ProductState> implements VendorProductsNotifier {
  FakeVendorProducts(List<ProductModel> products) : super(ProductState(products: products, categories: const ['All', 'Coffee', 'Pastry']));
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class FakeDeliveries extends StateNotifier<List<DeliveryModel>> implements DeliveryNotifier {
  FakeDeliveries(super.deliveries);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class FakeDrones extends StateNotifier<List<DroneModel>> implements DroneNotifier {
  FakeDrones(super.drones);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class FakeFleetTelemetry extends StateNotifier<TelemetryModel?> implements FleetTelemetryNotifier {
  FakeFleetTelemetry() : super(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class FakeDeliveryTelemetry extends StateNotifier<TelemetryModel?> implements DeliveryTelemetryNotifier {
  FakeDeliveryTelemetry() : super(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class FakeLowBattery extends StateNotifier<bool> implements LowBatteryAlertNotifier {
  FakeLowBattery() : super(true);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class FakeWeather extends WeatherNotifier {
  FakeWeather(WeatherState weather) : super(_NoRef()) {
    state = weather;
  }
  @override
  Future<void> loadWeatherSafety({bool isSilent = false}) async {}
}

class _NoRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The campus weather reading used across the cases: safe, partly cloudy.
WeatherState safeWeather() => WeatherState(
  id: 'w-1',
  safetyStatus: 'safe',
  condition: 'Partly cloudy',
  temperature: 30.4,
  windSpeed: 9.2,
  windGusts: 16.8,
  realSafetyStatus: 'safe',
  realCondition: 'Partly cloudy',
  lastFetchedAt: DateTime.now().subtract(const Duration(minutes: 7)),
);

ProductModel product(String id, String name, double price, double kg, int stock, String category, {String vendorId = 'kape', String vendorName = 'Kape Kanto'}) => ProductModel(
  id: id,
  vendorId: vendorId,
  vendorName: vendorName,
  name: name,
  description: '',
  price: price,
  stock: stock,
  category: category,
  weightKg: kg,
  imageUrl: '',
  isAvailable: true,
);

OrderModel order(String id, String status, String vendor, double total, {String customer = 'Maria Santos', DateTime? at, List<OrderItemModel> items = const []}) => OrderModel(
  id: id,
  userId: 'maria',
  vendorId: 'kape',
  vendorName: vendor,
  customerName: customer,
  orderStatus: status,
  paymentStatus: 'paid',
  paymentMethod: 'gcash_simulated',
  dropoffLocationId: 'maritime',
  dropoffLocationName: 'UCLM Maritime Building',
  totalAmount: total,
  createdAt: at ?? DateTime.now().subtract(const Duration(hours: 1)),
  items: items,
);

DeliveryModel delivery(String id, DeliveryStatus status, {String sender = 'Kape Kanto', String package = 'Iced Spanish Latte (x1)', double progress = 0.45}) => DeliveryModel(
  id: id,
  senderName: sender,
  recipientName: 'Maria Santos',
  recipientPhone: '+639171234567',
  deliveryAddress: 'UCLM Maritime Building',
  dropoffLocationName: 'UCLM Maritime Building',
  packageName: package,
  packageWeight: 0.38,
  packageType: 'Food',
  status: status,
  eta: 'TBD',
  createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
  progress: progress,
);
