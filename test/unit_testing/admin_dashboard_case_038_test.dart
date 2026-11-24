import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/models/drone_model.dart';
import 'package:aerodrop/core/providers/delivery_provider.dart';
import 'package:aerodrop/core/providers/drone_provider.dart';
import 'package:aerodrop/core/providers/notification_provider.dart';
import 'package:aerodrop/core/providers/settings_provider.dart';
import 'package:aerodrop/core/providers/telemetry_provider.dart';
import 'package:aerodrop/core/providers/weather_provider.dart';
import 'package:aerodrop/features/admin/admin_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fakes.dart';
import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-038', () {
    testWidgets(
      'Test Case Description: Admin opens the Command Deck with drone DRN-001 delivering an order | '
      "Expected Result: The dashboard shows 'Campus Fleet Active', the active flight and the delivery in progress",
      (tester) async {
        await pumpScreen(
          tester,
          const AdminDashboardScreen(),
          overrides: [
            deliveryProvider.overrideWith((ref) => FakeDeliveries([delivery('18e40ba9-0000-4000-a000-000000000001', DeliveryStatus.inTransit)])),
            droneProvider.overrideWith((ref) => FakeDrones([
              DroneModel(id: 'DRN-001', name: 'AeroCarrier Alpha', batteryLevel: 85, status: DroneStatus.busy, maxPayload: 0.5, modelType: 'Prototype 001', currentCoordinates: '10.3252, 123.9534'),
            ])),
            fleetTelemetryProvider.overrideWith((ref) => FakeFleetTelemetry()),
            deliveryTelemetryProvider.overrideWith((ref, id) => FakeDeliveryTelemetry()),
            lowBatteryAlertsProvider.overrideWith((ref) => FakeLowBattery()),
            weatherProvider.overrideWith((ref) => FakeWeather(safeWeather())),
            unreadNotificationCountProvider.overrideWithValue(0),
          ],
          size: const Size(600, 1400),
        );

        expect(find.text('Command Deck'), findsWidgets);
        expect(find.text('Campus Fleet Active'), findsOneWidget);
        expect(find.text('Active Flights'), findsOneWidget);
        expect(find.textContaining('Delivery in Progress'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      },
    );
  });
}
