import 'package:aerodrop/features/auth/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-001', () {
    testWidgets(
      'Test Case Description: User enters invalid email format | '
      "Expected Result: Login fails with 'Enter a valid email address' error message",
      (tester) async {
        await pumpScreen(tester, const LoginScreen());

        await fillField(tester, 0, 'invalidemail');
        await fillField(tester, 1, '123456');
        await tapButton(tester, 'Login');

        expect(find.text('Enter a valid email address'), findsWidgets);
      },
    );
  });
}
