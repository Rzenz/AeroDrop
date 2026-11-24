import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/providers/delivery_provider.dart';
import 'package:aerodrop/features/admin/reports_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fakes.dart';
import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-047', () {
    testWidgets(
      'Test Case Description: Admin opens System Diagnostics & Logs on the Deliveries tab | '
      'Expected Result: Each delivery is logged with its number, target building and status (IN TRANSIT, DELIVERED)',
      (tester) async {
        await pumpScreen(
          tester,
          const ReportsPage(),
          overrides: [
            deliveryProvider.overrideWith((ref) => FakeDeliveries([
              delivery('18e40ba9-0000-4000-a000-000000000001', DeliveryStatus.inTransit),
              delivery('5453550d-0000-4000-a000-000000000002', DeliveryStatus.delivered, sender: 'UCLM Canteen', progress: 1),
            ])),
          ],
          size: const Size(600, 1200),
        );

        expect(find.textContaining('18e40ba9'), findsOneWidget);
        expect(find.textContaining('5453550d'), findsOneWidget);
        expect(find.textContaining('UCLM Maritime Building'), findsWidgets);
        expect(find.textContaining('TRANSIT'), findsWidgets);
        expect(find.textContaining('DELIVERED'), findsWidgets);
      },
    );
  });
}
