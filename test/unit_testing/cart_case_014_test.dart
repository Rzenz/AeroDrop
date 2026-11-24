import 'package:aerodrop/core/models/cart_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test Case ID: CASE-014', () {
    test(
      'Test Case Description: User adds 2 x Iced Spanish Latte (0.38 kg each), more than one drone load | '
      "Expected Result: Cart warns 'Heavy order: 0.76 kg, 2 drone trips' and still allows checkout",
      () {
        final cart = CartNotifier();
        final latte = CartItem(productId: 'latte', productName: 'Iced Spanish Latte', vendorId: 'kape', vendorName: 'Kape Kanto', imageUrl: '', unitPrice: 120, weightKg: 0.38);
        cart.addItem(latte);
        cart.increment('latte');

        expect(cart.totalItems, 2);
        expect(cart.totalAmount, 240.0);
        expect(cart.totalWeightKg.toStringAsFixed(2), '0.76');
        expect(cart.tripsRequired, 2);
        expect(cart.needsMultipleTrips, isTrue);
        expect(cart.exceedsMaxTrips, isFalse);
      },
    );
  });
}
