import 'package:aerodrop/core/models/notification_model.dart';
import 'package:aerodrop/core/providers/notification_provider.dart';
import 'package:aerodrop/features/vendor/vendor_notifications_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

class _FakeNotifications extends NotificationNotifier {
  _FakeNotifications() {
    state = [
      NotificationModel(id: 'n1', title: 'New order', message: 'Paolo Reyes placed an order for 2 items.', type: 'new_order', isRead: false, createdAt: DateTime.now().subtract(const Duration(minutes: 4))),
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
  group('Test Case ID: CASE-036', () {
    testWidgets(
      'Test Case Description: Vendor taps Mark all as read on the Notifications screen with 1 unread notification | '
      "Expected Result: Every notification is marked read and 'All notifications marked as read.' is shown",
      (tester) async {
        late _FakeNotifications fake;
        await pumpScreen(
          tester,
          const VendorNotificationsScreen(),
          overrides: [notificationProvider.overrideWith((ref) => fake = _FakeNotifications())],
        );
        expect(find.text('New order'), findsOneWidget);
        expect(fake.state.where((n) => !n.isRead).length, 1);

        await tester.tap(find.byTooltip('Mark all as read'));
        await tester.pump(const Duration(milliseconds: 600));

        expect(fake.state.where((n) => !n.isRead), isEmpty);
        expect(find.text('All notifications marked as read.'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
