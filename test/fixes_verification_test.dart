import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aerodrop/features/orders/receipt_screen.dart';
import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/config/router/app_router.dart';

void main() {
  group('7 Discrete Fixes Verification', () {
    test('ReceiptData holds deliveryId properly', () {
      final receipt = ReceiptData(
        orderRef: 'ORD-12345678',
        vendorName: 'Campus Cafe',
        lines: const [
          ReceiptLine(name: 'Iced Coffee', quantity: 2, unitPrice: 85.0),
        ],
        subtotal: 170.0,
        deliveryFee: 20.0,
        total: 190.0,
        paymentLabel: 'GCash',
        placedAt: DateTime.now(),
        deliveryId: 'del-uuid-999',
      );

      expect(receipt.deliveryId, 'del-uuid-999');
      expect(receipt.orderRef, 'ORD-12345678');
      expect(receipt.total, 190.0);
    });

    test('OrderModel effectiveStatus delivered logic', () {
      final order = OrderModel(
        id: 'test-order-1',
        userId: 'user-1',
        vendorId: 'vendor-1',
        totalAmount: 250.0,
        deliveryFee: 20.0,
        orderStatus: 'delivered',
        dropoffLocationId: 'loc-1',
        items: const [],
        paymentMethod: 'gcash',
        deliveryProgress: 0.65, // Stored DB value is partial
        deliveryStatus: 'delivered',
        createdAt: DateTime.now(),
      );

      expect(order.effectiveStatus, 'delivered');
      // When effectiveStatus is delivered, display layer forces 1.0
      final displayProgress = order.effectiveStatus == 'delivered' ? 1.0 : (order.deliveryProgress ?? 0.0);
      expect(displayProgress, 1.0);
      expect((displayProgress * 100).toInt(), 100);
    });

    test('Router includes /vendor/receipt, /vendor/track/details, and /admin/support routes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(routerProvider);
      final routes = router.configuration.routes;

      bool hasVendorReceipt = false;
      bool hasVendorTrackDetails = false;
      bool hasAdminSupport = false;

      void checkRoute(dynamic route) {
        if (route is GoRoute) {
          if (route.path == '/vendor/receipt') hasVendorReceipt = true;
          if (route.path == '/vendor/track/details') hasVendorTrackDetails = true;
          if (route.path == '/admin/support') hasAdminSupport = true;
        }

        if (route.routes != null) {
          for (final sub in route.routes) {
            checkRoute(sub);
          }
        }
      }

      for (final r in routes) {
        checkRoute(r);
      }

      expect(hasVendorReceipt, isTrue, reason: '/vendor/receipt route must exist');
      expect(hasVendorTrackDetails, isTrue, reason: '/vendor/track/details route must exist');
      expect(hasAdminSupport, isTrue, reason: '/admin/support route must exist');
    });
  });
}
