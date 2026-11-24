import 'package:aerodrop/core/providers/product_provider.dart';
import 'package:aerodrop/core/models/cart_model.dart';
import 'package:aerodrop/features/products/product_details_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fakes.dart';
import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-011', () {
    testWidgets(
      'Test Case Description: Customer opens Mango Fruit Tea, which has 0 stock | '
      "Expected Result: Product is marked 'Unavailable' and Add to Cart does nothing",
      (tester) async {
        await pumpScreen(
          tester,
          const ProductDetailsScreen(productId: 'mango'),
          overrides: [
            productProvider.overrideWith((ref) => FakeProducts([
              product('mango', 'Mango Fruit Tea', 95, 0.45, 0, 'Fruit Tea', vendorId: 'tea', vendorName: 'Tea Haus'),
            ])),
          ],
          size: const Size(600, 1200),
        );

        expect(find.text('Mango Fruit Tea'), findsWidgets);
        expect(find.text('Unavailable'), findsOneWidget);
        expect(find.text('In Stock'), findsNothing);
        cartNotifier.clear();
        await tester.tap(find.text('Add to Cart'), warnIfMissed: false);
        await tester.pump(const Duration(seconds: 1));
        expect(cartNotifier.totalItems, 0);
      },
    );
  });
}
