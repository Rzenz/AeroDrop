import 'package:aerodrop/core/providers/product_provider.dart';
import 'package:aerodrop/features/vendor/vendor_products_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fakes.dart';
import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-116', () {
    testWidgets(
      'Test Case Description: Vendor searches their product catalog for "matcha", which they do not sell | '
      "Expected Result: No product is listed and 'No items found in this category.' is shown",
      (tester) async {
        await pumpScreen(
          tester,
          const VendorProductsScreen(),
          overrides: [
            vendorProductsProvider.overrideWith((ref) => FakeVendorProducts([
              product('latte', 'Iced Spanish Latte', 120, 0.38, 24, 'Coffee'),
              product('croissant', 'Butter Croissant', 65, 0.09, 12, 'Pastry'),
            ])),
          ],
          size: const Size(600, 1200),
        );
        await tester.enterText(find.byType(TextField).first, 'matcha');
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Iced Spanish Latte'), findsNothing);
        expect(find.text('Butter Croissant'), findsNothing);
        expect(find.text('No items found in this category.'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
