import 'delivery_model.dart';
import 'drone_model.dart';

/// What the drone is doing for one delivery right now.
///
/// Every flight label, badge and header is derived from this, so a tracking
/// header and a radar badge looking at the same moment cannot disagree.
enum FlightPhase {
  standby,
  headingToPickup,

  /// Parked at the vendor between trips of a multi-trip order.
  atVendor,
  delivering,

  /// Flying customer -> vendor between trips of a multi-trip order.
  returningToVendor,

  /// Flying home after the last (or only) trip.
  returningToBase,
  delivered,
}

/// Resolves the phase from the delivery, the drone's status and the latest
/// telemetry event.
///
/// The drone status arrives over realtime and is trusted over the telemetry
/// event, which is only the LAST point written and can be a leg behind: after
/// the shuttle lands at the vendor, the newest telemetry still says
/// 'returning_to_base' until the next leg writes its first point.
///
/// Invariant: [FlightPhase.returningToBase] is never returned while the
/// delivery still owes a trip.
FlightPhase resolveFlightPhase({
  DeliveryModel? delivery,
  DroneStatus? droneStatus,
  String? telemetryEvent,
}) {
  final droneReturning = droneStatus != null
      ? droneStatus == DroneStatus.returning
      : telemetryEvent == 'returning_to_base';

  final d = delivery;
  if (d == null) {
    return droneReturning ? FlightPhase.returningToBase : FlightPhase.standby;
  }

  final tripsOwed = d.returnLegHeadsToVendor;

  switch (d.status) {
    case DeliveryStatus.assigning:
      // Between trips, arrive_at_vendor_for_next_trip parks the delivery
      // here at full progress; otherwise the drone is flying out to pickup
      return tripsOwed && d.progress >= 1.0
          ? FlightPhase.atVendor
          : FlightPhase.headingToPickup;
    case DeliveryStatus.inTransit:
      // Between trips with the drone home and idle: the next trip was refused
      // (weather or battery) and the order is waiting at base, not flying
      if (tripsOwed && droneStatus == DroneStatus.available) {
        return FlightPhase.standby;
      }
      if (!droneReturning) return FlightPhase.delivering;
      return tripsOwed
          ? FlightPhase.returningToVendor
          : FlightPhase.returningToBase;
    case DeliveryStatus.delivered:
      return droneReturning
          ? FlightPhase.returningToBase
          : FlightPhase.delivered;
    case DeliveryStatus.pending:
    case DeliveryStatus.cancelled:
      return droneReturning ? FlightPhase.returningToBase : FlightPhase.standby;
  }
}

/// "load N of M" for the load being collected next, between trips.
String nextLoadLabel(DeliveryModel d) =>
    'load ${d.tripsCompleted + 1} of ${d.tripsRequired}';
