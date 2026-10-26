import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/models/drone_model.dart';
import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/core/models/telemetry_model.dart';
import 'package:aerodrop/core/providers/delivery_provider.dart';
import 'package:aerodrop/core/providers/drone_provider.dart';
import 'package:aerodrop/core/providers/notification_provider.dart';
import 'package:aerodrop/core/providers/order_provider.dart';
import 'package:aerodrop/core/providers/product_provider.dart';
import 'package:aerodrop/core/providers/settings_provider.dart';
import 'package:aerodrop/core/providers/telemetry_provider.dart';
import 'package:aerodrop/core/providers/weather_provider.dart';
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/features/admin/admin_dashboard_screen.dart';
import 'package:aerodrop/features/vendor/vendor_dashboard_screen.dart';

// Long, user-supplied strings are the realistic overflow trigger.
const _long = 'Extraordinarily Long Name That Should Ellipsize Cleanly Everywhere';

// The real notifiers reach for the Supabase client as they are built, which
// tests do not initialise; these stand in for them with fixed data. Their
// only other members the screens call are loaders, hence the empty Future.
class _Orders extends StateNotifier<OrderState>
    implements VendorOrdersNotifier {
  _Orders(List<OrderModel> orders) : super(OrderState(orders: orders));
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _Products extends StateNotifier<ProductState>
    implements VendorProductsNotifier {
  _Products() : super(ProductState(products: const [], categories: const ['All']));
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _Deliveries extends StateNotifier<List<DeliveryModel>>
    implements DeliveryNotifier {
  _Deliveries(super.deliveries);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _Drones extends StateNotifier<List<DroneModel>> implements DroneNotifier {
  _Drones(super.drones);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _FleetTelemetry extends StateNotifier<TelemetryModel?>
    implements FleetTelemetryNotifier {
  _FleetTelemetry() : super(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _DeliveryTelemetry extends StateNotifier<TelemetryModel?>
    implements DeliveryTelemetryNotifier {
  _DeliveryTelemetry() : super(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _LowBattery extends StateNotifier<bool>
    implements LowBatteryAlertNotifier {
  _LowBattery() : super(true);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _Weather extends WeatherNotifier {
  _Weather() : super(_DummyRef()) {
    state = WeatherState(
      id: 'w-1',
      safetyStatus: 'safe',
      condition: 'Clear',
      temperature: 30.0,
      windSpeed: 8.0,
      lastFetchedAt: DateTime.now(),
    );
  }

  @override
  Future<void> loadWeatherSafety({bool isSilent = false}) async {}
}

class _DummyRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

OrderModel _order(String id, String status) => OrderModel(
  id: '0000000$id-0000-0000-0000-000000000000',
  userId: 'u0000000-0000-0000-0000-000000000000',
  vendorId: 'v1',
  customerName: _long,
  orderStatus: status,
  dropoffLocationId: 'l1',
  totalAmount: 123456.78,
  createdAt: DateTime(2026, 10, 26),
  items: const [],
);

DeliveryModel _delivery(String id, DeliveryStatus status) => DeliveryModel(
  id: '0000000$id-0000-0000-0000-000000000000',
  senderName: _long,
  recipientName: _long,
  recipientPhone: '',
  deliveryAddress: _long,
  packageName: _long,
  packageWeight: 0.4,
  packageType: 'Food',
  status: status,
  eta: 'TBD',
  createdAt: DateTime(2026, 10, 26),
  progress: 0,
);

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required Size size,
  required List<Override> overrides,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  AppTheme.isDarkMode = true;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        weatherProvider.overrideWith((ref) => _Weather()),
        unreadNotificationCountProvider.overrideWithValue(0),
        ...overrides,
      ],
      child: MaterialApp(theme: AppTheme.darkTheme, home: screen),
    ),
  );
  await tester.pump(const Duration(milliseconds: 800));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  const sizes = {'360dp': Size(360, 740), 'desktop': Size(1366, 768)};

  for (final entry in sizes.entries) {
    final size = entry.value;

    group('vendor dashboard — ${entry.key}', () {
      List<Override> vendorOverrides(List<OrderModel> orders) => [
        currentVendorProvider.overrideWith(
          (ref) async => {'business_name': _long, 'business_logo_url': null},
        ),
        vendorOrdersProvider.overrideWith((ref) => _Orders(orders)),
        vendorProductsProvider.overrideWith((ref) => _Products()),
        deliveryProvider.overrideWith((ref) => _Deliveries(const [])),
      ];

      testWidgets('no orders', (tester) async {
        await _pump(
          tester,
          const VendorDashboardScreen(),
          size: size,
          overrides: vendorOverrides(const []),
        );

        // The two surviving shortcuts; the duplicates of the tabs are gone
        expect(find.text('Add Product'), findsOneWidget);
        expect(find.text('Analytics'), findsOneWidget);
        expect(find.text('Quick Actions'), findsNothing);
        expect(find.text('Orders'), findsNothing);
        expect(find.text('Inventory'), findsNothing);

        await tester.scrollUntilVisible(
          find.textContaining('No orders received yet'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('See all'), findsOneWidget);
        await _unmount(tester);
      });

      testWidgets('with orders', (tester) async {
        await _pump(
          tester,
          const VendorDashboardScreen(),
          size: size,
          overrides: vendorOverrides([
            _order('1', 'pending'),
            _order('2', 'preparing'),
            _order('3', 'ready_for_delivery'),
            _order('4', 'delivered'),
          ]),
        );
        await tester.scrollUntilVisible(
          find.text('Recent Orders'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await _unmount(tester);
      });
    });

    group('admin dashboard — ${entry.key}', () {
      List<Override> adminOverrides(
        List<DeliveryModel> deliveries,
        List<DroneModel> drones,
      ) => [
        deliveryProvider.overrideWith((ref) => _Deliveries(deliveries)),
        droneProvider.overrideWith((ref) => _Drones(drones)),
        fleetTelemetryProvider.overrideWith((ref) => _FleetTelemetry()),
        deliveryTelemetryProvider.overrideWith(
          (ref, id) => _DeliveryTelemetry(),
        ),
        lowBatteryAlertsProvider.overrideWith((ref) => _LowBattery()),
      ];

      testWidgets('no deliveries, no drones', (tester) async {
        await _pump(
          tester,
          const AdminDashboardScreen(),
          size: size,
          overrides: adminOverrides(const [], const []),
        );

        expect(find.text('No Drones Registered'), findsOneWidget);
        // Nothing in flight: no radar shortcut to the deliveries list
        expect(find.text('Deliveries'), findsNothing);
        expect(find.text('Track Delivery'), findsNothing);

        // No deliveries means no success rate, not a perfect one
        expect(find.text('100.0%'), findsNothing);
        expect(find.text('No deliveries yet', skipOffstage: false), findsOneWidget);

        await tester.scrollUntilVisible(
          find.textContaining('first order is dispatched'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        // The one way into the deliveries list
        expect(find.text('See all'), findsOneWidget);
        await _unmount(tester);
      });

      testWidgets('with deliveries and a drone', (tester) async {
        await _pump(
          tester,
          const AdminDashboardScreen(),
          size: size,
          overrides: adminOverrides(
            [
              _delivery('1', DeliveryStatus.pending),
              _delivery('2', DeliveryStatus.delivered),
            ],
            [
              DroneModel(
                id: 'DRN-001',
                name: 'DRN-001',
                batteryLevel: 80,
                status: DroneStatus.available,
                maxPayload: 0.5,
                modelType: 'Quad',
                currentCoordinates: '10.3252, 123.9532',
              ),
            ],
          ),
        );
        expect(find.text('Campus Fleet Active'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Recent Deliveries'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await _unmount(tester);
      });
    });
  }
}
