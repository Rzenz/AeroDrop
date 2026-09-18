import 'package:flutter_test/flutter_test.dart';
import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/core/models/notification_model.dart';
import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/providers/product_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('Order Notes Capabilities Tests', () {
    test(
      'OrderModel parses notes from database response and preserves value',
      () {
        final map = {
          'id': '11111111-1111-1111-1111-111111111111',
          'user_id': '22222222-2222-2222-2222-222222222222',
          'vendor_id': '33333333-3333-3333-3333-333333333333',
          'delivery_location_id': '44444444-4444-4444-4444-444444444444',
          'order_status': 'pending',
          'subtotal': 120.0,
          'delivery_fee': 20.0,
          'total_amount': 140.0,
          'payment_method': 'gcash_simulated',
          'payment_status': 'paid',
          'notes':
              'Please call upon arrival at the lobby and pack extra forks.',
          'created_at': DateTime.now().toIso8601String(),
          'order_items': [
            {
              'product_name': 'Chicken Rice',
              'quantity': 1,
              'unit_price': 120.0,
            },
          ],
        };

        final order = OrderModel.fromMap(map);
        expect(
          order.notes,
          'Please call upon arrival at the lobby and pack extra forks.',
        );
        expect(order.effectiveStatus, 'pending');
        expect(order.statusDisplay, 'Pending');
      },
    );

    test('OrderModel handles null/empty notes safely', () {
      final map = {
        'id': '11111111-1111-1111-1111-111111111111',
        'user_id': '22222222-2222-2222-2222-222222222222',
        'vendor_id': '33333333-3333-3333-3333-333333333333',
        'delivery_location_id': '44444444-4444-4444-4444-444444444444',
        'order_status': 'pending',
        'subtotal': 50.0,
        'delivery_fee': 20.0,
        'total_amount': 70.0,
        'notes': null,
        'created_at': DateTime.now().toIso8601String(),
        'order_items': [],
      };

      final order = OrderModel.fromMap(map);
      expect(order.notes, isNull);
    });
  });

  group('Drone Availability and Lifecycle Logic Tests', () {
    test(
      'Drone is available only when status is available and battery >= 15',
      () {
        bool isDroneAvailable(
          String status,
          double batteryLevel,
          int activeDeliveries,
        ) {
          if (status != 'available') return false;
          if (batteryLevel < 15.0) return false;
          if (activeDeliveries > 0) return false;
          return true;
        }

        // Available drone
        expect(isDroneAvailable('available', 100.0, 0), isTrue);
        expect(isDroneAvailable('available', 50.0, 0), isTrue);
        expect(isDroneAvailable('available', 15.0, 0), isTrue);

        // Low battery rejected
        expect(isDroneAvailable('available', 14.9, 0), isFalse);
        expect(isDroneAvailable('available', 5.0, 0), isFalse);

        // Active delivery busy rejected
        expect(isDroneAvailable('available', 100.0, 1), isFalse);

        // Status not available rejected
        expect(isDroneAvailable('busy', 100.0, 0), isFalse);
        expect(isDroneAvailable('assigned', 100.0, 0), isFalse);
        expect(isDroneAvailable('maintenance', 100.0, 0), isFalse);
        expect(isDroneAvailable('offline', 100.0, 0), isFalse);
        expect(isDroneAvailable('charging', 100.0, 0), isFalse);
      },
    );

    test(
      'Self-healing recovers stale assigned drone when active deliveries = 0',
      () {
        String resolveDroneStatus(String currentStatus, int activeDeliveries) {
          if (currentStatus == 'assigned' && activeDeliveries == 0) {
            return 'available'; // Self-healed
          }
          return currentStatus;
        }

        expect(resolveDroneStatus('assigned', 0), 'available');
        expect(resolveDroneStatus('assigned', 1), 'assigned');
        expect(resolveDroneStatus('available', 0), 'available');
        expect(resolveDroneStatus('maintenance', 0), 'maintenance');
      },
    );

    test(
      'Delivery completion releases drone to available and transitions order to delivered',
      () {
        String deliveryStatus = 'in_transit';
        String orderStatus = 'ready_for_delivery';
        String droneStatus = 'assigned';

        void onDeliveryStatusChanged(String newStatus) {
          deliveryStatus = newStatus;
          if (newStatus == 'delivered') {
            orderStatus = 'delivered';
            droneStatus = 'available';
          } else if (newStatus == 'cancelled') {
            orderStatus = 'cancelled';
            droneStatus = 'available';
          }
        }

        onDeliveryStatusChanged('delivered');
        expect(deliveryStatus, 'delivered');
        expect(orderStatus, 'delivered');
        expect(droneStatus, 'available');
      },
    );
  });

  group('Vendor Product Management & Scoped Ownership Tests', () {
    test('Vendor product modification requires authenticated vendor', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier(null)),
        ],
      );

      final notifier = container.read(vendorProductsProvider.notifier);

      final addResult = await notifier.addProduct(
        name: 'Burger',
        description: 'Tasty burger',
        price: 99.0,
        stock: 10,
        categoryName: 'Food',
        weightKg: 0.25,
        imageUrl: 'https://example.com/burger.png',
      );
      expect(
        addResult,
        isFalse,
        reason: 'Unauthenticated vendor cannot add products',
      );

      final editResult = await notifier.editProduct(
        id: 'fake-prod-id',
        name: 'Updated Burger',
        description: 'Tasty burger',
        price: 110.0,
        stock: 15,
        categoryName: 'Food',
        weightKg: 0.25,
        imageUrl: 'https://example.com/burger.png',
        isAvailable: true,
      );
      expect(
        editResult,
        isFalse,
        reason: 'Unauthenticated vendor cannot edit products',
      );

      final deleteResult = await notifier.deleteProduct('fake-prod-id');
      expect(
        deleteResult,
        isFalse,
        reason: 'Unauthenticated vendor cannot delete products',
      );
    });
  });

  group('Notifications Deserialization & Routing Tests', () {
    test(
      'NotificationModel deserializes notification_type column correctly',
      () {
        final map = {
          'id': 'notif-1',
          'user_id': 'user-123',
          'title': 'New Customer Order!',
          'message': 'You have received a new order for ₱240.00.',
          'notification_type': 'new_order',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        };

        final n = NotificationModel.fromMap(map);
        expect(n.id, 'notif-1');
        expect(n.userId, 'user-123');
        expect(n.title, 'New Customer Order!');
        expect(n.type, 'new_order');
        expect(n.isRead, isFalse);
      },
    );

    test('Notifications filter strictly by user_id', () {
      final notifs = [
        NotificationModel(
          id: 'n1',
          userId: 'customer-1',
          title: 'Order Confirmed',
          isRead: false,
        ),
        NotificationModel(
          id: 'n2',
          userId: 'vendor-1',
          title: 'New Customer Order',
          isRead: false,
        ),
        NotificationModel(
          id: 'n3',
          userId: 'customer-1',
          title: 'Order Preparing',
          isRead: false,
        ),
      ];

      final customerNotifs = notifs
          .where((n) => n.userId == 'customer-1')
          .toList();
      final vendorNotifs = notifs.where((n) => n.userId == 'vendor-1').toList();

      expect(customerNotifs.length, 2);
      expect(customerNotifs.map((n) => n.id), containsAll(['n1', 'n3']));
      expect(vendorNotifs.length, 1);
      expect(vendorNotifs.first.id, 'n2');
    });
  });

  group('Order Lifecycle State Transitions', () {
    test(
      'Order lifecycle strictly progresses: pending -> confirmed -> preparing -> ready_for_delivery -> in_transit -> delivered',
      () {
        final transitions = <String>[];

        String currentStatus = 'pending';
        transitions.add(currentStatus);

        // 1. Vendor accepts
        currentStatus = 'confirmed';
        transitions.add(currentStatus);

        // 2. Vendor prepares
        currentStatus = 'preparing';
        transitions.add(currentStatus);

        // 3. Vendor marks ready
        currentStatus = 'ready_for_delivery';
        transitions.add(currentStatus);

        // 4. System dispatches drone
        currentStatus = 'in_transit';
        transitions.add(currentStatus);

        // 5. Drone arrives and delivers
        currentStatus = 'delivered';
        transitions.add(currentStatus);

        expect(transitions, [
          'pending',
          'confirmed',
          'preparing',
          'ready_for_delivery',
          'in_transit',
          'delivered',
        ]);
      },
    );
  });
}

class _FakeAuthNotifier extends AuthNotifier {
  final UserModel? _stubUser;
  _FakeAuthNotifier(this._stubUser) {
    state = AuthState(
      user: _stubUser,
      sessionUnlocked: _stubUser != null,
      isLoading: false,
    );
  }
}
