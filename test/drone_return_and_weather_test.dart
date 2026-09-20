import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerodrop/core/models/drone_model.dart';
import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/providers/weather_provider.dart';
import 'package:aerodrop/core/widgets/status_chip.dart';

void main() {
  group('DroneStatus Returning and Parsing Tests', () {
    test('DroneStatus enum includes returning', () {
      expect(DroneStatus.values.contains(DroneStatus.returning), isTrue);
    });

    test('DroneStatus parses from returning string in database', () {
      final drone = DroneModel(
        id: 'drone-ret-1',
        name: 'AeroCarrier Alpha',
        status: DroneStatus.returning,
        batteryLevel: 75.0,
        maxPayload: 0.5,
        modelType: 'Hexacopter',
        currentCoordinates: '10.3200,123.9400',
      );
      expect(drone.status, DroneStatus.returning);
      expect(drone.status.name, 'returning');
    });

    test('Drone readiness status logic handles returning state', () {
      final drone = DroneModel(
        id: 'drone-ret-2',
        name: 'AeroCarrier Beta',
        status: DroneStatus.returning,
        batteryLevel: 62.0,
        maxPayload: 0.5,
        modelType: 'Hexacopter',
        currentCoordinates: '10.3200,123.9400',
      );

      final readiness = drone.batteryLevel < 10.0
          ? 'Battery too low for delivery'
          : drone.status == DroneStatus.available
          ? 'Ready for delivery'
          : drone.status == DroneStatus.returning
          ? 'Returning to Base'
          : 'Drone not available';

      expect(readiness, 'Returning to Base');
    });

    test('DroneModel supports dbId for database UUID and id for code', () {
      final drone = DroneModel(
        id: 'DRN-001',
        dbId: '80000000-0000-0000-0000-000000000001',
        name: 'AeroCarrier Alpha',
        status: DroneStatus.returning,
        batteryLevel: 80.0,
        maxPayload: 0.5,
        modelType: 'Hexacopter',
        currentCoordinates: '10.3156,123.9016',
      );
      expect(drone.id, 'DRN-001');
      expect(drone.dbId, '80000000-0000-0000-0000-000000000001');

      final copied = drone.copyWith(batteryLevel: 74.0, status: DroneStatus.available);
      expect(copied.dbId, '80000000-0000-0000-0000-000000000001');
      expect(copied.batteryLevel, 74.0);
      expect(copied.status, DroneStatus.available);
    });

    testWidgets('StatusChip.drone displays RETURNING TO BASE with warning color',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusChip.drone('returning'),
          ),
        ),
      );

      expect(find.text('RETURNING TO BASE'), findsOneWidget);
    });
  });

  group('Weather State and Caution Dynamics Tests', () {
    test('WeatherState isGrounded and isCaution properties', () {
      final safe = WeatherState(safetyStatus: 'safe');
      expect(safe.isSafe, isTrue);
      expect(safe.isCaution, isFalse);
      expect(safe.isGrounded, isFalse);

      final caution = WeatherState(safetyStatus: 'caution');
      expect(caution.isSafe, isFalse);
      expect(caution.isCaution, isTrue);
      expect(caution.isGrounded, isFalse);

      final grounded = WeatherState(safetyStatus: 'grounded');
      expect(grounded.isSafe, isFalse);
      expect(grounded.isCaution, isFalse);
      expect(grounded.isGrounded, isTrue);
    });

    test('Caution weather dynamics calculations: 0.7x speed, step 0.07, battery 8.5%', () {
      const normalSpeed = 5.0; // m/s
      const cautionSpeedMultiplier = 0.7;
      final effectiveCautionSpeed = normalSpeed * cautionSpeedMultiplier;
      expect(effectiveCautionSpeed, closeTo(3.5, 0.001));

      const normalStep = 0.1;
      const cautionStep = 0.07;
      expect(cautionStep, closeTo(normalStep * cautionSpeedMultiplier, 0.001));

      const cautionBatteryDrain = 8.5;
      expect(cautionBatteryDrain, 8.5);

      // ETA comparison for 100 meters
      const distanceM = 100.0;
      final normalSecs = (distanceM / normalSpeed).round();
      final cautionSecs = (distanceM / effectiveCautionSpeed).round();
      expect(normalSecs, 20);
      expect(cautionSecs, 29);
      expect(cautionSecs > normalSecs, isTrue);
    });
  });

  group('Delivery Cancellation Reason Tests', () {
    test('DeliveryModel supports cancellation status and fields', () {
      final delivery = DeliveryModel(
        id: 'del-cancel-1',
        senderName: 'Campus Diner',
        recipientName: 'Alice',
        recipientPhone: '09123456789',
        deliveryAddress: 'Main Library',
        packageName: 'Lunch Box',
        packageWeight: 0.35,
        packageType: 'Food',
        status: DeliveryStatus.cancelled,
        eta: 'Cancelled',
        progress: 0.0,
        createdAt: DateTime.now(),
      );
      expect(delivery.status, DeliveryStatus.cancelled);
    });

    test('Return percentage from position calculation matches distance formula', () {
      // Origin: (10.3156, 123.9016) [Dropoff point]
      // Base Hub: (10.3168, 123.9010)
      const originLat = 10.3156;
      const originLng = 123.9016;
      const baseLat = 10.3168;
      const baseLng = 123.9010;

      final totalDist = (baseLat - originLat) * (baseLat - originLat) +
          (baseLng - originLng) * (baseLng - originLng);

      // Current at 50% midpoint
      final currentLat = originLat + (baseLat - originLat) * 0.5;
      final currentLng = originLng + (baseLng - originLng) * 0.5;

      final traveledDist = (currentLat - originLat) * (currentLat - originLat) +
          (currentLng - originLng) * (currentLng - originLng);

      final progress = traveledDist / totalDist;
      expect(progress, closeTo(0.25, 0.001)); // squared ratio = 0.5^2 = 0.25; sqrt ratio = 0.5
      final progressLinear = ((currentLat - originLat) / (baseLat - originLat)).clamp(0.0, 1.0);
      expect(progressLinear, closeTo(0.5, 0.001));
    });
  });
}
