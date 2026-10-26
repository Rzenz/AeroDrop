import 'package:flutter_test/flutter_test.dart';
import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/models/drone_model.dart';
import 'package:aerodrop/core/models/flight_phase.dart';

DeliveryModel _delivery({
  required DeliveryStatus status,
  double progress = 0.0,
  int tripsRequired = 1,
  int tripsCompleted = 0,
}) => DeliveryModel(
  id: 'd1',
  senderName: 'Vendor',
  recipientName: 'Customer',
  recipientPhone: '',
  deliveryAddress: 'Annex 2',
  packageName: 'Package',
  packageWeight: 0.8,
  packageType: 'Food',
  status: status,
  eta: 'TBD',
  createdAt: DateTime(2026),
  progress: progress,
  tripsRequired: tripsRequired,
  tripsCompleted: tripsCompleted,
);

void main() {
  group('resolveFlightPhase', () {
    test('single-trip order flying home after delivery: returning to base', () {
      expect(
        resolveFlightPhase(
          delivery: _delivery(status: DeliveryStatus.delivered, tripsCompleted: 1),
          droneStatus: DroneStatus.returning,
        ),
        FlightPhase.returningToBase,
      );
    });

    test('multi-trip, customer -> vendor between trips: returning to vendor', () {
      expect(
        resolveFlightPhase(
          delivery: _delivery(
            status: DeliveryStatus.inTransit,
            tripsRequired: 2,
            tripsCompleted: 1,
          ),
          droneStatus: DroneStatus.returning,
          telemetryEvent: 'returning_to_base',
        ),
        FlightPhase.returningToVendor,
      );
    });

    test('multi-trip, parked at vendor: at vendor, even with stale telemetry '
        'and the drone not yet updated to assigned', () {
      final parked = _delivery(
        status: DeliveryStatus.assigning,
        progress: 1.0,
        tripsRequired: 2,
        tripsCompleted: 1,
      );
      for (final drone in [DroneStatus.returning, DroneStatus.assigned]) {
        expect(
          resolveFlightPhase(
            delivery: parked,
            droneStatus: drone,
            telemetryEvent: 'returning_to_base',
          ),
          FlightPhase.atVendor,
        );
      }
      expect(nextLoadLabel(parked), 'load 2 of 2');
    });

    test('multi-trip, second loaded leg with stale return telemetry: '
        'delivering, not returning', () {
      expect(
        resolveFlightPhase(
          delivery: _delivery(
            status: DeliveryStatus.inTransit,
            tripsRequired: 2,
            tripsCompleted: 1,
          ),
          droneStatus: DroneStatus.assigned,
          telemetryEvent: 'returning_to_base',
        ),
        FlightPhase.delivering,
      );
    });

    test('multi-trip, final leg home after the last trip: returning to base', () {
      expect(
        resolveFlightPhase(
          delivery: _delivery(
            status: DeliveryStatus.delivered,
            tripsRequired: 2,
            tripsCompleted: 2,
          ),
          droneStatus: DroneStatus.returning,
        ),
        FlightPhase.returningToBase,
      );
    });

    test('never returning to base while a trip is owed', () {
      for (final status in [
        DeliveryStatus.assigning,
        DeliveryStatus.inTransit,
      ]) {
        for (final drone in [...DroneStatus.values, null]) {
          for (final event in ['returning_to_base', 'in_flight', null]) {
            for (final progress in [0.0, 0.5, 1.0]) {
              expect(
                resolveFlightPhase(
                  delivery: _delivery(
                    status: status,
                    progress: progress,
                    tripsRequired: 2,
                    tripsCompleted: 1,
                  ),
                  droneStatus: drone,
                  telemetryEvent: event,
                ),
                isNot(FlightPhase.returningToBase),
                reason: '$status / $drone / $event / $progress',
              );
            }
          }
        }
      }
    });
  });
}
