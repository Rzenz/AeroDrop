import 'package:aerodrop/core/models/order_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderModel Lifecycle & Status Synchronization', () {
    test('pending order maps to pending status and label', () {
      final order = OrderModel(
        id: 'ord-001',
        userId: 'usr-001',
        vendorId: 'ven-001',
        orderStatus: 'pending',
        dropoffLocationId: 'loc-001',
        totalAmount: 150.0,
        createdAt: DateTime.now(),
        items: [],
      );

      expect(order.effectiveStatus, 'pending');
      expect(order.statusDisplay, 'Pending');
    });

    test(
      'pre-dispatch orders (pending, confirmed, preparing) NEVER map to in_transit even with delivery record',
      () {
        final pendingWithDel = OrderModel(
          id: 'ord-p1',
          userId: 'usr-001',
          vendorId: 'ven-001',
          orderStatus: 'pending',
          dropoffLocationId: 'loc-001',
          totalAmount: 150.0,
          createdAt: DateTime.now(),
          items: [],
          deliveryId: 'del-p1',
          deliveryStatus: 'in_transit',
        );
        expect(
          pendingWithDel.effectiveStatus,
          'pending',
          reason: 'Pending order must never be in transit',
        );

        final confirmedWithDel = OrderModel(
          id: 'ord-c1',
          userId: 'usr-001',
          vendorId: 'ven-001',
          orderStatus: 'confirmed',
          dropoffLocationId: 'loc-001',
          totalAmount: 150.0,
          createdAt: DateTime.now(),
          items: [],
          deliveryId: 'del-c1',
          deliveryStatus: 'in_transit',
        );
        expect(
          confirmedWithDel.effectiveStatus,
          'confirmed',
          reason: 'Confirmed order must never be in transit',
        );

        final preparingWithDel = OrderModel(
          id: 'ord-pr1',
          userId: 'usr-001',
          vendorId: 'ven-001',
          orderStatus: 'preparing',
          dropoffLocationId: 'loc-001',
          totalAmount: 150.0,
          createdAt: DateTime.now(),
          items: [],
          deliveryId: 'del-pr1',
          deliveryStatus: 'in_transit',
        );
        expect(
          preparingWithDel.effectiveStatus,
          'preparing',
          reason: 'Preparing order must never be in transit',
        );
      },
    );

    test('confirmed and preparing orders map accurately', () {
      final confirmed = OrderModel(
        id: 'ord-002',
        userId: 'usr-001',
        vendorId: 'ven-001',
        orderStatus: 'confirmed',
        dropoffLocationId: 'loc-001',
        totalAmount: 150.0,
        createdAt: DateTime.now(),
        items: [],
      );
      expect(confirmed.effectiveStatus, 'confirmed');
      expect(confirmed.statusDisplay, 'Confirmed');

      final preparing = OrderModel(
        id: 'ord-003',
        userId: 'usr-001',
        vendorId: 'ven-001',
        orderStatus: 'preparing',
        dropoffLocationId: 'loc-001',
        totalAmount: 150.0,
        createdAt: DateTime.now(),
        items: [],
      );
      expect(preparing.effectiveStatus, 'preparing');
      expect(preparing.statusDisplay, 'Preparing');
    });

    test(
      'ready_for_delivery order without active flight maps to ready_for_delivery',
      () {
        final order = OrderModel(
          id: 'ord-004',
          userId: 'usr-001',
          vendorId: 'ven-001',
          orderStatus: 'ready_for_delivery',
          dropoffLocationId: 'loc-001',
          totalAmount: 200.0,
          createdAt: DateTime.now(),
          items: [],
        );

        expect(order.effectiveStatus, 'ready_for_delivery');
        expect(order.statusDisplay, 'Ready for Delivery');
      },
    );

    test('order with delivery status in_transit maps to in_transit', () {
      final order = OrderModel(
        id: 'ord-005',
        userId: 'usr-001',
        vendorId: 'ven-001',
        orderStatus: 'ready_for_delivery',
        dropoffLocationId: 'loc-001',
        totalAmount: 200.0,
        createdAt: DateTime.now(),
        items: [],
        deliveryId: 'del-001',
        deliveryStatus: 'in_transit',
        droneId: 'DRN-001',
      );

      expect(order.effectiveStatus, 'in_transit');
      expect(order.statusDisplay, 'In Transit');
    });

    test('order with delivery status delivered maps to delivered', () {
      final order = OrderModel(
        id: 'ord-006',
        userId: 'usr-001',
        vendorId: 'ven-001',
        orderStatus: 'ready_for_delivery', // database order_status might lag
        dropoffLocationId: 'loc-001',
        totalAmount: 200.0,
        createdAt: DateTime.now(),
        items: [],
        deliveryId: 'del-001',
        deliveryStatus: 'delivered',
        droneId: 'DRN-001',
      );

      expect(order.effectiveStatus, 'delivered');
      expect(order.statusDisplay, 'Delivered');
    });

    test('order with database order_status delivered maps to delivered', () {
      final order = OrderModel(
        id: 'ord-007',
        userId: 'usr-001',
        vendorId: 'ven-001',
        orderStatus: 'delivered',
        dropoffLocationId: 'loc-001',
        totalAmount: 200.0,
        createdAt: DateTime.now(),
        items: [],
      );

      expect(order.effectiveStatus, 'delivered');
      expect(order.statusDisplay, 'Delivered');
    });

    test(
      'order with elapsed delivery timestamps auto-resolves to delivered',
      () {
        final pastTime = DateTime.now().subtract(const Duration(minutes: 5));
        final order = OrderModel(
          id: 'ord-008',
          userId: 'usr-001',
          vendorId: 'ven-001',
          orderStatus: 'ready_for_delivery',
          dropoffLocationId: 'loc-001',
          totalAmount: 200.0,
          createdAt: pastTime,
          items: [],
          deliveryId: 'del-002',
          deliveryStatus: 'in_transit',
          deliveryStartedAt: pastTime,
          estimatedDeliverySeconds: 60, // 1 minute flight, 5 minutes elapsed
        );

        expect(order.effectiveStatus, 'delivered');
        expect(order.statusDisplay, 'Delivered');
      },
    );

    test('cancelled and rejected orders map correctly', () {
      final cancelled = OrderModel(
        id: 'ord-009',
        userId: 'usr-001',
        vendorId: 'ven-001',
        orderStatus: 'cancelled',
        dropoffLocationId: 'loc-001',
        totalAmount: 200.0,
        createdAt: DateTime.now(),
        items: [],
      );
      expect(cancelled.effectiveStatus, 'cancelled');
      expect(cancelled.statusDisplay, 'Cancelled');

      final rejected = OrderModel(
        id: 'ord-010',
        userId: 'usr-001',
        vendorId: 'ven-001',
        orderStatus: 'rejected',
        dropoffLocationId: 'loc-001',
        totalAmount: 200.0,
        createdAt: DateTime.now(),
        items: [],
      );
      expect(rejected.effectiveStatus, 'rejected');
      expect(rejected.statusDisplay, 'Rejected');
    });

    test('OrderModel.fromMap parses joined deliveries from Supabase', () {
      final map = {
        'id': 'b0000000-0000-0000-0000-000000000001',
        'user_id': 'u0000000-0000-0000-0000-000000000001',
        'vendor_id': 'v0000000-0000-0000-0000-000000000001',
        'order_status': 'ready_for_delivery',
        'delivery_location_id': '10000000-0000-0000-0000-000000000001',
        'subtotal': 120.0,
        'delivery_fee': 20.0,
        'total_amount': 140.0,
        'created_at': '2026-09-13T12:00:00.000Z',
        'vendor': {'business_name': 'Aero Cafe'},
        'customer': {
          'full_name': 'Erickson Doe',
          'phone_number': '09123456789',
        },
        'campus_locations': {'name': 'Annex 1 Building'},
        'order_items': [
          {'product_name': 'Iced Latte', 'quantity': 2, 'unit_price': 60.0},
        ],
        'deliveries': [
          {
            'id': 'd0000000-0000-0000-0000-000000000001',
            'status': 'in_transit',
            'progress': 0.5,
            'drone_id': '80000000-0000-0000-0000-000000000001',
            'estimated_delivery_seconds': 720,
            'delivery_started_at': DateTime.now().toIso8601String(),
          },
        ],
      };

      final order = OrderModel.fromMap(map);

      expect(order.id, 'b0000000-0000-0000-0000-000000000001');
      expect(order.vendorName, 'Aero Cafe');
      expect(order.customerName, 'Erickson Doe');
      expect(order.dropoffLocationName, 'Annex 1 Building');
      expect(order.items.length, 1);
      expect(order.items.first.productName, 'Iced Latte');
      expect(order.items.first.quantity, 2);
      expect(order.deliveryId, 'd0000000-0000-0000-0000-000000000001');
      expect(order.deliveryStatus, 'in_transit');
      expect(order.deliveryProgress, 0.5);
      expect(order.effectiveStatus, 'in_transit');
      expect(order.statusDisplay, 'In Transit');
    });
  });
}
