import 'drone_flight_calculator.dart';

/// Structured single row item of a delivery fee breakdown.
class DeliveryFeeRow {
  final String label;
  final double amount;

  const DeliveryFeeRow(this.label, this.amount);

  @override
  String toString() => '$label: ₱${amount.toStringAsFixed(2)}';
}

/// Structured breakdown of calculated order delivery fee.
class DeliveryFeeBreakdown {
  final double baseFee;
  final double distanceKm;
  final double distanceFee;
  final double weightKg;
  final double weightFee;
  final double weatherFee;
  final double totalFee;
  final String breakdownText;

  const DeliveryFeeBreakdown({
    required this.baseFee,
    required this.distanceKm,
    required this.distanceFee,
    required this.weightKg,
    required this.weightFee,
    required this.weatherFee,
    required this.totalFee,
    required this.breakdownText,
  });

  /// Breakdown rows matching receipt and checkout specifications:
  /// - Base: ₱15.00
  /// - Distance: ₱XX.XX (if > 0)
  /// - Weight: ₱XX.XX (if > 0)
  /// - Weather surcharge: ₱5.00 (only when caution fee applied)
  List<DeliveryFeeRow> get breakdownRows {
    final rows = <DeliveryFeeRow>[
      DeliveryFeeRow('Base', baseFee),
    ];
    if (distanceKm > 0 || distanceFee > 0) {
      rows.add(
        DeliveryFeeRow('Distance ${distanceKm.toStringAsFixed(2)} km', distanceFee),
      );
    }
    if (weightKg > 0 || weightFee > 0) {
      rows.add(
        DeliveryFeeRow('Weight ${weightKg.toStringAsFixed(2)} kg', weightFee),
      );
    }
    if (weatherFee > 0) {
      rows.add(
        DeliveryFeeRow('Weather surcharge', weatherFee),
      );
    }
    return rows;
  }

  @override
  String toString() =>
      'DeliveryFeeBreakdown(total: ₱$totalFee, breakdown: $breakdownText)';
}

/// Unified authoritative delivery fee calculator for AeroDrop customer checkout
/// and custom delivery requests.
class DeliveryFeeCalculator {
  // Order checkout fee parameters
  static const double baseFee = 15.0; // Base flat fee (PHP)
  static const double distanceRatePerKm = 40.0; // PHP 40.00 per kilometer
  static const double weightRatePerKg = 10.0; // PHP 10.00 per kilogram
  static const double maxPayloadKg = 0.5; // Drone max capacity cap (0.5 kg)
  static const double weatherCautionSurcharge = 5.0; // PHP 5.00 caution fee

  /// Calculates the distance-based delivery fee for customer checkout orders:
  /// - Base: ₱15.00
  /// - Distance: ₱40.00 / km (using real Haversine distance, 0 if same building or missing coords)
  /// - Weight: ₱10.00 / kg of payload (capped at drone max 0.5 kg)
  /// - Weather: +₱5.00 when weather is caution
  /// - Rounded to 2 decimals, never below base fee (₱15.00)
  static DeliveryFeeBreakdown calculateOrderFee({
    double? distanceKm,
    double weightKg = 0.0,
    bool isCaution = false,
  }) {
    // Distance fee (missing or near-zero distance defaults to 0)
    final double dist = (distanceKm != null && distanceKm > 0.005) ? distanceKm : 0.0;
    final double distFee = double.parse((dist * distanceRatePerKm).toStringAsFixed(2));

    // Weight fee (capped at max drone payload 0.5 kg)
    final double cappedWeight = weightKg.clamp(0.0, maxPayloadKg);
    final double wFee = double.parse((cappedWeight * weightRatePerKg).toStringAsFixed(2));

    // Weather fee (+₱5.00 for caution weather)
    final double weaFee = isCaution ? weatherCautionSurcharge : 0.0;

    // Total fee, never below base fee
    final double rawTotal = baseFee + distFee + wFee + weaFee;
    final double total = double.parse(
      (rawTotal < baseFee ? baseFee : rawTotal).toStringAsFixed(2),
    );

    // Build short breakdown text: e.g. "Base ₱15.00 + Distance 0.21 km ₱8.40 + Weight 0.32 kg ₱3.20"
    final parts = <String>[
      'Base ₱${baseFee.toStringAsFixed(2)}',
    ];
    if (dist > 0) {
      parts.add('Distance ${dist.toStringAsFixed(2)} km ₱${distFee.toStringAsFixed(2)}');
    }
    if (cappedWeight > 0) {
      parts.add('Weight ${cappedWeight.toStringAsFixed(2)} kg ₱${wFee.toStringAsFixed(2)}');
    }
    if (weaFee > 0) {
      parts.add('Weather ₱${weaFee.toStringAsFixed(2)}');
    }

    final breakdown = parts.join(' + ');

    return DeliveryFeeBreakdown(
      baseFee: baseFee,
      distanceKm: dist,
      distanceFee: distFee,
      weightKg: cappedWeight,
      weightFee: wFee,
      weatherFee: weaFee,
      totalFee: total,
      breakdownText: breakdown,
    );
  }

  /// Recomputes fee breakdown from stored order data (stored delivery_fee, distance, weight).
  ///
  /// Reconciles against the charged delivery fee:
  /// - Tests if normal fee (base + distance + weight) matches stored fee.
  /// - If stored fee exceeds base + distance + weight by the weather caution surcharge
  ///   (+₱5.00), weather surcharge is included.
  /// - If the parts do not reconcile with the stored fee (e.g. vendor changed locations),
  ///   returns null so callers can fall back to the stored single total without displaying
  ///   conflicting numbers. Never alters the stored total.
  // ponytail: Recomputation relies on stored order weight, vendor & dropoff coords.
  // Ceilings: If coords changed since order placement, falls back gracefully to null (single total line).
  static DeliveryFeeBreakdown? recomputeStoredOrderFee({
    required double storedDeliveryFee,
    double? distanceKm,
    double weightKg = 0.0,
  }) {
    // 1. Check normal order fee (no weather surcharge)
    final normal = calculateOrderFee(
      distanceKm: distanceKm,
      weightKg: weightKg,
      isCaution: false,
    );
    if ((normal.totalFee - storedDeliveryFee).abs() < 0.01) {
      return normal;
    }

    // 2. Check if caution surcharge was applied at order time (+₱5.00)
    final withCaution = calculateOrderFee(
      distanceKm: distanceKm,
      weightKg: weightKg,
      isCaution: true,
    );
    if ((withCaution.totalFee - storedDeliveryFee).abs() < 0.01) {
      return withCaution;
    }

    // 3. Fallback: Does not reconcile with stored fee
    return null;
  }

  /// Calculates geodesic distance in kilometers between two points using DroneFlightCalculator.
  /// Returns null if any coordinate is missing or invalid (0, 0).
  static double? calculateDistanceKm({
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
  }) {
    if (startLat == null || startLng == null || endLat == null || endLng == null) {
      return null;
    }
    if ((startLat == 0.0 && startLng == 0.0) || (endLat == 0.0 && endLng == 0.0)) {
      return null;
    }

    final meters = DroneFlightCalculator.calculateDistanceMeters(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );
    return meters / 1000.0;
  }

  /// Fee calculation for custom peer-to-peer package delivery requests.
  static double calculateCustomDeliveryFee({
    required double estimatedDistanceKm,
    required double packageWeightKg,
    required String packageType,
    required String priority,
  }) {
    const base = 20.0;
    final distFee = estimatedDistanceKm * 100.0;
    final wFee = packageWeightKg * 20.0;

    double itemFee = 5.0;
    switch (packageType) {
      case 'Documents':
        itemFee = 0.0;
        break;
      case 'Medicine':
      case 'Food':
      case 'Other':
        itemFee = 5.0;
        break;
      case 'Electronics':
        itemFee = 10.0;
        break;
    }

    double priorityFee = 0.0;
    switch (_normalizePriority(priority)) {
      case 'Standard':
        priorityFee = 0.0;
        break;
      case 'Express':
        priorityFee = 10.0;
        break;
      case 'Scheduled':
        priorityFee = 5.0;
        break;
    }

    final raw = base + distFee + wFee + itemFee + priorityFee;
    return double.parse(raw.toStringAsFixed(2));
  }

  static String _normalizePriority(String p) {
    final lower = p.toLowerCase();
    if (lower.contains('express')) return 'Express';
    if (lower.contains('sched')) return 'Scheduled';
    return 'Standard';
  }
}
