import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/core/providers/delivery_provider.dart';
import 'package:aerodrop/core/models/product_model.dart';
import 'package:aerodrop/core/providers/notification_provider.dart';
import 'package:aerodrop/core/providers/order_provider.dart';
import 'package:aerodrop/core/providers/product_provider.dart';
import 'package:aerodrop/core/providers/vendor_provider.dart';
import 'package:aerodrop/core/providers/weather_provider.dart';
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/features/dashboard/user_dashboard_screen.dart';

// Long, user-supplied strings are the realistic overflow trigger.
const _long = 'Extraordinarily Long Name That Should Ellipsize Cleanly Everywhere';

ProductModel _product(String id, String category, double rating, int reviews) =>
    ProductModel(
      id: id,
      vendorId: 'v1',
      vendorName: _long,
      name: '$_long $id',
      description: '',
      price: 1234.5,
      stock: 5,
      category: category,
      weightKg: 0.2,
      imageUrl: '',
      isAvailable: true,
      rating: rating,
      reviewCount: reviews,
    );

// The real notifiers reach for the Supabase client as they are built, which
// tests do not initialise; these stand in for them with fixed data.
class _SeededProducts extends StateNotifier<ProductState>
    implements ProductNotifier {
  _SeededProducts(List<ProductModel> products)
    : super(ProductState(products: products, categories: const ['All']));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _SeededVendors extends StateNotifier<VendorState>
    implements VendorNotifier {
  _SeededVendors(List<VendorViewModel> vendors)
    : super(VendorState(vendors: vendors));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _SeededOrders extends StateNotifier<OrderState> implements OrderNotifier {
  _SeededOrders(List<OrderModel> orders) : super(OrderState(orders: orders));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoDeliveries extends StateNotifier<List<DeliveryModel>>
    implements DeliveryNotifier {
  _NoDeliveries() : super(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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

Future<void> _pumpHome(
  WidgetTester tester, {
  required Size size,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  AppTheme.isDarkMode = true;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        weatherProvider.overrideWith((ref) => _Weather()),
        // Reads the Supabase client directly, which tests do not initialise
        unreadNotificationCountProvider.overrideWithValue(0),
        deliveryProvider.overrideWith((ref) => _NoDeliveries()),
        orderProvider.overrideWith((ref) => _SeededOrders(const [])),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const UserDashboardScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 800));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  for (final size in const [Size(360, 740), Size(320, 640)]) {
    final label = '${size.width.toInt()}dp';

    testWidgets('$label — every section empty', (tester) async {
      await _pumpHome(
        tester,
        size: size,
        overrides: [
          productProvider.overrideWith((ref) => _SeededProducts(const [])),
          vendorProvider.overrideWith((ref) => _SeededVendors(const [])),
        ],
      );

      expect(find.text('Set drop-off'), findsOneWidget);
      // No products: no category row, an empty featured note
      expect(find.text('All'), findsNothing);
      expect(find.text('No products available'), findsOneWidget);
      // No vendors
      await tester.scrollUntilVisible(
        find.text('No vendors available'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No vendors available'), findsOneWidget);
      // No orders
      await tester.scrollUntilVisible(
        find.text('No orders yet'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No orders yet'), findsOneWidget);
      // The Quick Actions block is gone
      expect(find.text('Quick Actions'), findsNothing);
      expect(find.text('Order Food'), findsNothing);

      await _unmount(tester);
    });

    testWidgets('$label — populated, chips filter the carousel', (tester) async {
      final products = [
        _product('p1', 'Meals', 4.8, 10),
        _product('p2', 'Meals', 4.8, 25),
        _product('p3', 'Snacks', 4.1, 3),
        _product('p4', 'Drinks', 3.9, 7),
        _product('p5', '', 5.0, 1), // uncategorised: no chip of its own
      ];
      final vendors = [
        VendorViewModel(
          id: 'v1',
          ownerName: 'Owner',
          businessName: _long,
          phoneNumber: '',
          email: 'v@example.com',
          building: '$_long – Annex',
          logoInitials: 'EL',
          rating: 4.5,
          reviewCount: 12,
        ),
      ];
      final orders = [
        OrderModel(
          id: '00000000-0000-0000-0000-000000000001',
          userId: 'u1',
          vendorId: 'v1',
          vendorName: _long,
          orderStatus: 'preparing',
          dropoffLocationId: 'l1',
          totalAmount: 12345.67,
          createdAt: DateTime(2026, 10, 26),
          items: [
            OrderItemModel(productName: _long, quantity: 3),
          ],
        ),
      ];

      await _pumpHome(
        tester,
        size: size,
        overrides: [
          productProvider.overrideWith((ref) => _SeededProducts(products)),
          vendorProvider.overrideWith((ref) => _SeededVendors(vendors)),
          orderProvider.overrideWith((ref) => _SeededOrders(orders)),
        ],
      );

      // Chips: All first, then distinct non-empty categories. The row
      // scrolls, so on narrow screens later chips sit past the edge.
      expect(find.text('All'), findsOneWidget);
      for (final c in ['Drinks', 'Meals', 'Snacks']) {
        expect(find.text(c, skipOffstage: false), findsOneWidget);
      }
      // Five featured items: a carousel with dots
      expect(find.byType(SmoothPageIndicator), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);

      // One item in the category: a plain row, no carousel
      await tester.tap(find.text('Drinks'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PageView), findsNothing);
      expect(find.byType(SmoothPageIndicator), findsNothing);
      expect(find.text('$_long p4'), findsOneWidget);

      // Two in the category: carousel again, ties broken on review count
      await tester.tap(find.text('Meals'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PageView), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Best Choice'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('Recent Orders'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await _unmount(tester);
    });
  }
}
