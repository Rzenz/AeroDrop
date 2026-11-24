import 'package:aerodrop/core/providers/order_provider.dart';
import 'package:aerodrop/features/orders/orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fakes.dart';
import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-016', () {
    testWidgets(
      'Test Case Description: Customer opens My Orders and selects the Delivered tab | '
      'Expected Result: Only delivered orders are listed; preparing and cancelled orders are hidden',
      (tester) async {
        await pumpScreen(
          tester,
          const OrdersScreen(),
          overrides: [
            orderProvider.overrideWith((ref) => FakeCustomerOrders([
              order('23977133-0000-4000-a000-000000000001', 'preparing', 'Tea Haus', 112.19),
              order('9664dc58-0000-4000-a000-000000000002', 'delivered', 'UCLM Canteen', 148.19),
              order('b2f46839-0000-4000-a000-000000000003', 'delivered', 'Campus Mart', 138.19),
              order('c1a2b3c4-0000-4000-a000-000000000004', 'cancelled', 'Kape Kanto', 153.19),
            ])),
          ],
          size: const Size(900, 900),
        );
        expect(find.text('Tea Haus'), findsOneWidget);

        await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text('Delivered')));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        // Only the Delivered tab's list is on screen now.
        expect(find.text('UCLM Canteen').hitTestable(), findsOneWidget);
        expect(find.text('Campus Mart').hitTestable(), findsOneWidget);
        expect(find.text('Tea Haus').hitTestable(), findsNothing);
        expect(find.text('Kape Kanto').hitTestable(), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
