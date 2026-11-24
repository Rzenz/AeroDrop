import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/core/providers/order_provider.dart';
import 'package:aerodrop/features/vendor/vendor_orders_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fakes.dart';
import '_helpers.dart';

/// Answers markOrderReady the way the vendor_mark_order_ready server function
/// does when the campus weather is grounded: it refuses to dispatch.
class _GroundedOrders extends FakeVendorOrders {
  _GroundedOrders(super.orders);
  final readied = <String>[];

  @override
  Future<({bool success, bool droneDispatched, String message})> markOrderReady(String orderId) async {
    readied.add(orderId);
    return (success: false, droneDispatched: false, message: 'Flight dispatch blocked: Weather is grounded');
  }
}

void main() {
  group('Test Case ID: CASE-100', () {
    testWidgets(
      'Test Case Description: Kape Kanto taps Mark as Ready while the campus weather is GROUNDED | '
      "Expected Result: No drone is dispatched and 'Flight dispatch blocked: Weather is grounded' is shown",
      (tester) async {
        final orders = _GroundedOrders([
          order('f09a7ef5-0000-4000-a000-000000000003', 'preparing', 'Kape Kanto', 153.19, customer: 'Paolo Reyes', at: DateTime.now().subtract(const Duration(minutes: 9)), items: [
            OrderItemModel(productName: 'Americano', quantity: 1, unitPrice: 85),
          ]),
        ]);
        await pumpScreen(tester, const VendorOrdersScreen(initialStatus: 'preparing'), overrides: [vendorOrdersProvider.overrideWith((ref) => orders)], size: const Size(600, 1200));

        await tapButton(tester, 'Mark as Ready');

        expect(orders.readied, ['f09a7ef5-0000-4000-a000-000000000003']);
        expect(find.text('Flight dispatch blocked: Weather is grounded'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
