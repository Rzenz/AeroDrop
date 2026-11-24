import 'package:aerodrop/features/profile/change_password_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-025', () {
    testWidgets(
      'Test Case Description: User enters the same password (demo1234) as the current and the new password | '
      "Expected Result: Password is not changed and 'New password must be different' is shown",
      (tester) async {
        await pumpScreen(tester, const ChangePasswordPage());

        await fillField(tester, 0, 'demo1234');
        await fillField(tester, 1, 'demo1234');
        await fillField(tester, 2, 'demo1234');
        await tapButton(tester, 'Save Password');

        expect(find.text('New password must be different'), findsWidgets);
      },
    );
  });
}
