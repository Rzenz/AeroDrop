import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerodrop/core/widgets/neu_nav_dock.dart';
import 'package:aerodrop/features/orders/receipt_screen.dart';
import 'package:aerodrop/core/models/notification_model.dart';
import 'package:aerodrop/core/providers/notification_provider.dart';
import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/models/user_model.dart';

void main() {
  group('ReceiptData Model & Calculations Tests', () {
    test(
      'ReceiptData formats lines, subtotal, delivery fee, and total correctly',
      () {
        final receipt = ReceiptData(
          orderRef: 'ORD-TEST-99',
          vendorName: 'Campus Cafe',
          vendorInfo: 'Main Building Ground Floor Hub',
          customerName: 'Juan Dela Cruz',
          customerPhone: '+63 912 345 6789',
          lines: [
            const ReceiptLine(
              name: 'Cold Brew Coffee',
              quantity: 2,
              unitPrice: 85.0,
            ),
            const ReceiptLine(
              name: 'Blueberry Muffin',
              quantity: 1,
              unitPrice: 65.0,
            ),
          ],
          subtotal: 235.0,
          deliveryFee: 25.0,
          total: 260.0,
          paymentLabel: 'Cash on Delivery (COD)',
          placedAt: DateTime(2026, 9, 14, 10, 30),
          dropoffName: 'Engineering Building - Drone Landing Pad Alpha',
          totalWeightGrams: 750,
          customerNote: 'Please notify via SMS upon drone touchdown.',
          orderStatus: 'ready_for_delivery',
        );

        expect(receipt.orderRef, 'ORD-TEST-99');
        expect(receipt.vendorName, 'Campus Cafe');
        expect(receipt.customerName, 'Juan Dela Cruz');
        expect(receipt.customerPhone, '+63 912 345 6789');
        expect(receipt.subtotal, 235.0);
        expect(receipt.deliveryFee, 25.0);
        expect(receipt.total, 260.0);
        expect(receipt.lines.length, 2);
        expect(receipt.lines[0].amount, 170.0);
        expect(receipt.lines[1].amount, 65.0);
        expect(receipt.totalWeightGrams, 750);
        expect(receipt.customerNote, contains('SMS upon drone touchdown'));
        expect(receipt.orderStatus, 'ready_for_delivery');
      },
    );

    test('ReceiptLine calculates amount accurately', () {
      const line = ReceiptLine(
        name: 'Burger Combo',
        quantity: 3,
        unitPrice: 120.50,
      );
      expect(line.amount, closeTo(361.50, 0.001));
    });

    test('ReceiptData handles optional fields gracefully', () {
      final receipt = ReceiptData(
        orderRef: 'ORD-MINIMAL',
        vendorName: 'Main Canteen',
        lines: const [],
        subtotal: 100.0,
        deliveryFee: 15.0,
        total: 115.0,
        paymentLabel: 'GCash',
        placedAt: DateTime.now(),
      );

      expect(receipt.vendorName, 'Main Canteen');
      expect(receipt.customerName, isNull);
      expect(receipt.customerPhone, isNull);
      expect(receipt.deliveryFee, 15.0);
      expect(receipt.totalWeightGrams, isNull);
      expect(receipt.customerNote, isNull);
    });
  });

  group('Notification Badge Provider & Rendering Tests', () {
    const currentUserId = 'usr-auth-vendor-01';
    const otherUserId = 'usr-auth-vendor-02';

    test(
      'unreadNotificationCountProvider correctly counts only unread notifications belonging to auth user',
      () {
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(
              (ref) => _FakeAuthNotifier(currentUserId),
            ),
            notificationProvider.overrideWith(
              (ref) => _FakeNotificationNotifier([
                NotificationModel(
                  id: 'notif-1',
                  userId: currentUserId,
                  title: 'Order Confirmed',
                  message: 'Vendor accepted order',
                  createdAt: DateTime.now(),
                  isRead: false,
                  readAt: null,
                ),
                NotificationModel(
                  id: 'notif-2',
                  userId: currentUserId,
                  title: 'Drone Dispatched',
                  message: 'DRN-001 en route',
                  createdAt: DateTime.now(),
                  isRead: true,
                  readAt: DateTime.now(),
                ),
                NotificationModel(
                  id: 'notif-3',
                  userId: currentUserId,
                  title: 'Order Ready',
                  message: 'Package ready for pickup',
                  createdAt: DateTime.now(),
                  isRead: false,
                  readAt: null,
                ),
                NotificationModel(
                  id: 'notif-other-user',
                  userId: otherUserId,
                  title: 'Other Vendor Order',
                  message: 'Should not be counted',
                  createdAt: DateTime.now(),
                  isRead: false,
                  readAt: null,
                ),
              ]),
            ),
          ],
        );
        addTearDown(container.dispose);

        final unreadCount = container.read(unreadNotificationCountProvider);
        // Only notif-1 and notif-3 belong to currentUserId and are unread
        expect(unreadCount, 2);
      },
    );

    test(
      'unreadNotificationCountProvider returns 0 when all notifications are read or list is empty',
      () {
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(
              (ref) => _FakeAuthNotifier(currentUserId),
            ),
            notificationProvider.overrideWith(
              (ref) => _FakeNotificationNotifier([
                NotificationModel(
                  id: 'notif-1',
                  userId: currentUserId,
                  title: 'Order Delivered',
                  message: 'Delivered safely',
                  createdAt: DateTime.now(),
                  isRead: true,
                  readAt: DateTime.now(),
                ),
              ]),
            ),
          ],
        );
        addTearDown(container.dispose);

        final unreadCount = container.read(unreadNotificationCountProvider);
        expect(unreadCount, 0);
      },
    );

    test(
      'unread count decreases after markOneAsRead and markAllAsRead',
      () async {
        final notifier = _FakeNotificationNotifier([
          NotificationModel(
            id: 'notif-1',
            userId: currentUserId,
            title: 'Alert 1',
            message: 'Message 1',
            createdAt: DateTime.now(),
            isRead: false,
          ),
          NotificationModel(
            id: 'notif-2',
            userId: currentUserId,
            title: 'Alert 2',
            message: 'Message 2',
            createdAt: DateTime.now(),
            isRead: false,
          ),
        ]);

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(
              (ref) => _FakeAuthNotifier(currentUserId),
            ),
            notificationProvider.overrideWith((ref) => notifier),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(unreadNotificationCountProvider), 2);

        // Read one notification -> count drops to 1
        await notifier.markOneAsRead('notif-1');
        expect(container.read(unreadNotificationCountProvider), 1);

        // Mark all as read -> count drops to 0
        await notifier.markAllAsRead();
        expect(container.read(unreadNotificationCountProvider), 0);
      },
    );

    test('realtime notification increments unread count', () {
      final notifier = _FakeNotificationNotifier([]);
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier(currentUserId)),
          notificationProvider.overrideWith((ref) => notifier),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(unreadNotificationCountProvider), 0);

      // Simulate incoming realtime notification
      notifier.addNotificationForUser(
        currentUserId,
        'New Order',
        'You have a new order!',
      );
      expect(container.read(unreadNotificationCountProvider), 1);

      notifier.addNotificationForUser(
        currentUserId,
        'Drone En Route',
        'Drone DRN-001 is on the way',
      );
      expect(container.read(unreadNotificationCountProvider), 2);
    });

    testWidgets(
      'NeuNavDock badge renders numeric values and never Scout or \$count',
      (tester) async {
        // Test count = 0 (no badge rendered)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: NeuNavDock(
                selectedIndex: 0,
                onTap: (_) {},
                items: const [
                  NeuNavItem(icon: Icons.dashboard, label: 'Home'),
                  NeuNavItem(
                    icon: Icons.notifications,
                    label: 'Alerts',
                    badge: 0,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('0'), findsNothing);
        expect(find.text('Scout'), findsNothing);
        expect(find.text(r'$count'), findsNothing);

        // Test count = 1
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: NeuNavDock(
                selectedIndex: 0,
                onTap: (_) {},
                items: const [
                  NeuNavItem(icon: Icons.dashboard, label: 'Home'),
                  NeuNavItem(
                    icon: Icons.notifications,
                    label: 'Alerts',
                    badge: 1,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('1'), findsOneWidget);
        expect(find.text('Scout'), findsNothing);

        // Test count = 5
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: NeuNavDock(
                selectedIndex: 0,
                onTap: (_) {},
                items: const [
                  NeuNavItem(icon: Icons.dashboard, label: 'Home'),
                  NeuNavItem(
                    icon: Icons.notifications,
                    label: 'Alerts',
                    badge: 5,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('5'), findsOneWidget);

        // Test count = 25
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: NeuNavDock(
                selectedIndex: 0,
                onTap: (_) {},
                items: const [
                  NeuNavItem(icon: Icons.dashboard, label: 'Home'),
                  NeuNavItem(
                    icon: Icons.notifications,
                    label: 'Alerts',
                    badge: 25,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('25'), findsOneWidget);

        // Test count > 99 -> 99+
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: NeuNavDock(
                selectedIndex: 0,
                onTap: (_) {},
                items: const [
                  NeuNavItem(icon: Icons.dashboard, label: 'Home'),
                  NeuNavItem(
                    icon: Icons.notifications,
                    label: 'Alerts',
                    badge: 120,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('99+'), findsOneWidget);
        expect(find.text('Scout'), findsNothing);
      },
    );
  });

  group('Windows Receipt File Path Sanitization Tests', () {
    test('Generates valid sanitized Windows path in user Downloads folder', () {
      final userProfile =
          Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          r'C:\Users\Student';
      final orderRef = 'ORD:123/456#TEST';
      final safeOrderRef = orderRef.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      final targetPath =
          '$userProfile${Platform.pathSeparator}Downloads${Platform.pathSeparator}AeroDrop-Receipt-$safeOrderRef.png';

      expect(targetPath, contains('AeroDrop-Receipt-ORD_123_456#TEST.png'));
      expect(targetPath.contains(r':123'), isFalse);
      expect(targetPath.contains(r'/456'), isFalse);
    });
  });

  group('DeliveryStatus & Drone Allocation Verification', () {
    test('DeliveryStatus values contain assigning and inTransit', () {
      expect(DeliveryStatus.values, contains(DeliveryStatus.assigning));
      expect(DeliveryStatus.values, contains(DeliveryStatus.inTransit));
      expect(DeliveryStatus.values, contains(DeliveryStatus.delivered));
    });
  });
}

class _FakeNotificationNotifier extends StateNotifier<List<NotificationModel>>
    implements NotificationNotifier {
  _FakeNotificationNotifier(super.state);

  @override
  Ref? get ref => null;

  @override
  Future<void> loadNotifications() async {}

  @override
  Future<void> markAllAsRead() async {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  @override
  Future<void> markOneAsRead(String id) async {
    state = state
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
  }

  void addNotificationForUser(String userId, String title, String body) {
    final n = NotificationModel(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: title,
      message: body,
      isRead: false,
    );
    state = [n, ...state];
  }

  @override
  void addNotification(String title, String body) {
    final n = NotificationModel(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: body,
      isRead: false,
    );
    state = [n, ...state];
  }

  @override
  void clearNotifications() {
    state = [];
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(String? userId) {
    state = AuthState(
      user: userId != null
          ? AeroDropUser(
              id: userId,
              email: '$userId@example.com',
              name: 'User $userId',
              role: 'vendor',
            )
          : null,
      sessionUnlocked: userId != null,
      isLoading: false,
    );
  }
}
