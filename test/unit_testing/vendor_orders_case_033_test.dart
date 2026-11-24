import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/core/providers/order_provider.dart';
import 'package:aerodrop/features/vendor/vendor_orders_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fakes.dart';
import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-033', () {
    testWidgets(
      "Test Case Description: Kape Kanto taps Accept Order on Paolo Reyes's pending order | "
      "Expected Result: The order is updated to confirmed and 'Order updated to confirmed.' is shown",
      (tester) async {
        final orders = FakeVendorOrders([
          order('f09a7ef5-0000-4000-a000-000000000001', 'pending', 'Kape Kanto', 153.19, customer: 'Paolo Reyes', at: DateTime.now().subtract(const Duration(minutes: 4)), items: [
            OrderItemModel(productName: 'Americano', quantity: 1, unitPrice: 85),
            OrderItemModel(productName: 'Chocolate Chip Cookie', quantity: 1, unitPrice: 45),
          ]),
        ]);
        await pumpScreen(tester, const VendorOrdersScreen(), overrides: [vendorOrdersProvider.overrideWith((ref) => orders)], size: const Size(600, 1200));

        await tapButton(tester, 'Accept Order');

        expect(orders.updates, ['f09a7ef5-0000-4000-a000-000000000001:confirmed']);
        expect(find.text('Order updated to confirmed.'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
