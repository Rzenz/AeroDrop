import 'package:aerodrop/features/auth/forgot_password_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-007', () {
    testWidgets(
      'Test Case Description: User requests a reset code with an invalid email (juan.delacruz@gmail) | '
      "Expected Result: Request fails with 'Please enter a valid email address' error message",
      (tester) async {
        await pumpScreen(tester, const ForgotPasswordScreen());

        await fillField(tester, 0, 'juan.delacruz@gmail');
        await tapButton(tester, 'Request Code');

        expect(find.text('Please enter a valid email address'), findsWidgets);
      },
    );
  });
}
