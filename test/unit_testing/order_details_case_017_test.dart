import 'package:aerodrop/core/models/order_model.dart';
import 'package:flutter_test/flutter_test.dart';

OrderModel _order(String status, {String? deliveryStatus}) => OrderModel(
  id: '68efac5f-0000-4000-a000-000000000000',
  userId: 'maria',
  vendorId: 'kape',
  orderStatus: status,
  deliveryStatus: deliveryStatus,
  dropoffLocationId: 'maritime',
  totalAmount: 143.19,
  createdAt: DateTime(2026, 11, 17, 9),
  items: const [],
);

// The Order Details screen offers Cancel Order only for these statuses.
bool _cancellable(OrderModel o) => const ['pending', 'confirmed', 'preparing'].contains(o.effectiveStatus.toLowerCase());

void main() {
  group('Test Case ID: CASE-017', () {
    test(
      'Test Case Description: Customer opens an order whose drone is already in flight | '
      "Expected Result: The order counts as in transit, so Cancel Order is replaced by 'Order is packed or in flight and cannot be cancelled.'",
      () {
        final inFlight = _order('ready_for_delivery', deliveryStatus: 'in_transit');
        expect(inFlight.effectiveStatus, 'in_transit');
        expect(_cancellable(inFlight), isFalse);

        expect(_cancellable(_order('preparing')), isTrue);
        expect(_cancellable(_order('delivered', deliveryStatus: 'delivered')), isFalse);
      },
    );
  });
}
