import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerodrop/core/models/cart_model.dart';
import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/core/models/order_quote_model.dart';
import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/providers/delivery_zone_provider.dart';
import 'package:aerodrop/core/providers/location_provider.dart';
import 'package:aerodrop/core/providers/notification_provider.dart';
import 'package:aerodrop/core/providers/order_quote_provider.dart';
import 'package:aerodrop/core/providers/weather_provider.dart';
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/core/widgets/neu_button.dart';
import 'package:aerodrop/features/cart/checkout_screen.dart';
import 'package:aerodrop/features/cart/dropoff_map_picker.dart';

const _zone = DeliveryZone(
  centerLatitude: 10.325152,
  centerLongitude: 123.953046,
  centerName: 'Campus Drone Hub',
  radiusMeters: 300,
);

CartItem _item(String id, int qty) => CartItem(
  productId: id,
  productName: 'Item $id',
  vendorId: 'vendor-1',
  vendorName: 'Vendor',
  imageUrl: '',
  unitPrice: 50,
  weightKg: 0.2,
  quantity: qty,
);

Map<String, dynamic> _orderRow(Map<String, dynamic> extra) => {
  'id': 'o1',
  'user_id': 'u1',
  'vendor_id': 'v1',
  'order_status': 'pending',
  'total_amount': 100,
  'created_at': '2026-11-16T02:00:00Z',
  ...extra,
};

void main() {
  group('OrderModel pin', () {
    test('a pinned order carries its coordinates and label', () {
      final o = OrderModel.fromMap(
        _orderRow({
          'delivery_location_id': null,
          'custom_dropoff_lat': 10.3255,
          'custom_dropoff_lng': '123.9535',
          'custom_dropoff_label': '  by the main gate ',
        }),
      );
      expect(o.hasCustomDropoff, isTrue);
      expect(o.customDropoffLat, 10.3255);
      expect(o.customDropoffLng, 123.9535);
      expect(o.customDropoffLabel, 'by the main gate');
      expect(o.dropoffLocationName, 'by the main gate');
    });

    test('a pin without a label gets a plain name', () {
      final o = OrderModel.fromMap(
        _orderRow({'custom_dropoff_lat': 10.3255, 'custom_dropoff_lng': 123.9}),
      );
      expect(o.customDropoffLabel, isNull);
      expect(o.dropoffLocationName, OrderModel.pinnedDropoffName);
    });

    test('a fixed-point order is unchanged', () {
      final o = OrderModel.fromMap(
        _orderRow({
          'delivery_location_id': 'loc-1',
          'campus_locations': {'name': 'Maritime Building'},
        }),
      );
      expect(o.hasCustomDropoff, isFalse);
      expect(o.dropoffLocationName, 'Maritime Building');
    });

    test('half a pin is not a pin', () {
      final o = OrderModel.fromMap(_orderRow({'custom_dropoff_lat': 10.3}));
      expect(o.hasCustomDropoff, isFalse);
    });
  });

  test('DeliveryModel exposes the pin and keeps it through copyWith', () {
    final d = DeliveryModel(
      id: 'd1',
      senderName: 'Vendor',
      recipientName: 'Customer',
      recipientPhone: '',
      deliveryAddress: 'by the main gate',
      packageName: 'Order',
      packageWeight: 0.2,
      packageType: 'Food',
      status: DeliveryStatus.inTransit,
      eta: '',
      createdAt: DateTime(2026, 11, 16),
      progress: 0.2,
      customDropoffLat: 10.3255,
      customDropoffLng: 123.9535,
      customDropoffLabel: 'by the main gate',
    );
    expect(d.customDropoffCoords, (10.3255, 123.9535));
    final moved = d.copyWith(progress: 0.5);
    expect(moved.hasCustomDropoff, isTrue);
    expect(moved.customDropoffLabel, 'by the main gate');

    final fixed = DeliveryModel(
      id: 'd2',
      senderName: '',
      recipientName: '',
      recipientPhone: '',
      deliveryAddress: 'Main Building',
      packageName: '',
      packageWeight: 0,
      packageType: '',
      status: DeliveryStatus.pending,
      eta: '',
      createdAt: DateTime(2026, 11, 16),
      progress: 0,
    );
    expect(fixed.customDropoffCoords, isNull);
  });

  group('quote requests with a pin', () {
    test('a pin replaces the location id', () {
      final r = orderQuoteRequestFor(
        [_item('p1', 1)],
        'loc-1',
        pin: (10.3255, 123.9535),
      )!;
      expect(r.dropoffLocationId, isNull);
      expect(r.dropoffLat, 10.3255);
      expect(r.dropoffLng, 123.9535);
    });

    test('a pin is enough without any location selected', () {
      expect(
        orderQuoteRequestFor([_item('p1', 1)], null, pin: (10.3, 123.9)),
        isNotNull,
      );
    });

    test('a different pin is a different quote', () {
      final a = orderQuoteRequestFor(
        [_item('p1', 1)],
        null,
        pin: (10.3, 123.9),
      );
      final b = orderQuoteRequestFor(
        [_item('p1', 1)],
        null,
        pin: (10.4, 123.9),
      );
      expect(a, isNot(b));
    });

    test('a fixed-point request carries no coordinates', () {
      final r = orderQuoteRequestFor([_item('p1', 1)], 'loc-1')!;
      expect(r.dropoffLocationId, 'loc-1');
      expect(r.dropoffLat, isNull);
    });
  });

  group('DeliveryZone.fromMap', () {
    test('reads delivery_zone_info', () {
      final z = DeliveryZone.fromMap({
        'center_latitude': 10.325152,
        'center_longitude': '123.953046',
        'center_name': 'Campus Drone Hub',
        'radius_meters': 300,
      })!;
      expect(z.radiusMeters, 300);
      expect(z.centerLongitude, 123.953046);
    });

    test('no zone without a centre or a radius; nothing is assumed', () {
      expect(DeliveryZone.fromMap({}), isNull);
      expect(
        DeliveryZone.fromMap({
          'center_latitude': 10.3,
          'center_longitude': 123.9,
        }),
        isNull,
      );
      expect(
        DeliveryZone.fromMap({
          'center_latitude': 10.3,
          'center_longitude': 123.9,
          'radius_meters': 0,
        }),
        isNull,
      );
    });
  });

  const sizes = {'360dp': Size(360, 740), 'desktop': Size(1366, 768)};

  for (final entry in sizes.entries) {
    group('map picker — ${entry.key}', () {
      Future<void> pump(WidgetTester tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        AppTheme.isDarkMode = true;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const DropoffMapPicker(zone: _zone),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }

      NeuButton confirm(WidgetTester tester) =>
          tester.widget<NeuButton>(find.byType(NeuButton));

      testWidgets('no pin yet: confirm is disabled', (tester) async {
        await pump(tester);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Tap the map'), findsOneWidget);
        expect(confirm(tester).onPressed, isNull);
        expect(find.text('Describe the spot (optional)'), findsOneWidget);
      });

      testWidgets('a pin inside the circle can be confirmed', (tester) async {
        await pump(tester);
        await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Inside the delivery area'), findsOneWidget);
        expect(confirm(tester).onPressed, isNotNull);
      });

      testWidgets('a pin outside the circle cannot', (tester) async {
        await pump(tester);
        // A corner of the first view lies beyond the circle at any shape
        await tester.tapAt(
          tester.getTopLeft(find.byType(FlutterMap)) + const Offset(6, 6),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(
          find.textContaining('Outside the delivery area'),
          findsOneWidget,
        );
        expect(confirm(tester).onPressed, isNull);
      });
    });
  }

  group('checkout drop-off choice', () {
    setUp(() => cartNotifier.addItem(_item('p1', 2)));
    tearDown(cartNotifier.clear);

    Future<void> pump(WidgetTester tester, DeliveryZone? zone) async {
      tester.view.physicalSize = const Size(360, 740);
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
            deliveryZoneProvider.overrideWith((ref) async => zone),
            orderQuoteProvider.overrideWith(
              (ref, req) async => OrderQuote.fromMap({
                'subtotal': 100,
                'delivery_fee': 20,
                'total_amount': 120,
              }),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const CheckoutScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('with a zone: both options, campus list by default', (
      tester,
    ) async {
      await pump(tester, _zone);
      expect(tester.takeException(), isNull);
      expect(find.text('Campus drop-off point'), findsOneWidget);
      expect(find.text('Pin on map'), findsOneWidget);
      expect(find.text('Main Library Pad'), findsOneWidget);
      expect(find.text('₱120.00'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('without a zone: the pin option is absent', (tester) async {
      await pump(tester, null);
      expect(tester.takeException(), isNull);
      expect(find.text('Pin on map'), findsNothing);
      expect(find.text('Campus drop-off point'), findsNothing);
      expect(find.text('Main Library Pad'), findsOneWidget);
      expect(find.text('₱120.00'), findsOneWidget);
      await unmount(tester);
    });
  });
}

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
