import 'package:aerodrop/core/providers/notification_provider.dart';
import 'package:aerodrop/features/vendor/vendor_notifications_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

/// A newly approved vendor who has not received any notification yet.
class _NoNotifications extends NotificationNotifier {
  _NoNotifications() {
    state = const [];
  }
  @override
  Future<void> loadNotifications() async {}
}

void main() {
  group('Test Case ID: CASE-108', () {
    testWidgets(
      'Test Case Description: Newly approved vendor with no notifications opens the vendor Notifications screen | '
      "Expected Result: No notification is listed and 'No notifications yet.' is shown",
      (tester) async {
        await pumpScreen(tester, const VendorNotificationsScreen(), overrides: [notificationProvider.overrideWith((ref) => _NoNotifications())]);

        expect(find.text('No notifications yet.'), findsOneWidget);
        expect(find.text('New order'), findsNothing);
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
