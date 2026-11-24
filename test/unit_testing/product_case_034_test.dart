import 'package:flutter/widgets.dart';
import 'package:aerodrop/features/vendor/add_edit_product_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-034', () {
    testWidgets(
      'Test Case Description: Vendor taps Publish Listing with all product fields empty | '
      'Expected Result: Product is not saved and each required field shows its error message',
      (tester) async {
        // A tall phone screen so the whole form is built at once.
        await pumpScreen(
          tester,
          const AddEditProductScreen(),
          size: const Size(390, 1800),
        );

        await tapButton(tester, 'Publish Listing');

        expect(find.text('Item name is required'), findsWidgets);
        expect(find.text('Description is required'), findsWidgets);
        expect(find.text('Required'), findsWidgets);
        expect(find.text('Weight is required for drone cargo limits'), findsWidgets);
      },
    );
  });
}
