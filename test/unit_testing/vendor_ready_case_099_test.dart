import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/core/providers/order_provider.dart';
import 'package:aerodrop/features/vendor/vendor_orders_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fakes.dart';
import '_helpers.dart';

/// Answers markOrderReady the way the vendor_mark_order_ready server function does.
class _ReadyOrders extends FakeVendorOrders {
  _ReadyOrders(super.orders, this.answer);
  final ({bool success, bool droneDispatched, String message}) answer;
  final readied = <String>[];

  @override
  Future<({bool success, bool droneDispatched, String message})> markOrderReady(String orderId) async {
    readied.add(orderId);
    return answer;
  }
}

void main() {
  group('Test Case ID: CASE-099', () {
    testWidgets(
      "Test Case Description: Kape Kanto taps Mark as Ready on Paolo Reyes's order that is being prepared | "
      "Expected Result: A drone is dispatched and 'Order is ready for delivery. Drone DRN-001 dispatched for pickup.' is shown",
      (tester) async {
        final orders = _ReadyOrders([
          order('f09a7ef5-0000-4000-a000-000000000002', 'preparing', 'Kape Kanto', 153.19, customer: 'Paolo Reyes', at: DateTime.now().subtract(const Duration(minutes: 9)), items: [
            OrderItemModel(productName: 'Americano', quantity: 1, unitPrice: 85),
          ]),
        ], (success: true, droneDispatched: true, message: 'Order is ready for delivery. Drone DRN-001 dispatched for pickup.'));
        await pumpScreen(tester, const VendorOrdersScreen(initialStatus: 'preparing'), overrides: [vendorOrdersProvider.overrideWith((ref) => orders)], size: const Size(600, 1200));

        await tapButton(tester, 'Mark as Ready');

        expect(orders.readied, ['f09a7ef5-0000-4000-a000-000000000002']);
        expect(find.text('Order is ready for delivery. Drone DRN-001 dispatched for pickup.'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
