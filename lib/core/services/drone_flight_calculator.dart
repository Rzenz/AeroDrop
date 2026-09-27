import 'package:latlong2/latlong.dart';

/// Authoritative calculator for realistic drone flight physics, flight duration,
/// payload penalties, and battery drain.
class DroneFlightCalculator {
  // Drone physical constraints
  static const double maxPayloadKg = 0.5; // Max cargo capacity for fleet (DRN-001)
  static const double baseSpeed = 5.0; // Base cruise speed in m/s (~18 km/h)
  static const double baseDrainNormal = 6.0; // Base battery drain % per leg
  static const double baseDrainCaution = 8.5; // Base battery drain % in caution weather
  static const double weatherCautionSpeedFactor = 0.7; // Speed multiplier under caution

  // Simulation timing constraints for watchable demos
  static const double minDurationSeconds = 15.0; // Minimum leg duration
  static const double maxDurationSeconds = 60.0; // Maximum leg duration
  static const double tickSeconds = 3.0; // Simulation timer periodic interval (seconds)

  static const Distance _distance = Distance();

  /// Calculates geographic distance between two points in meters using Haversine.
  static double calculateDistanceMeters({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    return _distance.as(
      LengthUnit.Meter,
      LatLng(startLat, startLng),
      LatLng(endLat, endLng),
    );
  }

  /// Extracts and sums total payload weight in kilograms from order items,
  /// capped at [maxPayloadKg] (0.5 kg).
  static double calculatePayloadKg(List<dynamic>? orderItems) {
    if (orderItems == null || orderItems.isEmpty) return 0.0;
    int totalWeightGrams = 0;
    for (final item in orderItems) {
      if (item is Map) {
        final w = (item['weight_grams'] as num?)?.toInt() ?? 0;
        final q = (item['quantity'] as num?)?.toInt() ?? 1;
        totalWeightGrams += w * q;
      }
    }
    final kg = totalWeightGrams / 1000.0;
    return kg.clamp(0.0, maxPayloadKg);
  }

  /// Calculates effective drone speed for a leg:
  /// - Leg 1 (hub -> vendor) and Leg 3 (customer -> base) are EMPTY: [isLoaded] = false.
  /// - Leg 2 (vendor -> customer) is LOADED: [isLoaded] = true.
  ///   speed = baseSpeed * (1 - 0.20 * payloadRatio)
  ///   where payloadRatio = payload / max_payload_kg (capped at 1.0).
  /// - Weather Caution applies on top (0.7x speed).
  static double calculateEffectiveSpeed({
    required bool isLoaded,
    double payloadKg = 0.0,
    bool isCaution = false,
  }) {
    final payload = isLoaded ? payloadKg.clamp(0.0, maxPayloadKg) : 0.0;
    final payloadRatio = (payload / maxPayloadKg).clamp(0.0, 1.0);
    final loadedSpeed = baseSpeed * (1.0 - 0.20 * payloadRatio);
    final weatherFactor = isCaution ? weatherCautionSpeedFactor : 1.0;
    return loadedSpeed * weatherFactor;
  }

  /// Calculates total battery drain percentage for a leg:
  /// - Empty legs (Leg 1 & Leg 3): payloadRatio = 0 -> drain = baseDrain.
  /// - Loaded leg (Leg 2): drain = baseDrain * (1 + 0.40 * payloadRatio).
  /// - Weather Caution increases base drain to 8.5% (vs 6.0% normal).
  static double calculateBatteryDrain({
    required bool isLoaded,
    double payloadKg = 0.0,
    bool isCaution = false,
  }) {
    final baseDrain = isCaution ? baseDrainCaution : baseDrainNormal;
    final payload = isLoaded ? payloadKg.clamp(0.0, maxPayloadKg) : 0.0;
    final payloadRatio = (payload / maxPayloadKg).clamp(0.0, 1.0);
    return baseDrain * (1.0 + 0.40 * payloadRatio);
  }

  /// Computes flight duration in seconds from distance and effective speed,
  /// clamped between [minDurationSeconds] (15s) and [maxDurationSeconds] (60s).
  static double calculateDurationSeconds({
    required double distanceMeters,
    required double effectiveSpeed,
  }) {
    if (effectiveSpeed <= 0) return maxDurationSeconds;
    final rawDuration = distanceMeters / effectiveSpeed;
    return rawDuration.clamp(minDurationSeconds, maxDurationSeconds);
  }

  /// Calculates progress increment per simulation tick (3 seconds / duration).
  static double calculateProgressStep({
    required double durationSeconds,
    double currentTickSeconds = tickSeconds,
  }) {
    if (durationSeconds <= 0) return 1.0;
    return currentTickSeconds / durationSeconds;
  }

  /// Computes remaining seconds of flight for a leg based on current progress [0.0, 1.0].
  static int calculateRemainingSeconds({
    required double progress,
    required double totalDurationSeconds,
  }) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress >= 1.0) return 0;
    return ((1.0 - clampedProgress) * totalDurationSeconds).round();
  }

  /// Formats remaining seconds into a user-friendly ETA string.
  static String formatEta(int remainingSeconds) {
    if (remainingSeconds <= 0) return '0 mins';
    if (remainingSeconds < 60) return '$remainingSeconds secs';
    return '${(remainingSeconds / 60).ceil()} mins';
  }
}
