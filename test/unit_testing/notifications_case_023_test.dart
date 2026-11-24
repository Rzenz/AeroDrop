import 'package:aerodrop/core/models/notification_model.dart';
import 'package:aerodrop/core/providers/notification_provider.dart';
import 'package:aerodrop/features/notifications/notifications_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

class _Notifications extends NotificationNotifier {
  _Notifications() {
    final now = DateTime.now();
    state = [
      NotificationModel(id: 'n1', title: 'Drone dispatched', message: 'Your order from Kape Kanto is on its way.', type: 'drone_dispatched', isRead: false, createdAt: now.subtract(const Duration(minutes: 2))),
      NotificationModel(id: 'n2', title: 'Order is being prepared', message: 'Tea Haus is preparing your Classic Milk Tea.', type: 'order_preparing', isRead: false, createdAt: now.subtract(const Duration(minutes: 5))),
      NotificationModel(id: 'n3', title: 'Order delivered', message: 'Your package has arrived at UCLM Maritime Building.', type: 'order_delivered', isRead: true, createdAt: now.subtract(const Duration(hours: 3))),
    ];
  }
  @override
  Future<void> loadNotifications() async {}
  @override
  Future<void> markAllAsRead() async {
    state = [for (final n in state) NotificationModel(id: n.id, title: n.title, message: n.message, type: n.type, isRead: true, createdAt: n.createdAt)];
  }
}

void main() {
  group('Test Case ID: CASE-023', () {
    testWidgets(
      'Test Case Description: Customer opens Notifications with unread updates and taps Mark all read | '
      'Expected Result: The notifications are listed and every one is marked read',
      (tester) async {
        late _Notifications fake;
        await pumpScreen(tester, const NotificationsScreen(), overrides: [notificationProvider.overrideWith((ref) => fake = _Notifications())]);

        expect(find.text('Drone dispatched'), findsOneWidget);
        expect(find.text('Order is being prepared'), findsOneWidget);
        expect(find.text('Order delivered'), findsOneWidget);
        expect(fake.state.where((n) => !n.isRead).length, 2);

        await tester.tap(find.text('Mark all read'));
        await tester.pump(const Duration(milliseconds: 600));

        expect(fake.state.where((n) => !n.isRead), isEmpty);
      },
    );
  });
}
