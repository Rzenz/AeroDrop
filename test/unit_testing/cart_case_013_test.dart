import 'package:aerodrop/core/models/cart_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test Case ID: CASE-013', () {
    test(
      'Test Case Description: User adds Iced Spanish Latte (P120) and Butter Croissant (P65) to the cart | '
      'Expected Result: Cart holds 2 items with a subtotal of P185.00 in 1 drone trip',
      () {
        final cart = CartNotifier();
        cart.addItem(CartItem(productId: 'latte', productName: 'Iced Spanish Latte', vendorId: 'kape', vendorName: 'Kape Kanto', imageUrl: '', unitPrice: 120, weightKg: 0.38));
        cart.addItem(CartItem(productId: 'croissant', productName: 'Butter Croissant', vendorId: 'kape', vendorName: 'Kape Kanto', imageUrl: '', unitPrice: 65, weightKg: 0.09));

        expect(cart.value.length, 2);
        expect(cart.totalItems, 2);
        expect(cart.totalAmount, 185.0);
        expect(cart.totalWeightKg, closeTo(0.47, 0.0001));
        expect(cart.tripsRequired, 1);
      },
    );
  });
}
