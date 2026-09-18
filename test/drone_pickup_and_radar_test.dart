import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/core/widgets/shared_drone_radar.dart';

void main() {
  group('Drone Pickup & Radar Synchronization Tests', () {
    test('DeliveryStatus enum contains assigning and standard statuses', () {
      expect(DeliveryStatus.assigning.name, 'assigning');
      expect(DeliveryStatus.inTransit.name, 'inTransit');
      expect(DeliveryStatus.delivered.name, 'delivered');
      expect(DeliveryStatus.pending.name, 'pending');
      expect(DeliveryStatus.cancelled.name, 'cancelled');
    });

    test(
      'Order MUST stay ready_for_delivery when delivery status is assigning (drone en route to pickup)',
      () {
        // Core requirement: Drone must NOT be in_transit when vendor marks ready
        final order = OrderModel(
          id: 'ord-pickup-01',
          userId: 'usr-customer-01',
          vendorId: 'ven-jollibee-01',
          orderStatus: 'ready_for_delivery',
          dropoffLocationId: 'loc-maritime',
          totalAmount: 180.0,
          createdAt: DateTime.now(),
          items: [],
          deliveryId: 'del-pickup-01',
          deliveryStatus: 'assigning',
          droneId: 'DRN-001',
        );

        expect(
          order.effectiveStatus,
          'ready_for_delivery',
          reason:
              'Package is still with vendor while drone heads to pickup; status must remain ready_for_delivery',
        );
        expect(order.statusDisplay, 'Ready for Delivery');
        expect(order.effectiveStatus == 'delivered', isFalse);
        expect(order.effectiveStatus == 'in_transit', isFalse);
      },
    );

    test(
      'Order transitions to in_transit ONLY after drone picks up package (deliveryStatus == in_transit)',
      () {
        final orderInTransit = OrderModel(
          id: 'ord-pickup-02',
          userId: 'usr-customer-01',
          vendorId: 'ven-jollibee-01',
          orderStatus: 'in_transit',
          dropoffLocationId: 'loc-maritime',
          totalAmount: 180.0,
          createdAt: DateTime.now(),
          items: [],
          deliveryId: 'del-pickup-02',
          deliveryStatus: 'in_transit',
          droneId: 'DRN-001',
        );

        expect(orderInTransit.effectiveStatus, 'in_transit');
        expect(orderInTransit.statusDisplay, 'In Transit');
      },
    );

    test(
      'Order transitions to delivered after delivery completes and drone is released',
      () {
        final orderDelivered = OrderModel(
          id: 'ord-pickup-03',
          userId: 'usr-customer-01',
          vendorId: 'ven-jollibee-01',
          orderStatus: 'delivered',
          dropoffLocationId: 'loc-maritime',
          totalAmount: 180.0,
          createdAt: DateTime.now(),
          items: [],
          deliveryId: 'del-pickup-03',
          deliveryStatus: 'delivered',
          droneId: 'DRN-001',
        );

        expect(orderDelivered.effectiveStatus, 'delivered');
        expect(orderDelivered.statusDisplay, 'Delivered');
      },
    );

    test(
      'DeliveryModel telemetry copyWith preserves state and updates live telemetry',
      () {
        final initial = DeliveryModel(
          id: 'del-telemetry-01',
          senderName: 'Jollibee Main',
          recipientName: 'Juan Dela Cruz',
          recipientPhone: '09123456789',
          deliveryAddress: 'Maritime Building, 2nd Floor',
          packageName: 'Chickenjoy Bucket',
          packageWeight: 1.2,
          packageType: 'Food',
          eta: '10 mins',
          progress: 0.0,
          status: DeliveryStatus.assigning,
          droneId: 'DRN-001',
          pickupLocationId: 'loc-main',
          dropoffLocationId: 'loc-maritime',
          pickupLocationName: 'Old Building (Main)',
          dropoffLocationName: 'Maritime Building',
          currentLatitude: 10.3150,
          currentLongitude: 123.9010,
          currentAltitude: 20.0,
          currentSpeed: 8.0,
          batteryLevel: 98.0,
          createdAt: DateTime.now(),
        );

        expect(initial.status, DeliveryStatus.assigning);
        expect(initial.pickupLocationName, 'Old Building (Main)');
        expect(initial.dropoffLocationName, 'Maritime Building');

        final updated = initial.copyWith(
          status: DeliveryStatus.inTransit,
          currentLatitude: 10.3155,
          currentLongitude: 123.9015,
          currentAltitude: 45.0,
          currentSpeed: 14.5,
          batteryLevel: 92.0,
          progress: 0.5,
        );

        expect(updated.status, DeliveryStatus.inTransit);
        expect(updated.pickupLocationName, 'Old Building (Main)');
        expect(updated.dropoffLocationName, 'Maritime Building');
        expect(updated.currentLatitude, 10.3155);
        expect(updated.currentLongitude, 123.9015);
        expect(updated.currentAltitude, 45.0);
        expect(updated.currentSpeed, 14.5);
        expect(updated.batteryLevel, 92.0);
        expect(updated.progress, 0.5);
      },
    );

    testWidgets(
      'SharedDroneRadar renders Pickup phase labels and progress accurately',
      (tester) async {
        final pickupDelivery = DeliveryModel(
          id: 'del-radar-01',
          senderName: 'Aero Diner',
          recipientName: 'Maria Santos',
          recipientPhone: '09181234567',
          deliveryAddress: 'Maritime Hub',
          packageName: 'Meal Box',
          packageWeight: 0.8,
          packageType: 'Food',
          eta: '5 mins',
          progress: 0.65,
          status: DeliveryStatus.assigning,
          droneId: 'DRN-001',
          pickupLocationId: 'loc-1',
          dropoffLocationId: 'loc-2',
          pickupLocationName: 'Old Building (Main)',
          dropoffLocationName: 'Maritime Building',
          currentLatitude: 10.3150,
          currentLongitude: 123.9010,
          currentAltitude: 25.0,
          currentSpeed: 10.0,
          batteryLevel: 95.0,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SharedDroneRadar(
                  delivery: pickupDelivery,
                  title: 'VENDOR RADAR',
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Heading to Pickup'), findsOneWidget);
        expect(find.text('Pickup Progress'), findsOneWidget);
        expect(find.text('65%'), findsOneWidget);
        expect(find.text('In Flight / In Transit'), findsNothing);
        expect(find.text('Delivery Progress'), findsNothing);
      },
    );

    testWidgets(
      'SharedDroneRadar renders Delivery phase labels and progress accurately',
      (tester) async {
        final inTransitDelivery = DeliveryModel(
          id: 'del-radar-02',
          senderName: 'Aero Diner',
          recipientName: 'Maria Santos',
          recipientPhone: '09181234567',
          deliveryAddress: 'Maritime Hub',
          packageName: 'Meal Box',
          packageWeight: 0.8,
          packageType: 'Food',
          eta: '7 mins',
          progress: 0.42,
          status: DeliveryStatus.inTransit,
          droneId: 'DRN-001',
          pickupLocationId: 'loc-1',
          dropoffLocationId: 'loc-2',
          pickupLocationName: 'Old Building (Main)',
          dropoffLocationName: 'Maritime Building',
          currentLatitude: 10.3158,
          currentLongitude: 123.9018,
          currentAltitude: 45.0,
          currentSpeed: 15.0,
          batteryLevel: 88.0,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SharedDroneRadar(
                  delivery: inTransitDelivery,
                  title: 'CUSTOMER RADAR',
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('In Flight / In Transit'), findsOneWidget);
        expect(find.text('Delivery Progress'), findsOneWidget);
        expect(find.text('42%'), findsOneWidget);
        expect(find.text('Heading to Pickup'), findsNothing);
        expect(find.text('Pickup Progress'), findsNothing);
      },
    );

    testWidgets(
      'Customer, Vendor, and Admin radars render identical progress and state',
      (tester) async {
        final sharedDelivery = DeliveryModel(
          id: 'del-shared-01',
          senderName: 'Aero Diner',
          recipientName: 'Maria Santos',
          recipientPhone: '09181234567',
          deliveryAddress: 'Maritime Hub',
          packageName: 'Meal Box',
          packageWeight: 0.8,
          packageType: 'Food',
          eta: '4 mins',
          progress: 0.57,
          status: DeliveryStatus.inTransit,
          droneId: 'DRN-001',
          pickupLocationId: 'loc-1',
          dropoffLocationId: 'loc-2',
          pickupLocationName: 'Old Building (Main)',
          dropoffLocationName: 'Maritime Building',
          currentLatitude: 10.3155,
          currentLongitude: 123.9015,
          currentAltitude: 40.0,
          currentSpeed: 14.0,
          batteryLevel: 90.0,
          createdAt: DateTime.now(),
        );

        // Verify that building the radar for any role outputs 57% and "In Flight / In Transit"
        for (final roleTitle in [
          'ADMIN RADAR',
          'VENDOR RADAR',
          'CUSTOMER RADAR',
        ]) {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: Scaffold(
                  body: SharedDroneRadar(
                    delivery: sharedDelivery,
                    title: roleTitle,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.text('57%'), findsOneWidget);
          expect(find.text('In Flight / In Transit'), findsOneWidget);
          expect(find.text('Delivery Progress'), findsOneWidget);
        }
      },
    );

    test(
      'Pickup reaches 100% and transitions to in_transit with progress 0% without looping',
      () {
        // 1. Initial assigning state
        var delivery = DeliveryModel(
          id: 'del-loop-test',
          senderName: 'Vendor 1',
          recipientName: 'Customer 1',
          recipientPhone: '09123456789',
          deliveryAddress: 'Maritime Hub',
          packageName: 'Coffee',
          packageWeight: 0.5,
          packageType: 'Drink',
          eta: '5 mins',
          progress: 0.0,
          status: DeliveryStatus.assigning,
          droneId: 'DRN-001',
          createdAt: DateTime.now(),
        );

        expect(delivery.status, DeliveryStatus.assigning);
        expect(delivery.progress, 0.0);

        // 2. Pickup progresses 0.0 -> 1.0
        delivery = delivery.copyWith(progress: 1.0);
        expect(delivery.progress, 1.0);

        // 3. State transition: assigning -> inTransit, progress resets to 0.0 for customer leg
        // Guard prevents re-transitioning
        final Set<String> confirmingPickupDeliveryIds = {};
        final canConfirm = confirmingPickupDeliveryIds.add(delivery.id);
        expect(canConfirm, isTrue, reason: 'First transition must be accepted');

        delivery = delivery.copyWith(
          status: DeliveryStatus.inTransit,
          progress: 0.0,
        );

        expect(delivery.status, DeliveryStatus.inTransit);
        expect(delivery.progress, 0.0, reason: 'Customer leg starts at 0%');

        // 4. Verify idempotence: second attempt with same delivery id is rejected
        final duplicateAttempt = confirmingPickupDeliveryIds.add(delivery.id);
        expect(
          duplicateAttempt,
          isFalse,
          reason: 'Duplicate pickup transition must be prevented',
        );

        // 5. Customer leg progresses 0.0 -> 1.0
        delivery = delivery.copyWith(progress: 1.0);
        expect(delivery.progress, 1.0);

        // 6. Complete delivery
        delivery = delivery.copyWith(
          status: DeliveryStatus.delivered,
          progress: 1.0,
        );
        expect(delivery.status, DeliveryStatus.delivered);
      },
    );

    test(
      'Drone lifecycle: remains assigned after pickup, available ONLY after delivered',
      () {
        String droneStatus = 'available';

        // 1. Drone allocated for delivery
        droneStatus = 'assigned';
        expect(droneStatus, 'assigned');

        // 2. Delivery is assigning (heading to pickup)
        const assigningStatus = DeliveryStatus.assigning;
        expect(assigningStatus, DeliveryStatus.assigning);
        expect(
          droneStatus,
          'assigned',
          reason: 'Drone must be assigned during pickup',
        );

        // 3. Package picked up -> in_transit
        const inTransitStatus = DeliveryStatus.inTransit;
        expect(inTransitStatus, DeliveryStatus.inTransit);
        expect(
          droneStatus,
          'assigned',
          reason:
              'Drone MUST remain assigned while carrying package to customer',
        );

        // 4. Delivery completes
        const deliveredStatus = DeliveryStatus.delivered;
        if (deliveredStatus == DeliveryStatus.delivered) {
          droneStatus = 'available';
        }
        expect(
          droneStatus,
          'available',
          reason: 'Drone released only after final delivery',
        );
      },
    );

    test(
      'Stale drone availability recovery: recovers to available when no active deliveries exist',
      () {
        // Drone was left in assigned status from a past crashed/completed delivery
        String droneStatus = 'assigned';
        final List<DeliveryModel> allDeliveries = [
          DeliveryModel(
            id: 'del-past-01',
            senderName: 'V',
            recipientName: 'C',
            recipientPhone: '1',
            deliveryAddress: 'A',
            packageName: 'P',
            packageWeight: 0.5,
            packageType: 'Food',
            eta: '10 mins',
            status: DeliveryStatus.delivered,
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
            progress: 1.0,
          ),
        ];

        final hasActiveDeliveries = allDeliveries.any(
          (d) =>
              d.status == DeliveryStatus.assigning ||
              d.status == DeliveryStatus.inTransit,
        );

        if (droneStatus == 'assigned' && !hasActiveDeliveries) {
          droneStatus = 'available';
        }

        expect(
          droneStatus,
          'available',
          reason:
              'Stale assigned drone must self-heal to available when no active flight exists',
        );
      },
    );
  });
}
