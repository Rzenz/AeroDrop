import '../services/delivery_fee_calculator.dart';

/// What an order will cost, as priced by the server's quote_order_fee().
///
/// It runs the same function place_order charges with, so this is the figure
/// the customer pays. Nothing on the client computes these numbers.
class OrderQuote {
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final int totalWeightGrams;
  final int tripsRequired;
  final double distanceKm;
  final bool isCaution;
  final double baseFee;
  final double distanceFee;
  final double weightFee;
  final double extraTripFee;
  final double weatherFee;

  const OrderQuote({
    required this.subtotal,
    required this.deliveryFee,
    required this.totalAmount,
    required this.totalWeightGrams,
    required this.tripsRequired,
    required this.distanceKm,
    required this.isCaution,
    required this.baseFee,
    required this.distanceFee,
    required this.weightFee,
    required this.extraTripFee,
    required this.weatherFee,
  });

  /// The quoted figures in the shape the checkout and receipt already render,
  /// so their breakdown rows and labels are unchanged; only the numbers now
  /// come from the server.
  DeliveryFeeBreakdown toFeeBreakdown() => DeliveryFeeCalculator.breakdownFrom(
    baseFee: baseFee,
    distanceKm: distanceKm,
    distanceFee: distanceFee,
    // Labelled on the weight that was charged, which the server caps at
    // maxTrips loads
    weightKg: (totalWeightGrams / 1000.0).clamp(
      0.0,
      DeliveryFeeCalculator.maxPayloadKg * DeliveryFeeCalculator.maxTrips,
    ),
    weightFee: weightFee,
    extraTripFee: extraTripFee,
    weatherFee: weatherFee,
    totalFee: deliveryFee,
    trips: tripsRequired,
  );

  /// Throws [FormatException] when a figure the checkout needs is missing,
  /// rather than defaulting it to zero and showing a price nobody charged.
  factory OrderQuote.fromMap(Map<String, dynamic> map) {
    double required(String key, [Map<String, dynamic>? from]) {
      final v = (from ?? map)[key];
      final d = v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
      if (d == null) throw FormatException('Quote is missing $key');
      return d;
    }

    double optional(Map<String, dynamic> from, String key) {
      final v = from[key];
      return v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;
    }

    final breakdown = map['breakdown'] is Map
        ? Map<String, dynamic>.from(map['breakdown'] as Map)
        : <String, dynamic>{};

    return OrderQuote(
      subtotal: required('subtotal'),
      deliveryFee: required('delivery_fee'),
      totalAmount: required('total_amount'),
      totalWeightGrams: optional(map, 'total_weight_grams').round(),
      tripsRequired: optional(map, 'trips_required').round().clamp(1, 99),
      distanceKm: optional(map, 'distance_km'),
      isCaution: map['is_caution'] == true,
      baseFee: optional(breakdown, 'base'),
      distanceFee: optional(breakdown, 'distance'),
      weightFee: optional(breakdown, 'weight'),
      extraTripFee: optional(breakdown, 'extra_trip'),
      weatherFee: optional(breakdown, 'weather'),
    );
  }
}
