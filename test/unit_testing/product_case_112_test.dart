import 'package:aerodrop/core/providers/product_provider.dart';
import 'package:aerodrop/features/vendor/add_edit_product_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fakes.dart';
import '_helpers.dart';
import '_router.dart';

/// Vendor catalog whose addProduct() succeeds and records what was sent.
class _Catalog extends FakeVendorProducts {
  _Catalog() : super(const []);
  final added = <String>[];
  @override
  Future<bool> addProduct({
    required String name,
    required String description,
    required double price,
    required int stock,
    required String categoryName,
    required double weightKg,
    String imageUrl = '',
  }) async {
    added.add('$name|$price|$stock|$weightKg');
    return true;
  }
}

void main() {
  group('Test Case ID: CASE-112', () {
    testWidgets(
      'Test Case Description: Vendor fills in Caramel Macchiato (P135.00, stock 20, 380 g) and taps Publish Listing | '
      "Expected Result: The product is saved and 'Product added successfully.' is shown",
      (tester) async {
        final catalog = _Catalog();
        await pumpRouted(tester, const AddEditProductScreen(), overrides: [vendorProductsProvider.overrideWith((ref) => catalog)], size: const Size(390, 1800));
        await fillField(tester, 0, 'Caramel Macchiato');
        await fillField(tester, 1, 'Espresso with steamed milk and caramel drizzle.');
        await fillField(tester, 2, '135');
        await fillField(tester, 3, '20');
        await fillField(tester, 4, '380');
        await tapButton(tester, 'Publish Listing');
        await tester.pump(const Duration(milliseconds: 300));

        expect(catalog.added, ['Caramel Macchiato|135.0|20|0.38']);
        expect(find.text('Product added successfully.'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
