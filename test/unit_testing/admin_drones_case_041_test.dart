import 'package:aerodrop/core/models/drone_model.dart';
import 'package:aerodrop/core/providers/drone_provider.dart';
import 'package:aerodrop/core/providers/settings_provider.dart';
import 'package:aerodrop/features/admin/admin_drones_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fakes.dart';
import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-041', () {
    testWidgets(
      'Test Case Description: Admin opens Fleet Management while DRN-001 (85% battery) is out on a delivery | '
      "Expected Result: AeroCarrier Alpha is listed as busy with 85% battery and marked 'Drone not available'",
      (tester) async {
        await pumpScreen(
          tester,
          const AdminDronesScreen(),
          overrides: [
            droneProvider.overrideWith((ref) => FakeDrones([
              DroneModel(id: 'DRN-001', name: 'AeroCarrier Alpha', batteryLevel: 85, status: DroneStatus.busy, maxPayload: 0.5, modelType: 'Prototype 001', currentCoordinates: '10.3252, 123.9534'),
            ])),
            lowBatteryAlertsProvider.overrideWith((ref) => FakeLowBattery()),
          ],
          size: const Size(600, 1400),
        );

        expect(find.text('AeroCarrier Alpha'), findsOneWidget);
        expect(find.text('85%'), findsWidgets);
        expect(find.text('Drone not available'), findsOneWidget);
      },
    );
  });
}
