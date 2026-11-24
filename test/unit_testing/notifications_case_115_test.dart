import 'package:aerodrop/core/providers/notification_provider.dart';
import 'package:aerodrop/features/notifications/notifications_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

/// A customer who has not received any notification yet.
class _NoNotifications extends NotificationNotifier {
  _NoNotifications() {
    state = const [];
  }
  @override
  Future<void> loadNotifications() async {}
}

void main() {
  group('Test Case ID: CASE-115', () {
    testWidgets(
      'Test Case Description: New customer with no notifications opens the Notifications screen | '
      "Expected Result: No notification is listed and 'No notifications yet' is shown",
      (tester) async {
        await pumpScreen(tester, const NotificationsScreen(), overrides: [notificationProvider.overrideWith((ref) => _NoNotifications())]);

        expect(find.text('No notifications yet'), findsOneWidget);
        expect(find.text('Drone dispatched'), findsNothing);
      },
    );
  });
}
