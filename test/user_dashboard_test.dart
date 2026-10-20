import 'package:aerodrop/core/models/cart_model.dart';
import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/models/product_model.dart';
import 'package:aerodrop/core/providers/delivery_provider.dart';
import 'package:aerodrop/core/providers/product_provider.dart';
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/features/web/app/customer/web_dashboard_page.dart';
import 'package:aerodrop/features/dashboard/widgets/dash_kit.dart';
import 'package:aerodrop/features/web/app/web_app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Products for the dashboard, without Supabase.
class _FakeProducts extends ProductNotifier {
  _FakeProducts(this._items);
  final List<ProductModel> _items;

  @override
  Future<void> loadProducts() async {
    state = ProductState(
      products: _items,
      categories: ['All', ..._items.map((p) => p.category).toSet()],
    );
  }
}

class _FakeDeliveries extends StateNotifier<List<DeliveryModel>>
    implements DeliveryNotifier {
  _FakeDeliveries(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProductModel _product(
  String id,
  String name,
  String category, {
  int stock = 10,
}) => ProductModel(
  id: id,
  vendorId: 'v1',
  vendorName: 'Annex Building Canteen',
  name: name,
  description: '',
  price: 85,
  stock: stock,
  category: category,
  weightKg: 0.3,
  imageUrl: '',
  isAvailable: true,
);

final _menu = [
  _product('p1', 'Chicken adobo rice bowl with egg', 'Meals'),
  _product('p2', 'Iced coffee', 'Drinks'),
  _product('p3', 'Ensaymada', 'Bakery', stock: 1),
  _product('p4', 'Pancit canton', 'Meals'),
  _product('p5', 'Calamansi juice', 'Drinks'),
];

void main() {
  AppTheme.isDarkMode = true;

  setUp(cartNotifier.clear);

  Future<List<String>> pump(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
    List<ProductModel>? products,
    List<DeliveryModel> deliveries = const [],
  }) async {
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());

    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productProvider.overrideWith((ref) => _FakeProducts(products ?? _menu)),
          deliveryProvider.overrideWith((ref) => _FakeDeliveries(deliveries)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: const WebDashboardPage(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    // Restored before any expect, so a failure reports instead of wedging
    // the test binding.
    FlutterError.onError = previous;
    return errors;
  }

  const sizes = <String, Size>{
    'small phone': Size(320, 640),
    'phone': Size(390, 844),
    'tablet': Size(834, 1112),
    'laptop, no order panel': Size(1180, 800),
    'desktop, three columns': Size(1440, 900),
  };

  group('lays out', () {
    for (final MapEntry(key: name, value: size) in sizes.entries) {
      for (final scale in const [1.0, 1.5]) {
        testWidgets('$name at ${scale}x', (tester) async {
          final errors = await pump(tester, size, textScale: scale);
          expect(
            errors.where((e) => e.contains('overflowed')),
            isEmpty,
            reason: errors.join('\n'),
          );
        });
      }
    }

    testWidgets('with nothing listed', (tester) async {
      final errors = await pump(
        tester,
        const Size(390, 844),
        products: const [],
      );
      expect(errors.where((e) => e.contains('overflowed')), isEmpty);
      expect(find.text('No food listed yet'), findsOneWidget);
    });
  });

  testWidgets('the order panel joins on a wide window only', (tester) async {
    await pump(tester, const Size(1440, 900));
    expect(find.byType(DashOrderPanel), findsOneWidget);
    await pump(tester, const Size(1180, 800));
    expect(find.byType(DashOrderPanel), findsNothing);
  });

  testWidgets('categories filter the grid', (tester) async {
    await pump(tester, const Size(1440, 900));
    expect(find.byType(DashProductCard), findsNWidgets(5));

    await tester.tap(find.text('Drinks').first);
    await tester.pumpAndSettle();
    expect(find.byType(DashProductCard), findsNWidgets(2));
    expect(find.text('Iced coffee'), findsOneWidget);
  });

  testWidgets('search filters the grid, and clears', (tester) async {
    await pump(tester, const Size(1440, 900));
    await tester.enterText(find.byType(TextField).first, 'adobo');
    await tester.pumpAndSettle();
    expect(find.byType(DashProductCard), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches that'), findsOneWidget);
    await tester.tap(find.text('Show everything'));
    await tester.pumpAndSettle();
    expect(find.byType(DashProductCard), findsNWidgets(5));
  });

  testWidgets('adding fills the order panel and its total', (tester) async {
    await pump(tester, const Size(1440, 900));
    // The first card's + button: tapped twice for two of the same item.
    final firstCard = find.byType(DashProductCard).first;
    final add = find.descendant(
      of: firstCard,
      matching: find.byIcon(Icons.add_rounded),
    );
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(cartNotifier.totalItems, 2);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('₱170.00'), findsWidgets);
  });

  testWidgets('never adds more than the canteen has in stock', (tester) async {
    await pump(tester, const Size(1440, 900));
    // Ensaymada: one in stock.
    final card = find.ancestor(
      of: find.text('Ensaymada'),
      matching: find.byType(DashProductCard),
    );
    final add = find.descendant(
      of: card,
      matching: find.byIcon(Icons.add_rounded),
    );
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(
      cartNotifier.value.firstWhere((c) => c.productId == 'p3').quantity,
      1,
    );
  });

  testWidgets('an active delivery shows with its status', (tester) async {
    final errors = await pump(
      tester,
      const Size(390, 844),
      deliveries: [
        DeliveryModel(
          id: 'd1',
          orderId: 'o1',
          senderName: 'Annex Building Canteen',
          recipientName: 'Student',
          recipientPhone: '09123456789',
          deliveryAddress: 'Maritime Building',
          packageName: 'Iced coffee (x2)',
          packageWeight: 0.4,
          packageType: 'Food',
          status: DeliveryStatus.inTransit,
          eta: '4 min',
          createdAt: DateTime.now(),
          progress: 0.4,
        ),
      ],
    );
    expect(errors, isEmpty, reason: errors.join('\n---\n'));
    expect(find.text('In flight'), findsOneWidget);
    expect(find.text('Track it live'), findsOneWidget);
  });

  group('in the website chrome', () {
    Future<List<String>> pumpShell(WidgetTester tester, Size size) async {
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) =>
          errors.add('${d.exceptionAsString()}\n${d.stack}');
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/user',
        routes: [
          GoRoute(
            path: '/user',
            builder: (c, s) => const WebAppShell(
              location: '/user',
              child: WebDashboardPage(),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productProvider.overrideWith((ref) => _FakeProducts(_menu)),
            deliveryProvider.overrideWith((ref) => _FakeDeliveries(const [])),
          ],
          child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      FlutterError.onError = previous;
      return errors;
    }

    testWidgets('a wide window gets the sidebar', (tester) async {
      final errors = await pumpShell(tester, const Size(1440, 900));
      expect(errors, isEmpty, reason: errors.join('\n---\n'));
      expect(find.byType(CustomerSidebar), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('a phone browser gets a top bar and a menu', (tester) async {
      final errors = await pumpShell(tester, const Size(390, 844));
      expect(errors, isEmpty, reason: errors.join('\n---\n'));
      expect(find.byType(CustomerSidebar), findsNothing);
      expect(find.byTooltip('Menu'), findsOneWidget);
    });
  });
}
