import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerodrop/core/models/cart_model.dart';
import 'package:aerodrop/core/models/order_quote_model.dart';
import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/providers/location_provider.dart';
import 'package:aerodrop/core/providers/notification_provider.dart';
import 'package:aerodrop/core/providers/order_quote_provider.dart';
import 'package:aerodrop/core/providers/weather_provider.dart';
import 'package:aerodrop/core/services/delivery_fee_calculator.dart';
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/features/cart/checkout_screen.dart';

/// The example reply from the migration 31 brief.
const _reply = {
  'subtotal': 750.00,
  'delivery_fee': 49.45,
  'total_amount': 799.45,
  'total_weight_grams': 940,
  'trips_required': 2,
  'distance_km': 0.1312,
  'is_caution': false,
  'breakdown': {
    'base': 15.00,
    'distance': 0.00,
    'weight': 9.45,
    'extra_trip': 25.00,
    'weather': 0.00,
  },
};

CartItem _item(String id, int qty) => CartItem(
  productId: id,
  productName: 'Item $id',
  vendorId: 'vendor-1',
  vendorName: 'Vendor',
  imageUrl: '',
  // Deliberately not the server's price: the checkout must show the quote
  unitPrice: 999,
  weightKg: 0.47,
  quantity: qty,
);

void main() {
  group('OrderQuote.fromMap', () {
    test('reads the quote_order_fee reply', () {
      final q = OrderQuote.fromMap(Map<String, dynamic>.from(_reply));
      expect(q.subtotal, 750.0);
      expect(q.deliveryFee, 49.45);
      expect(q.totalAmount, 799.45);
      expect(q.tripsRequired, 2);
      expect(q.extraTripFee, 25.0);
      expect(q.weightFee, 9.45);
    });

    test('accepts numeric strings, as Postgres numerics can arrive', () {
      final q = OrderQuote.fromMap({
        'subtotal': '10.50',
        'delivery_fee': '15.00',
        'total_amount': '25.50',
      });
      expect(q.totalAmount, 25.5);
      expect(q.tripsRequired, 1);
    });

    test('refuses a reply without a price rather than showing zero', () {
      expect(
        () => OrderQuote.fromMap({'subtotal': 10, 'delivery_fee': 15}),
        throwsFormatException,
      );
    });
  });

  test('server figures render through the existing labels', () {
    final rows = OrderQuote.fromMap(
      Map<String, dynamic>.from(_reply),
    ).toFeeBreakdown();
    expect(rows.totalFee, 49.45);
    expect(rows.breakdownText, contains('Base ₱15.00'));
    expect(rows.breakdownText, contains('Distance 0.13 km × 2 trips ₱0.00'));
    expect(rows.breakdownText, contains('Weight 0.94 kg ₱9.45'));
    expect(rows.breakdownText, contains('Extra drone trip ₱25.00'));
    expect(
      rows.breakdownRows.map((r) => r.label),
      contains('Extra drone trip (1 × ₱25.00)'),
    );
  });

  test('breakdownFrom labels exactly as calculateOrderFee did', () {
    final local = DeliveryFeeCalculator.calculateOrderFee(
      distanceKm: 0.21,
      weightKg: 0.32,
      isCaution: true,
    );
    final labelled = DeliveryFeeCalculator.breakdownFrom(
      baseFee: local.baseFee,
      distanceKm: local.distanceKm,
      distanceFee: local.distanceFee,
      weightKg: local.weightKg,
      weightFee: local.weightFee,
      weatherFee: local.weatherFee,
      extraTripFee: local.extraTripFee,
      totalFee: local.totalFee,
      trips: local.trips,
    );
    expect(labelled.breakdownText, local.breakdownText);
  });

  group('quote requests', () {
    test('the same cart in any order shares one quote', () {
      final a = orderQuoteRequestFor([_item('p1', 1), _item('p2', 3)], 'loc');
      final b = orderQuoteRequestFor([_item('p2', 3), _item('p1', 1)], 'loc');
      expect(a, b);
      expect(orderQuoteRequestFor([_item('p1', 2)], 'loc'), isNot(a));
    });

    test('nothing to price without items or a drop-off', () {
      expect(orderQuoteRequestFor(const [], 'loc'), isNull);
      expect(orderQuoteRequestFor([_item('p1', 1)], null), isNull);
    });

    test('the payload sends only product and quantity', () {
      final req = orderQuoteRequestFor([_item('p1', 2), _item('p2', 1)], 'l')!;
      expect(quoteItemsPayload(req.items), [
        {'product_id': 'p1', 'quantity': 2},
        {'product_id': 'p2', 'quantity': 1},
      ]);
    });
  });

  group('checkout shows only the server price', () {
    const sizes = {'360dp': Size(360, 740), 'desktop': Size(1366, 768)};

    setUp(() => cartNotifier.addItem(_item('p1', 2)));
    tearDown(cartNotifier.clear);

    Future<void> pump(
      WidgetTester tester,
      Size size,
      Future<OrderQuote> Function() quote,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      AppTheme.isDarkMode = true;
      final loc = CampusLocation(
        id: 'loc-1',
        name: 'Main Library Pad',
        locationCode: 'LIB',
        latitude: 10.3,
        longitude: 123.9,
        isActive: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _Auth()),
            weatherProvider.overrideWith((ref) => _Weather()),
            campusLocationsProvider.overrideWith((ref) async => [loc]),
            dropoffLocationsProvider.overrideWith((ref) async => [loc]),
            unreadNotificationCountProvider.overrideWithValue(0),
            orderQuoteProvider.overrideWith((ref, req) => quote()),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const CheckoutScreen(),
          ),
        ),
      );
      // Locations resolve, the drop-off is picked, then the quote is asked for
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    for (final entry in sizes.entries) {
      testWidgets('${entry.key}: loading', (tester) async {
        final never = Completer<OrderQuote>();
        await pump(tester, entry.value, () => never.future);
        expect(tester.takeException(), isNull);
        expect(find.text('Calculating…'), findsWidgets);
        expect(find.text('Calculating Fee…'), findsOneWidget);
        expect(_confirm(tester).onPressed, isNull);
        await unmount(tester);
      });

      testWidgets('${entry.key}: quote failed', (tester) async {
        await pump(
          tester,
          entry.value,
          () async => throw StateError('Product not found'),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Unavailable'), findsWidgets);
        expect(
          find.text(
            'The delivery fee could not be calculated: Product not found',
          ),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Fee Unavailable'), findsOneWidget);
        expect(_confirm(tester).onPressed, isNull);
        // No figure computed on the device stands in for the missing one
        expect(find.textContaining('₱'), findsNothing);
        await unmount(tester);
      });

      testWidgets('${entry.key}: quoted', (tester) async {
        await pump(
          tester,
          entry.value,
          () async => OrderQuote.fromMap(Map<String, dynamic>.from(_reply)),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('₱750.00'), findsOneWidget);
        expect(find.text('₱49.45'), findsOneWidget);
        expect(find.text('₱799.45'), findsOneWidget);
        // The cart's own prices (2 × ₱999) appear nowhere
        expect(find.text('₱1998.00'), findsNothing);
        expect(_confirm(tester).onPressed, isNotNull);
        await unmount(tester);
      });
    }
  });
}

FilledButton _confirm(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth()
    : super(
        AuthState(
          user: AeroDropUser(
            id: 'u1',
            name: 'Test Customer',
            email: 'customer@example.com',
            phoneNumber: '+639171234567',
            role: 'user',
          ),
          isVerified: true,
          sessionUnlocked: true,
        ),
      );
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
