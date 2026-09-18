import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/core/widgets/shared_drone_radar.dart';

void main() {
  group('Runtime Fixes & Authoritative Delivery Verification', () {
    test('DeliveryModel progress adheres to deliveries.progress authoritative source', () {
      final activeDel = DeliveryModel(
        id: 'del-001',
        senderName: 'Vendor A',
        recipientName: 'Student B',
        recipientPhone: '09123456789',
        deliveryAddress: 'Old Building Pad',
        packageName: 'Coffee',
        packageWeight: 0.5,
        packageType: 'Beverage',
        status: DeliveryStatus.inTransit,
        eta: '2 mins',
        createdAt: DateTime.now(),
        progress: 0.47,
      );

      expect(activeDel.progress, 0.47);
      expect((activeDel.progress * 100).round(), 47);

      final completedDel = activeDel.copyWith(
        status: DeliveryStatus.delivered,
        progress: 1.0,
      );
      expect(completedDel.progress, 1.0);
      expect((completedDel.progress * 100).round(), 100);
    });

    test('OrderModel retains associated order_id and delivery_id', () {
      final order = OrderModel(
        id: 'ord-8888-9999',
        userId: 'usr-customer-1',
        vendorId: 'ven-vendor-1',
        orderStatus: 'ready_for_delivery',
        dropoffLocationId: 'loc-01',
        totalAmount: 250.0,
        createdAt: DateTime.now(),
        items: [],
        deliveryId: 'del-7777-6666',
        deliveryStatus: 'in_transit',
        droneId: 'DRN-001',
      );

      expect(order.id, 'ord-8888-9999');
      expect(order.deliveryId, 'del-7777-6666');
      expect(order.deliveryStatus, 'in_transit');
    });

    test('Active deliveries filter strictly excludes delivered and historical flights', () {
      final allDeliveries = [
        DeliveryModel(
          id: 'del-001',
          senderName: 'Vendor A',
          recipientName: 'Student A',
          recipientPhone: '09111111111',
          deliveryAddress: 'Annex 1',
          packageName: 'Meal',
          packageWeight: 0.5,
          packageType: 'Food',
          status: DeliveryStatus.delivered,
          eta: 'Delivered',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          progress: 1.0,
        ),
        DeliveryModel(
          id: 'del-002',
          senderName: 'Vendor B',
          recipientName: 'Student B',
          recipientPhone: '09222222222',
          deliveryAddress: 'Maritime',
          packageName: 'Book',
          packageWeight: 0.8,
          packageType: 'Book',
          status: DeliveryStatus.inTransit,
          eta: '3 mins',
          createdAt: DateTime.now(),
          progress: 0.55,
        ),
      ];

      final activeDeliveries = allDeliveries
          .where(
            (d) =>
                d.status == DeliveryStatus.inTransit ||
                d.status == DeliveryStatus.assigning,
          )
          .toList();

      expect(activeDeliveries.length, 1);
      expect(activeDeliveries.first.id, 'del-002');
      expect(activeDeliveries.first.status, DeliveryStatus.inTransit);
    });

    testWidgets('SharedDroneRadar renders Standby state at Base Hub when delivery is null', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SharedDroneRadar(
                delivery: null,
                title: 'Campus Drone Radar • Standby',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Campus Drone Radar • Standby'), findsOneWidget);
      expect(find.text('Available — At Base'), findsOneWidget);
      expect(find.text('Stationed at Campus Drone Hub • Ready for dispatch'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets('SharedDroneRadar renders for active in_transit and delivered states without throwing', (tester) async {
      final inTransitDelivery = DeliveryModel(
        id: 'del-test-1',
        senderName: 'UCLM Canteen',
        recipientName: 'Erickson',
        recipientPhone: '09123456789',
        deliveryAddress: 'Annex 1 Building',
        packageName: 'Engineering Kit',
        packageWeight: 1.2,
        packageType: 'Electronics',
        status: DeliveryStatus.inTransit,
        eta: '3 mins',
        createdAt: DateTime.now(),
        progress: 0.65,
        pickupLocationName: 'Main Canteen',
        dropoffLocationName: 'Annex 1 Building',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SharedDroneRadar(
                delivery: inTransitDelivery,
                title: 'DRONE EN ROUTE',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('DRONE EN ROUTE'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);

      // Transition to delivered
      final deliveredDelivery = inTransitDelivery.copyWith(
        status: DeliveryStatus.delivered,
        progress: 1.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SharedDroneRadar(
                delivery: deliveredDelivery,
                title: 'DELIVERED',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('DELIVERED'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });
  });
}
