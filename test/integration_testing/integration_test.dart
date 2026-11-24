// Integration testing (mobile application): each case acts on one screen and
// checks the result on the screen of the next module, often as another
// account, through one shared backend (_backend.dart).
import 'package:aerodrop/core/models/cart_model.dart';
import 'package:aerodrop/core/models/order_quote_model.dart';
import 'package:aerodrop/core/providers/order_quote_provider.dart';
import 'package:aerodrop/features/cart/checkout_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/features/admin/admin_deliveries_screen.dart';
import 'package:aerodrop/features/admin/admin_weather_screen.dart';
import 'package:aerodrop/features/cart/cart_screen.dart';
import 'package:aerodrop/features/notifications/notifications_screen.dart';
import 'package:aerodrop/features/orders/orders_screen.dart';
import 'package:aerodrop/features/products/product_details_screen.dart';
import 'package:aerodrop/features/vendor/vendor_notifications_screen.dart';
import 'package:aerodrop/features/vendor/vendor_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_backend.dart';

/// Opens [screen] signed in as [who] on a phone-sized view.
Future<void> open(WidgetTester tester, String who, Widget screen, {Size size = const Size(600, 1200)}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  AppTheme.isDarkMode = true;
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(ProviderScope(key: UniqueKey(), overrides: session(who), child: MaterialApp(theme: AppTheme.darkTheme, home: screen)));
  await tester.pump(const Duration(seconds: 2));
}

/// Opens Checkout as Maria Santos inside a router, so it can move on to the receipt.
Future<void> openCheckout(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(600, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  AppTheme.isDarkMode = true;
  final router = GoRouter(initialLocation: '/user/checkout', routes: [
    GoRoute(path: '/user/checkout', builder: (_, _) => const CheckoutScreen()),
    GoRoute(path: '/user/receipt', builder: (_, _) => const Scaffold(body: Center(child: Text('Receipt')))),
  ]);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      ...session('maria'),
      // quote_order_fee() for the cart, priced as the server does (base, distance, weight).
      orderQuoteProvider.overrideWith((ref, request) async => OrderQuote.fromMap({
        'subtotal': cartNotifier.totalAmount,
        'delivery_fee': 15 + 8.39 + cartNotifier.totalWeightKg * 10,
        'total_amount': cartNotifier.totalAmount + 15 + 8.39 + cartNotifier.totalWeightKg * 10,
        'total_weight_grams': (cartNotifier.totalWeightKg * 1000).round(),
        'trips_required': 1,
        'distance_km': 0.2097,
        'is_caution': false,
        'breakdown': {'base': 15.0, 'distance': 8.39, 'weight': cartNotifier.totalWeightKg * 10, 'extra_trip': 0.0, 'weather': 0.0},
      })),
    ],
    child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
  ));
  await tester.pump(const Duration(seconds: 2));
  // The drop-off is chosen once the campus locations load; the fee is quoted after.
  for (var i = 0; i < 40 && find.text('Calculating Fee…').evaluate().isNotEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> tapText(WidgetTester tester, String label) async {
  final f = find.text(label);
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Lets snack bars and animations finish before the next screen or the end.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Future<void> tab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text(label)));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    backend = Backend();
    cartNotifier.clear();
  });

  group('Test Case ID: INT-024', () {
    testWidgets('Product Details -> Cart | Customer adds Iced Spanish Latte to the cart from its product page | The cart lists Iced Spanish Latte at P120.00', (tester) async {
      await open(tester, 'maria', const ProductDetailsScreen(productId: 'latte'));
      await tapText(tester, 'Add to Cart');
      await settle(tester);

      await open(tester, 'maria', const CartScreen());
      expect(find.text('Iced Spanish Latte'), findsWidgets);
      expect(find.textContaining('120.00'), findsWidgets);
      expect(cartNotifier.totalItems, 1);
      await settle(tester);
    });
  });

  group('Test Case ID: INT-026', () {
    testWidgets('Checkout -> Vendor Orders | Customer places an order with Kape Kanto | The order appears in the vendor orders with the customer name, and the vendor is notified', (tester) async {
      customerOrders();
      await open(tester, 'kape', const VendorOrdersScreen());
      expect(find.textContaining('Maria Santos'), findsWidgets);
      await settle(tester);

      await open(tester, 'kape', const VendorNotificationsScreen());
      expect(find.text('New Order Received'), findsOneWidget);
      await settle(tester);
    });
  });

  group('Test Case ID: INT-027', () {
    testWidgets('Vendor Orders -> Notifications | Vendor taps Accept Order on the pending order | The customer receives "Order Confirmed"', (tester) async {
      final id = customerOrders();
      await open(tester, 'kape', const VendorOrdersScreen());
      await tapText(tester, 'Accept Order');
      expect(find.text('Order updated to confirmed.'), findsOneWidget);
      expect(backend.orders.single.status, 'confirmed');
      await settle(tester);

      await open(tester, 'maria', const NotificationsScreen());
      expect(find.text('Order Confirmed'), findsOneWidget);
      expect(find.text('The vendor has accepted your order.'), findsOneWidget);
      expect(backend.orders.single.id, id);
      await settle(tester);
    });
  });

  group('Test Case ID: INT-028', () {
    testWidgets('Vendor Orders -> My Orders | Vendor taps Reject on the pending order | The order moves to the customer\'s Cancelled tab and the payment is refunded', (tester) async {
      customerOrders();
      await open(tester, 'kape', const VendorOrdersScreen());
      await tapText(tester, 'Reject');
      expect(backend.orders.single.status, 'cancelled');
      expect(backend.orders.single.paymentStatus, 'refunded');
      await settle(tester);

      await open(tester, 'maria', const OrdersScreen(), size: const Size(900, 900));
      await tab(tester, 'Cancelled');
      expect(find.text('Kape Kanto').hitTestable(), findsOneWidget);
      await settle(tester);
    });
  });

  group('Test Case ID: INT-029', () {
    testWidgets('Vendor Orders -> Notifications | Vendor taps Mark as Ready on the order being prepared | DRN-001 is dispatched and the customer receives "Drone Dispatched to Vendor"', (tester) async {
      preparingOrder();
      await open(tester, 'kape', const VendorOrdersScreen(initialStatus: 'preparing'));
      await tapText(tester, 'Mark as Ready');
      expect(find.text('Order is ready for delivery. Drone DRN-001 dispatched for pickup.'), findsOneWidget);
      expect(backend.deliveries.single.status, 'assigning');
      await settle(tester);

      await open(tester, 'maria', const NotificationsScreen());
      expect(find.text('Drone Dispatched to Vendor'), findsOneWidget);
      await settle(tester);
    });
  });

  group('Test Case ID: INT-030', () {
    testWidgets('Vendor Orders -> Deliveries Dispatch | Vendor marks the order ready for drone pickup | The admin Deliveries Dispatch screen lists the Kape Kanto delivery with DRN-001 assigned', (tester) async {
      preparingOrder();
      await open(tester, 'kape', const VendorOrdersScreen(initialStatus: 'preparing'));
      await tapText(tester, 'Mark as Ready');
      await settle(tester);

      await open(tester, 'admin', const AdminDeliveriesScreen(), size: const Size(900, 1400));
      expect(find.text('Kape Kanto'), findsOneWidget);
      expect(backend.deliveries.single.droneId, 'drn1');
      await settle(tester);
    });
  });

  group('Test Case ID: INT-031', () {
    testWidgets('Deliveries Dispatch -> Notifications | DRN-001 picks up the package at Kape Kanto | The admin sees the delivery under In Transit and the customer receives "Package Picked Up"', (tester) async {
      final id = preparingOrder();
      backend.markReady('kape', id);
      backend.pickUp(id);

      await open(tester, 'admin', const AdminDeliveriesScreen(), size: const Size(900, 1400));
      await tapText(tester, 'In Transit');
      expect(find.text('Kape Kanto'), findsOneWidget);
      await settle(tester);

      await open(tester, 'maria', const NotificationsScreen());
      expect(find.text('Package Picked Up'), findsOneWidget);
      await settle(tester);
    });
  });

  group('Test Case ID: INT-032', () {
    testWidgets('Deliveries Dispatch -> My Orders | DRN-001 completes the delivery at the Maritime Building | The order is listed under Delivered in My Orders and the customer receives "Order Delivered"', (tester) async {
      final id = preparingOrder();
      backend.markReady('kape', id);
      backend.pickUp(id);
      backend.complete(id);

      await open(tester, 'maria', const OrdersScreen(), size: const Size(900, 900));
      await tab(tester, 'Delivered');
      expect(find.text('Kape Kanto').hitTestable(), findsOneWidget);
      await settle(tester);

      await open(tester, 'maria', const NotificationsScreen());
      expect(find.text('Order Delivered'), findsOneWidget);
      await settle(tester);
    });
  });

  group('Test Case ID: INT-033', () {
    testWidgets('Weather Controls -> Vendor Orders | Admin publishes GROUNDED, then the vendor taps Mark as Ready | No drone is dispatched and "Flight dispatch blocked: Weather is grounded" is shown', (tester) async {
      preparingOrder();
      await open(tester, 'admin', const AdminWeatherScreen(), size: const Size(600, 1600));
      await tapText(tester, 'GROUNDED');
      await tapText(tester, 'Publish Weather Constraints');
      expect(backend.weather, 'grounded');
      await settle(tester);

      await open(tester, 'kape', const VendorOrdersScreen(initialStatus: 'preparing'));
      await tapText(tester, 'Mark as Ready');
      expect(find.text('Flight dispatch blocked: Weather is grounded'), findsOneWidget);
      expect(backend.deliveries, isEmpty);
      await settle(tester);
    });
  });


  group('Test Case ID: INT-025', () {
    testWidgets('Cart -> Checkout -> My Orders | Customer confirms the order for the Maritime Building and pays | The order is placed, the receipt opens, the stock is reduced and the order is listed in My Orders', (tester) async {
      cartNotifier.addItem(CartItem(productId: 'latte', productName: 'Iced Spanish Latte', vendorId: 'kape', vendorName: 'Kape Kanto', imageUrl: '', unitPrice: 120, weightKg: 0.38));
      await openCheckout(tester);
      await tapText(tester, 'Confirm Order');
      // The checkout re-quotes the fee before the confirmation dialog opens.
      for (var i = 0; i < 20 && find.text('Confirm & Pay').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tapText(tester, 'Confirm & Pay');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Receipt'), findsOneWidget);
      expect(backend.orders, hasLength(1));
      expect(backend.products.firstWhere((p) => p.id == 'latte').stock, 23);
      await settle(tester);

      await open(tester, 'maria', const OrdersScreen(), size: const Size(900, 900));
      expect(find.text('Kape Kanto'), findsWidgets);
      await settle(tester);
    });
  });

  group('Test Case ID: INT-034', () {
    testWidgets('Weather Controls -> Checkout | Admin publishes GROUNDED, then the customer opens Checkout | The order button reads "Flight Grounded" and no order can be placed', (tester) async {
      await open(tester, 'admin', const AdminWeatherScreen(), size: const Size(600, 1600));
      await tapText(tester, 'GROUNDED');
      await tapText(tester, 'Publish Weather Constraints');
      expect(backend.weather, 'grounded');
      await settle(tester);

      cartNotifier.addItem(CartItem(productId: 'latte', productName: 'Iced Spanish Latte', vendorId: 'kape', vendorName: 'Kape Kanto', imageUrl: '', unitPrice: 120, weightKg: 0.38));
      await openCheckout(tester);
      expect(find.text('Flight Grounded'), findsOneWidget);
      await tester.tap(find.text('Flight Grounded'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));
      expect(backend.orders, isEmpty);
      await settle(tester);
    });
  });
}
