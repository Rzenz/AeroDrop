import 'package:flutter_test/flutter_test.dart';
import 'package:aerodrop/core/services/drone_flight_calculator.dart';

void main() {
  group('DroneFlightCalculator Unit Tests', () {
    test('1. Distance-based duration: calculates proportional duration based on real distance', () {
      // 200m at 5.0 m/s should take exactly 40.0s
      final duration200m = DroneFlightCalculator.calculateDurationSeconds(
        distanceMeters: 200.0,
        effectiveSpeed: 5.0,
      );
      expect(duration200m, closeTo(40.0, 0.001));

      // 100m at 5.0 m/s should take exactly 20.0s
      final duration100m = DroneFlightCalculator.calculateDurationSeconds(
        distanceMeters: 100.0,
        effectiveSpeed: 5.0,
      );
      expect(duration100m, closeTo(20.0, 0.001));

      // 150m at loaded 4.0 m/s should take 37.5s
      final durationLoaded = DroneFlightCalculator.calculateDurationSeconds(
        distanceMeters: 150.0,
        effectiveSpeed: 4.0,
      );
      expect(durationLoaded, closeTo(37.5, 0.001));

      // Haversine distance between UCLM Main (10.325210, 123.953201) and Maritime (10.326184, 123.954843)
      final distanceMainToMaritime = DroneFlightCalculator.calculateDistanceMeters(
        startLat: 10.325210,
        startLng: 123.953201,
        endLat: 10.326184,
        endLng: 123.954843,
      );
      expect(distanceMainToMaritime, closeTo(210.0, 2.0));

      final durationMainToMaritime = DroneFlightCalculator.calculateDurationSeconds(
        distanceMeters: distanceMainToMaritime,
        effectiveSpeed: 5.0,
      );
      expect(durationMainToMaritime, closeTo(42.0, 0.5));
    });

    test('2. Empty vs loaded leg speed: applies 20% payload penalty only to loaded legs', () {
      // Empty leg (Leg 1 & Leg 3): no penalty regardless of payloadKg passed
      final emptySpeedNormal = DroneFlightCalculator.calculateEffectiveSpeed(
        isLoaded: false,
        payloadKg: 0.5,
        isCaution: false,
      );
      expect(emptySpeedNormal, closeTo(5.0, 0.001));

      final emptySpeedCaution = DroneFlightCalculator.calculateEffectiveSpeed(
        isLoaded: false,
        payloadKg: 0.5,
        isCaution: true,
      );
      expect(emptySpeedCaution, closeTo(3.5, 0.001));

      // Loaded leg (Leg 2): 0 payload -> full 5.0 m/s
      final loadedZeroPayload = DroneFlightCalculator.calculateEffectiveSpeed(
        isLoaded: true,
        payloadKg: 0.0,
        isCaution: false,
      );
      expect(loadedZeroPayload, closeTo(5.0, 0.001));

      // Loaded leg (Leg 2): half payload (0.25 kg = 50% max) -> 10% penalty -> 4.5 m/s
      final loadedHalfPayload = DroneFlightCalculator.calculateEffectiveSpeed(
        isLoaded: true,
        payloadKg: 0.25,
        isCaution: false,
      );
      expect(loadedHalfPayload, closeTo(4.5, 0.001));

      // Loaded leg (Leg 2): max payload (0.5 kg = 100% max) -> 20% penalty -> 4.0 m/s
      final loadedMaxPayload = DroneFlightCalculator.calculateEffectiveSpeed(
        isLoaded: true,
        payloadKg: 0.5,
        isCaution: false,
      );
      expect(loadedMaxPayload, closeTo(4.0, 0.001));

      // Loaded leg (Leg 2) under weather caution: 4.0 m/s * 0.7 = 2.8 m/s
      final loadedMaxCaution = DroneFlightCalculator.calculateEffectiveSpeed(
        isLoaded: true,
        payloadKg: 0.5,
        isCaution: true,
      );
      expect(loadedMaxCaution, closeTo(2.8, 0.001));

      // Verify empty speed is strictly greater than loaded speed with max payload
      expect(emptySpeedNormal, greaterThan(loadedMaxPayload));
      expect(emptySpeedCaution, greaterThan(loadedMaxCaution));
    });

    test('3. Payload battery drain: applies 40% drain penalty to loaded leg and higher drain in caution', () {
      // Empty leg: baseline drain
      final emptyDrainNormal = DroneFlightCalculator.calculateBatteryDrain(
        isLoaded: false,
        payloadKg: 0.5,
        isCaution: false,
      );
      expect(emptyDrainNormal, closeTo(6.0, 0.001));

      final emptyDrainCaution = DroneFlightCalculator.calculateBatteryDrain(
        isLoaded: false,
        payloadKg: 0.5,
        isCaution: true,
      );
      expect(emptyDrainCaution, closeTo(8.5, 0.001));

      // Loaded leg with 0 kg payload
      final loadedDrainZero = DroneFlightCalculator.calculateBatteryDrain(
        isLoaded: true,
        payloadKg: 0.0,
        isCaution: false,
      );
      expect(loadedDrainZero, closeTo(6.0, 0.001));

      // Loaded leg with half payload (0.25 kg): 6.0 * (1 + 0.40 * 0.5) = 7.2%
      final loadedDrainHalf = DroneFlightCalculator.calculateBatteryDrain(
        isLoaded: true,
        payloadKg: 0.25,
        isCaution: false,
      );
      expect(loadedDrainHalf, closeTo(7.2, 0.001));

      // Loaded leg with max payload (0.5 kg): 6.0 * (1 + 0.40 * 1.0) = 8.4%
      final loadedDrainMax = DroneFlightCalculator.calculateBatteryDrain(
        isLoaded: true,
        payloadKg: 0.5,
        isCaution: false,
      );
      expect(loadedDrainMax, closeTo(8.4, 0.001));

      // Loaded leg with max payload under caution: 8.5 * (1 + 0.40) = 11.9%
      final loadedDrainCaution = DroneFlightCalculator.calculateBatteryDrain(
        isLoaded: true,
        payloadKg: 0.5,
        isCaution: true,
      );
      expect(loadedDrainCaution, closeTo(11.9, 0.001));

      // Verify loaded drain is strictly higher than empty drain
      expect(loadedDrainMax, greaterThan(emptyDrainNormal));
      expect(loadedDrainCaution, greaterThan(emptyDrainCaution));
    });

    test('4. Min/max clamps: enforces 15s min and 60s max durations and clamps payload capacity', () {
      // Super short leg (e.g. 18m between Base Hub and Main Building: 18m / 5m/s = 3.6s raw)
      final shortDuration = DroneFlightCalculator.calculateDurationSeconds(
        distanceMeters: 18.0,
        effectiveSpeed: 5.0,
      );
      expect(shortDuration, equals(15.0), reason: 'Must clamp to 15.0s minimum');

      // Zero distance leg clamps to 15.0s
      final zeroDuration = DroneFlightCalculator.calculateDurationSeconds(
        distanceMeters: 0.0,
        effectiveSpeed: 5.0,
      );
      expect(zeroDuration, equals(15.0), reason: '0m distance must clamp to 15.0s minimum');

      // Extremely long distance (e.g. 500m / 5m/s = 100s raw)
      final longDuration = DroneFlightCalculator.calculateDurationSeconds(
        distanceMeters: 500.0,
        effectiveSpeed: 5.0,
      );
      expect(longDuration, equals(60.0), reason: 'Must clamp to 60.0s maximum');

      // Progress step for 15s duration: 3.0 / 15.0 = 0.20
      final stepShort = DroneFlightCalculator.calculateProgressStep(durationSeconds: 15.0);
      expect(stepShort, closeTo(0.20, 0.001));

      // Progress step for 60s duration: 3.0 / 60.0 = 0.05
      final stepLong = DroneFlightCalculator.calculateProgressStep(durationSeconds: 60.0);
      expect(stepLong, closeTo(0.05, 0.001));

      // Payload cap: payload exceeding 0.5 kg (e.g. 1.5 kg) is capped at 0.5 kg
      final itemsExceeding = [
        {'weight_grams': 500, 'quantity': 3},
      ];
      final cappedPayload = DroneFlightCalculator.calculatePayloadKg(itemsExceeding);
      expect(cappedPayload, equals(0.5));

      final speedOverweight = DroneFlightCalculator.calculateEffectiveSpeed(
        isLoaded: true,
        payloadKg: 2.0,
      );
      expect(speedOverweight, equals(4.0), reason: 'Overweight payload ratio capped at 1.0 (4.0 m/s)');

      // Negative payload clamp
      final speedNegative = DroneFlightCalculator.calculateEffectiveSpeed(
        isLoaded: true,
        payloadKg: -0.5,
      );
      expect(speedNegative, equals(5.0));

      // ETA remaining seconds and formatting
      expect(DroneFlightCalculator.calculateRemainingSeconds(progress: 0.0, totalDurationSeconds: 40.0), equals(40));
      expect(DroneFlightCalculator.calculateRemainingSeconds(progress: 0.5, totalDurationSeconds: 40.0), equals(20));
      expect(DroneFlightCalculator.calculateRemainingSeconds(progress: 1.0, totalDurationSeconds: 40.0), equals(0));
      expect(DroneFlightCalculator.formatEta(40), equals('40 secs'));
      expect(DroneFlightCalculator.formatEta(75), equals('2 mins'));
      expect(DroneFlightCalculator.formatEta(0), equals('0 mins'));
    });
  });
}
