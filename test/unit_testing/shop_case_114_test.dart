import 'package:aerodrop/core/providers/product_provider.dart';
import 'package:aerodrop/core/providers/vendor_provider.dart';
import 'package:aerodrop/features/vendors/vendors_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fakes.dart';
import '_helpers.dart';

VendorViewModel _store(String id, String name, String building) => VendorViewModel(
  id: id,
  ownerName: 'Owner',
  businessName: name,
  phoneNumber: '+639171234567',
  email: '$id@uclm.edu.ph',
  building: building,
  logoInitials: name.substring(0, 2).toUpperCase(),
  rating: 4.5,
  reviewCount: 10,
);

void main() {
  group('Test Case ID: CASE-114', () {
    testWidgets(
      'Test Case Description: Customer searches the Shop stores for "pizza", which no store sells | '
      "Expected Result: No store is listed and 'No stores found matching your search.' is shown",
      (tester) async {
        await pumpScreen(
          tester,
          const VendorsScreen(),
          overrides: [
            vendorProvider.overrideWith((ref) => FakeVendors([
              _store('kape', 'Kape Kanto', 'UCLM Main Building'),
              _store('tea', 'Tea Haus', 'UCLM Basic Education'),
            ])),
            productProvider.overrideWith((ref) => FakeProducts(const [])),
          ],
          size: const Size(600, 900),
        );
        await tester.enterText(find.byType(TextField).first, 'pizza');
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Kape Kanto'), findsNothing);
        expect(find.text('Tea Haus'), findsNothing);
        expect(find.text('No stores found matching your search.'), findsOneWidget);
      },
    );
  });
}
