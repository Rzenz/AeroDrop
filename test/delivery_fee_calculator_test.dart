import 'package:flutter_test/flutter_test.dart';
import 'package:aerodrop/core/services/delivery_fee_calculator.dart';

void main() {
  group('DeliveryFeeCalculator Unit Tests', () {
    test('1. Distance scaling: scales at PHP 40.00 per km', () {
      // 0.21 km (e.g. Main to Maritime ~210m): 0.21 * 40 = 8.40
      final fee210m = DeliveryFeeCalculator.calculateOrderFee(
        distanceKm: 0.21,
        weightKg: 0.0,
        isCaution: false,
      );
      expect(fee210m.distanceFee, equals(8.40));
      expect(fee210m.totalFee, equals(23.40)); // 15 + 8.40

      // 0.10 km (100m): 0.10 * 40 = 4.00
      final fee100m = DeliveryFeeCalculator.calculateOrderFee(
        distanceKm: 0.10,
        weightKg: 0.0,
        isCaution: false,
      );
      expect(fee100m.distanceFee, equals(4.00));
      expect(fee100m.totalFee, equals(19.00)); // 15 + 4.00

      // 0.078 km (Main to Annex-2 ~78m): 0.078 * 40 = 3.12
      final fee78m = DeliveryFeeCalculator.calculateOrderFee(
        distanceKm: 0.078,
        weightKg: 0.0,
        isCaution: false,
      );
      expect(fee78m.distanceFee, equals(3.12));
      expect(fee78m.totalFee, equals(18.12));
    });

    test('2. Weight: scales at PHP 10.00/kg and caps at 2 trips (1.0 kg)', () {
      // 0.32 kg: 0.32 * 10 = 3.20
      final fee320g = DeliveryFeeCalculator.calculateOrderFee(
        distanceKm: 0.0,
        weightKg: 0.32,
        isCaution: false,
      );
      expect(fee320g.weightKg, equals(0.32));
      expect(fee320g.weightFee, equals(3.20));
      expect(fee320g.totalFee, equals(18.20));

      // 0.50 kg (at maximum): 0.50 * 10 = 5.00
      final feeMax = DeliveryFeeCalculator.calculateOrderFee(
        distanceKm: 0.0,
        weightKg: 0.50,
        isCaution: false,
      );
      expect(feeMax.weightKg, equals(0.50));
      expect(feeMax.weightFee, equals(5.00));
      expect(feeMax.totalFee, equals(20.00));

      // 0.80 kg (two trips): billed on the actual weight -> 8.00
      final feeTwoTrips = DeliveryFeeCalculator.calculateOrderFee(
        distanceKm: 0.0,
        weightKg: 0.80,
        isCaution: false,
        trips: 2,
      );
      expect(feeTwoTrips.weightKg, equals(0.80));
      expect(feeTwoTrips.weightFee, equals(8.00));
      expect(feeTwoTrips.extraTripFee, equals(25.00));
      expect(feeTwoTrips.totalFee, equals(48.00)); // 15 + 8 + 25 extra trip

      // 1.50 kg (beyond 2 trips): capped to 1.00 kg -> 10.00
      final feeOver = DeliveryFeeCalculator.calculateOrderFee(
        distanceKm: 0.0,
        weightKg: 1.50,
        isCaution: false,
      );
      expect(feeOver.weightKg, equals(1.00));
      expect(feeOver.weightFee, equals(10.00));
      expect(feeOver.totalFee, equals(25.00));

      // Combined distance + weight: 0.21 km + 0.32 kg -> Base 15 + 8.40 + 3.20 = 26.60
      final feeCombined = DeliveryFeeCalculator.calculateOrderFee(
        distanceKm: 0.21,
        weightKg: 0.32,
        isCaution: false,
      );
      expect(feeCombined.totalFee, equals(26.60));
      expect(
        feeCombined.breakdownText,
        equals('Base ₱15.00 + Distance 0.21 km ₱8.40 + Weight 0.32 kg ₱3.20'),
      );
    });

    test('2b. Multi-trip: trips from weight, distance charged per trip', () {
      expect(DeliveryFeeCalculator.tripsForWeight(0.0), equals(1));
      expect(DeliveryFeeCalculator.tripsForWeight(0.50), equals(1));
      // Float sums of item weights must not tip exactly 0.5 kg into 2 trips
      expect(DeliveryFeeCalculator.tripsForWeight(0.1 + 0.2 + 0.2), equals(1));
      expect(DeliveryFeeCalculator.tripsForWeight(0.501), equals(2));
      expect(DeliveryFeeCalculator.tripsForWeight(1.00), equals(2));
      // Not clamped: the cart must see an over-limit order
      expect(DeliveryFeeCalculator.tripsForWeight(1.20), equals(3));

      // 0.30 km x 2 trips = 24.00; 0.80 kg = 8.00; caution charged once
      final fee = DeliveryFeeCalculator.calculateOrderFee(
        distanceKm: 0.30,
        weightKg: 0.80,
        isCaution: true,
        trips: 2,
      );
      expect(fee.trips, equals(2));
      expect(fee.distanceFee, equals(24.00));
      expect(fee.totalFee, equals(77.00)); // 15 + 24 + 8 + 25 + 5
      expect(
        fee.breakdownRows.map((r) => r.label).toList(),
        equals([
          'Base',
          'Distance 0.30 km × 2 trips',
          'Weight 0.80 kg',
          'Extra drone trip (1 × ₱25.00)',
          'Weather surcharge',
        ]),
      );
      expect(fee.breakdownRows[3].amount, equals(25.00));

      // A single trip carries no extra-trip charge or row
      final single = DeliveryFeeCalculator.calculateOrderFee(
        distanceKm: 0.30,
        weightKg: 0.40,
      );
      expect(single.extraTripFee, equals(0.0));
      expect(
        single.breakdownRows.any((r) => r.label.startsWith('Extra drone')),
        isFalse,
      );
    });

    test('3. Caution surcharge: adds PHP 5.00 when weather is caution', () {
      // Normal weather (isCaution = false)
      final feeNormal = DeliveryFeeCalculator.calculateOrderFee(
        distanceKm: 0.21,
        weightKg: 0.32,
        isCaution: false,
      );
      expect(feeNormal.weatherFee, equals(0.00));
      expect(feeNormal.totalFee, equals(26.60));

      // Caution weather (isCaution = true) -> +5.00
      final feeCaution = DeliveryFeeCalculator.calculateOrderFee(
        distanceKm: 0.21,
        weightKg: 0.32,
        isCaution: true,
      );
      expect(feeCaution.weatherFee, equals(5.00));
      expect(feeCaution.totalFee, equals(31.60));
      expect(
        feeCaution.breakdownText,
        equals('Base ₱15.00 + Distance 0.21 km ₱8.40 + Weight 0.32 kg ₱3.20 + Weather ₱5.00'),
      );
    });

    test('4. Same-building minimum: zero distance results in base fee + weight, never below base 15.00', () {
      // Same building, no weight: distance = 0.0 -> exact base fee 15.00
      final feeSameBuilding = DeliveryFeeCalculator.calculateOrderFee(
        distanceKm: 0.0,
        weightKg: 0.0,
        isCaution: false,
      );
      expect(feeSameBuilding.distanceKm, equals(0.0));
      expect(feeSameBuilding.distanceFee, equals(0.0));
      expect(feeSameBuilding.totalFee, equals(15.00));
      expect(feeSameBuilding.breakdownText, equals('Base ₱15.00'));

      // Micro distance under 5 meters (treated as same building)
      final feeMicro = DeliveryFeeCalculator.calculateOrderFee(
        distanceKm: 0.003, // 3 meters
        weightKg: 0.10,
        isCaution: false,
      );
      expect(feeMicro.distanceFee, equals(0.0));
      expect(feeMicro.totalFee, equals(16.00)); // 15 + 1.00 weight
    });

    test('5. Missing-coordinate fallback: falls back gracefully to base fee plus weight only', () {
      // null distanceKm
      final feeNull = DeliveryFeeCalculator.calculateOrderFee(
        distanceKm: null,
        weightKg: 0.25,
        isCaution: false,
      );
      expect(feeNull.distanceKm, equals(0.0));
      expect(feeNull.distanceFee, equals(0.0));
      expect(feeNull.weightFee, equals(2.50));
      expect(feeNull.totalFee, equals(17.50));
      expect(feeNull.breakdownText, equals('Base ₱15.00 + Weight 0.25 kg ₱2.50'));

      // calculateDistanceKm with missing/invalid coordinates returns null
      expect(
        DeliveryFeeCalculator.calculateDistanceKm(
          startLat: null,
          startLng: 123.953,
          endLat: 10.325,
          endLng: 123.954,
        ),
        isNull,
      );
      expect(
        DeliveryFeeCalculator.calculateDistanceKm(
          startLat: 0.0,
          startLng: 0.0,
          endLat: 10.325,
          endLng: 123.954,
        ),
        isNull,
      );

      // calculateDistanceKm with real coordinates computes valid km
      final distKm = DeliveryFeeCalculator.calculateDistanceKm(
        startLat: 10.325210,
        startLng: 123.953201, // Main
        endLat: 10.326184,
        endLng: 123.954843, // Maritime
      );
      expect(distKm, isNotNull);
      expect(distKm!, closeTo(0.21, 0.01));
    });

    test('6. Custom delivery request formula compatibility', () {
      final customFee = DeliveryFeeCalculator.calculateCustomDeliveryFee(
        estimatedDistanceKm: 0.21,
        packageWeightKg: 0.3,
        packageType: 'Food',
        priority: 'Express',
      );
      // base (20) + dist (0.21 * 100 = 21) + weight (0.3 * 20 = 6) + food (5) + express (10) = 62.00
      expect(customFee, equals(62.00));
    });

    test('7. Breakdown sums to stored delivery fee', () {
      // 0.21 km distance -> 8.40, 0.32 kg weight -> 3.20, base -> 15.00 = 26.60
      const storedFee = 26.60;
      final recomputed = DeliveryFeeCalculator.recomputeStoredOrderFee(
        storedDeliveryFee: storedFee,
        distanceKm: 0.21,
        weightKg: 0.32,
      );

      expect(recomputed, isNotNull);
      expect(recomputed!.totalFee, equals(storedFee));

      final rows = recomputed.breakdownRows;
      expect(rows.length, 3);
      expect(rows[0].label, equals('Base'));
      expect(rows[0].amount, equals(15.00));
      expect(rows[1].label, equals('Distance 0.21 km'));
      expect(rows[1].amount, equals(8.40));
      expect(rows[2].label, equals('Weight 0.32 kg'));
      expect(rows[2].amount, equals(3.20));

      final rowSum = rows.fold<double>(0.0, (sum, r) => sum + r.amount);
      expect(double.parse(rowSum.toStringAsFixed(2)), equals(storedFee));
    });

    test('8. Weather surcharge: shown only when applicable (caution at order time)', () {
      // Normal order: storedFee matches base + distance + weight -> no weather surcharge
      final normal = DeliveryFeeCalculator.recomputeStoredOrderFee(
        storedDeliveryFee: 26.60,
        distanceKm: 0.21,
        weightKg: 0.32,
      );
      expect(normal, isNotNull);
      expect(normal!.weatherFee, equals(0.0));
      expect(
        normal.breakdownRows.any((r) => r.label.contains('Weather')),
        isFalse,
      );

      // Caution order: storedFee = 31.60 (exceeds base + dist + weight by 5.00)
      final caution = DeliveryFeeCalculator.recomputeStoredOrderFee(
        storedDeliveryFee: 31.60,
        distanceKm: 0.21,
        weightKg: 0.32,
      );
      expect(caution, isNotNull);
      expect(caution!.weatherFee, equals(5.00));
      expect(caution.totalFee, equals(31.60));

      final cautionRows = caution.breakdownRows;
      expect(cautionRows.length, 4);
      expect(cautionRows[0].label, equals('Base'));
      expect(cautionRows[0].amount, equals(15.00));
      expect(cautionRows[1].label, equals('Distance 0.21 km'));
      expect(cautionRows[1].amount, equals(8.40));
      expect(cautionRows[2].label, equals('Weight 0.32 kg'));
      expect(cautionRows[2].amount, equals(3.20));
      expect(cautionRows[3].label, equals('Weather surcharge'));
      expect(cautionRows[3].amount, equals(5.00));

      final cautionSum = cautionRows.fold<double>(0.0, (sum, r) => sum + r.amount);
      expect(double.parse(cautionSum.toStringAsFixed(2)), equals(31.60));
    });

    test('9. Graceful fallback when parts do not reconcile with stored fee', () {
      // Stored fee is 31.60, but distance changed to 0.50 km (distFee 20.00 -> total 38.20 / 43.20)
      final mismatch = DeliveryFeeCalculator.recomputeStoredOrderFee(
        storedDeliveryFee: 31.60,
        distanceKm: 0.50, // Vendor moved or different coordinates
        weightKg: 0.32,
      );
      // Must return null rather than displaying conflicting numbers
      expect(mismatch, isNull);

      // Random non-matching fee
      final arbitraryFee = DeliveryFeeCalculator.recomputeStoredOrderFee(
        storedDeliveryFee: 50.00,
        distanceKm: 0.21,
        weightKg: 0.32,
      );
      expect(arbitraryFee, isNull);
    });

    test('10. Order totals consistency: subtotal + deliveryFee == totalAmount', () {
      const subtotal = 150.00;
      const storedDeliveryFee = 26.60;
      const totalAmount = 176.60;

      // Confirm charged total is preserved exactly
      expect(subtotal + storedDeliveryFee, equals(totalAmount));

      final recomputed = DeliveryFeeCalculator.recomputeStoredOrderFee(
        storedDeliveryFee: storedDeliveryFee,
        distanceKm: 0.21,
        weightKg: 0.32,
      );
      expect(recomputed, isNotNull);
      expect(subtotal + recomputed!.totalFee, equals(totalAmount));
    });
  });
}
