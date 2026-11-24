import 'package:aerodrop/core/providers/product_provider.dart';
import 'package:aerodrop/core/providers/vendor_provider.dart';
import 'package:aerodrop/features/vendors/vendors_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fakes.dart';
import '_helpers.dart';

VendorViewModel _store(String id, String name, String building, double rating, int reviews) => VendorViewModel(
  id: id,
  ownerName: 'Owner',
  businessName: name,
  phoneNumber: '+639171234567',
  email: '$id@uclm.edu.ph',
  building: building,
  logoInitials: name.substring(0, 2).toUpperCase(),
  rating: rating,
  reviewCount: reviews,
);

void main() {
  group('Test Case ID: CASE-010', () {
    testWidgets(
      'Test Case Description: Customer searches the Shop stores for "tea" | '
      "Expected Result: Only Tea Haus is listed and the Shop shows '1 store available'",
      (tester) async {
        await pumpScreen(
          tester,
          const VendorsScreen(),
          overrides: [
            vendorProvider.overrideWith((ref) => FakeVendors([
              _store('kape', 'Kape Kanto', 'UCLM Main Building', 4.7, 38),
              _store('canteen', 'UCLM Canteen', 'UCLM Annex 2', 4.4, 52),
              _store('tea', 'Tea Haus', 'UCLM Basic Education', 4.8, 41),
              _store('mart', 'Campus Mart', 'UCLM Main Building', 4.2, 17),
            ])),
            productProvider.overrideWith((ref) => FakeProducts(const [])),
          ],
          // Wide enough for the test font, which is wider than the app's.
          size: const Size(600, 900),
        );
        expect(find.text('4 stores available'), findsOneWidget);

        await tester.enterText(find.byType(TextField).first, 'tea');
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Tea Haus'), findsOneWidget);
        expect(find.text('Kape Kanto'), findsNothing);
        expect(find.text('1 store available'), findsOneWidget);
      },
    );
  });
}
