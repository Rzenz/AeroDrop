import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/models/drone_model.dart';
import 'package:aerodrop/core/providers/drone_provider.dart';
import 'package:aerodrop/core/widgets/shared_drone_radar.dart';

void main() {
  group('SharedDroneRadar OpenStreetMap & Offline Fallback Tests', () {
    testWidgets('renders FlutterMap with OpenStreetMap attribution and landmark markers', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SharedDroneRadar(
                delivery: null,
                title: 'Campus Drone Radar',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(find.text('BASE HUB'), findsOneWidget);
      expect(find.text('MAIN'), findsOneWidget);
      expect(find.text('ANNEX-2'), findsOneWidget);
      expect(find.text('BASIC-ED'), findsOneWidget);
      expect(find.text('MARITIME'), findsOneWidget);
    });

    testWidgets('renders route polylines and live drone marker during inTransit delivery', (tester) async {
      final activeDelivery = DeliveryModel(
        id: 'del-map-01',
        senderName: 'Campus Cafe',
        recipientName: 'Juan Dela Cruz',
        recipientPhone: '09171234567',
        deliveryAddress: 'Maritime Building',
        packageName: 'Coffee and Sandwich',
        packageWeight: 0.5,
        packageType: 'Food',
        eta: '4 mins',
        progress: 0.55,
        status: DeliveryStatus.inTransit,
        droneId: 'DRN-001',
        pickupLocationName: 'Main Building',
        dropoffLocationName: 'Maritime Building',
        currentLatitude: 10.3255,
        currentLongitude: 123.9538,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SharedDroneRadar(
                delivery: activeDelivery,
                title: 'DELIVERY RADAR',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.text('In Flight / In Transit'), findsOneWidget);
      expect(find.text('55%'), findsOneWidget);
    });

    testWidgets('renders returning to base state with warning tone and progress', (tester) async {
      final returningDelivery = DeliveryModel(
        id: 'del-map-02',
        senderName: 'Campus Cafe',
        recipientName: 'Juan Dela Cruz',
        recipientPhone: '09171234567',
        deliveryAddress: 'Annex 2 Building',
        packageName: 'Stationery',
        packageWeight: 0.3,
        packageType: 'Documents',
        eta: '2 mins',
        progress: 0.80,
        status: DeliveryStatus.inTransit,
        droneId: 'DRN-002',
        pickupLocationName: 'Annex 2 Building',
        dropoffLocationName: 'Base Hub',
        currentLatitude: 10.3253,
        currentLongitude: 123.9533,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SharedDroneRadar(
                delivery: returningDelivery,
                title: 'RETURNING RADAR',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
    });

    testWidgets('full flight cycle: pickup -> delivery -> delivered -> returning to base -> arrival runs cleanly without assertions', (tester) async {
      final container = ProviderContainer(
        overrides: [
          droneProvider.overrideWith((ref) => DroneNotifier(ref)),
        ],
      );
      addTearDown(container.dispose);

      // Base shared model
      DeliveryModel createDelivery({
        required DeliveryStatus status,
        required double progress,
      }) {
        return DeliveryModel(
          id: 'del-flight-01',
          senderName: 'Campus Cafe',
          recipientName: 'Juan Dela Cruz',
          recipientPhone: '09171234567',
          deliveryAddress: 'Maritime Building',
          packageName: 'Document Folder',
          packageWeight: 0.4,
          packageType: 'Documents',
          eta: '5 mins',
          progress: progress,
          status: status,
          droneId: 'DRN-001',
          pickupLocationName: 'Main Building',
          dropoffLocationName: 'Maritime Building',
          currentLatitude: 10.3255,
          currentLongitude: 123.9538,
          createdAt: DateTime.now(),
        );
      }

      // 1. Pickup Phase
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SharedDroneRadar(
                delivery: createDelivery(
                  status: DeliveryStatus.assigning,
                  progress: 0.25,
                ),
                title: 'LIVE RADAR',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Heading to Pickup'), findsOneWidget);
      expect(find.text('Pickup Progress'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);

      // 2. Delivery Phase (In Transit)
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SharedDroneRadar(
                delivery: createDelivery(
                  status: DeliveryStatus.inTransit,
                  progress: 0.70,
                ),
                title: 'LIVE RADAR',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('In Flight / In Transit'), findsOneWidget);
      expect(find.text('Delivery Progress'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);

      // 3. Delivered Phase
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SharedDroneRadar(
                delivery: createDelivery(
                  status: DeliveryStatus.delivered,
                  progress: 1.0,
                ),
                title: 'LIVE RADAR',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      // 4. Returning to Base Phase
      // Simulate drone in returning state
      container.read(droneProvider.notifier).state = [
        DroneModel(
          id: 'DRN-001',
          name: 'AeroCarrier Alpha',
          status: DroneStatus.returning,
          batteryLevel: 85.0,
          maxPayload: 0.5,
          modelType: 'Hexacopter',
          currentCoordinates: '10.3255,123.9538',
        ),
      ];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SharedDroneRadar(
                delivery: createDelivery(
                  status: DeliveryStatus.delivered,
                  progress: 1.0,
                ),
                title: 'LIVE RADAR',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Returning to Base'), findsOneWidget);
      expect(find.text('Return Progress'), findsOneWidget);

      // 5. Arrival at Base Hub Phase
      container.read(droneProvider.notifier).state = [
        DroneModel(
          id: 'DRN-001',
          name: 'AeroCarrier Alpha',
          status: DroneStatus.available,
          batteryLevel: 82.0,
          maxPayload: 0.5,
          modelType: 'Hexacopter',
          currentCoordinates: '10.325152,123.953046',
        ),
      ];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SharedDroneRadar(
                delivery: null,
                title: 'CAMPUS RADAR',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Available — At Base'), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);

      // Unmount widget and dispose container so all timers cancel cleanly
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      container.dispose();
    });

    testWidgets('TileLayer errorTileCallback safely triggers offline fallback without setState during build', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SharedDroneRadar(
                delivery: null,
                title: 'Campus Drone Radar',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final tileLayerFinder = find.byType(TileLayer);
      expect(tileLayerFinder, findsOneWidget);
      final tileLayer = tester.widget<TileLayer>(tileLayerFinder);

      // Trigger 3 tile errors to reach offline fallback threshold
      final dummyTile = FakeTileImage();
      tileLayer.errorTileCallback?.call(
        dummyTile,
        Exception('Network tile failure test'),
        StackTrace.empty,
      );
      tileLayer.errorTileCallback?.call(
        dummyTile,
        Exception('Network tile failure test'),
        StackTrace.empty,
      );
      tileLayer.errorTileCallback?.call(
        dummyTile,
        Exception('Network tile failure test'),
        StackTrace.empty,
      );

      // Drain post frame callbacks safely
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Offline map indicator should be visible
      expect(find.text('Offline map'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('panning triggers onPositionChanged safely and Follow Drone button recenters cleanly', (tester) async {
      final activeDelivery = DeliveryModel(
        id: 'del-pan-01',
        senderName: 'Campus Cafe',
        recipientName: 'Juan Dela Cruz',
        recipientPhone: '09171234567',
        deliveryAddress: 'Maritime Building',
        packageName: 'Coffee and Sandwich',
        packageWeight: 0.5,
        packageType: 'Food',
        eta: '4 mins',
        progress: 0.55,
        status: DeliveryStatus.inTransit,
        droneId: 'DRN-001',
        pickupLocationName: 'Main Building',
        dropoffLocationName: 'Maritime Building',
        currentLatitude: 10.3255,
        currentLongitude: 123.9538,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SharedDroneRadar(
                delivery: activeDelivery,
                title: 'LIVE RADAR',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Simulate panning gesture
      await tester.drag(find.byType(FlutterMap), const Offset(60, 60));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Follow Drone button should appear
      expect(find.text('Follow Drone'), findsOneWidget);

      // Tap Follow Drone button
      await tester.tap(find.text('Follow Drone'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Follow Drone button should disappear once recentered
      expect(find.text('Follow Drone'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}

class FakeTileImage implements TileImage {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
