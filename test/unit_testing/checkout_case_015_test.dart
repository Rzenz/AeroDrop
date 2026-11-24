import 'package:aerodrop/core/models/order_quote_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test Case ID: CASE-015', () {
    test(
      'Test Case Description: Customer checks out 1 x Iced Spanish Latte (P120.00) for delivery to the Maritime Building | '
      'Expected Result: Checkout shows the server price: Base P15.00, Distance 0.21 km P8.39, Weight 0.38 kg P3.80, fee P27.19, total P147.19',
      () {
        // The reply quote_order_fee() returns for this order.
        final quote = OrderQuote.fromMap({
          'subtotal': 120.0,
          'delivery_fee': 27.19,
          'total_amount': 147.19,
          'total_weight_grams': 380,
          'trips_required': 1,
          'distance_km': 0.2097,
          'is_caution': false,
          'breakdown': {'base': 15.0, 'distance': 8.39, 'weight': 3.8, 'extra_trip': 0.0, 'weather': 0.0},
        });

        expect(quote.subtotal, 120.0);
        expect(quote.deliveryFee, 27.19);
        expect(quote.totalAmount, 147.19);
        final rows = quote.toFeeBreakdown().breakdownRows.map((r) => r.toString()).toList();
        expect(rows, ['Base: ₱15.00', 'Distance 0.21 km: ₱8.39', 'Weight 0.38 kg: ₱3.80']);
      },
    );
  });
}
