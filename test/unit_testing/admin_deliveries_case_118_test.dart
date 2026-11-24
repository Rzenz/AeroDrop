import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/providers/delivery_provider.dart';
import 'package:aerodrop/features/admin/admin_deliveries_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fakes.dart';
import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-118', () {
    testWidgets(
      'Test Case Description: Admin filters Deliveries Dispatch by In Transit when every delivery is already delivered | '
      "Expected Result: No delivery is listed and 'No Deliveries' is shown",
      (tester) async {
        await pumpScreen(
          tester,
          const AdminDeliveriesScreen(),
          overrides: [
            deliveryProvider.overrideWith((ref) => FakeDeliveries([
              delivery('5453550d-0000-4000-a000-000000000002', DeliveryStatus.delivered, sender: 'UCLM Canteen', package: 'Chicken Adobo Rice (x1)', progress: 1),
              delivery('185607f7-0000-4000-a000-000000000003', DeliveryStatus.delivered, sender: 'Campus Mart', package: 'Yellow Pad (x2)', progress: 1),
            ])),
          ],
          size: const Size(900, 1400),
        );
        expect(find.text('UCLM Canteen'), findsOneWidget);
        await tester.tap(find.text('In Transit').first);
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('UCLM Canteen'), findsNothing);
        expect(find.text('Campus Mart'), findsNothing);
        expect(find.text('No Deliveries'), findsOneWidget);
      },
    );
  });
}
