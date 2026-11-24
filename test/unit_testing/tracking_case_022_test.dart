import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/models/drone_model.dart';
import 'package:aerodrop/core/models/flight_phase.dart';
import 'package:flutter_test/flutter_test.dart';

DeliveryModel _delivery(DeliveryStatus status, double progress) => DeliveryModel(
  id: 'del-18e40ba9',
  senderName: 'Kape Kanto',
  recipientName: 'Maria Santos',
  recipientPhone: '+639171234567',
  deliveryAddress: 'UCLM Maritime Building',
  packageName: 'Iced Spanish Latte (x1)',
  packageWeight: 0.38,
  packageType: 'Food',
  status: status,
  eta: 'TBD',
  createdAt: DateTime(2026, 11, 17),
  progress: progress,
);

void main() {
  group('Test Case ID: CASE-022', () {
    test(
      'Test Case Description: Customer tracks an order the drone has picked up and is flying to the Maritime Building | '
      'Expected Result: Tracking shows the drone delivering (in flight) until the package lands, then delivered',
      () {
        expect(
          resolveFlightPhase(delivery: _delivery(DeliveryStatus.assigning, 0.3), droneStatus: DroneStatus.busy),
          FlightPhase.headingToPickup,
        );
        expect(
          resolveFlightPhase(delivery: _delivery(DeliveryStatus.inTransit, 0.69), droneStatus: DroneStatus.busy),
          FlightPhase.delivering,
        );
        expect(
          resolveFlightPhase(delivery: _delivery(DeliveryStatus.delivered, 1.0), droneStatus: DroneStatus.busy),
          FlightPhase.delivered,
        );
      },
    );
  });
}
