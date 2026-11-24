import 'package:aerodrop/features/auth/register_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-005', () {
    testWidgets(
      'Test Case Description: User enters a Confirm Password that differs from the Password | '
      "Expected Result: Registration fails with 'Passwords do not match' error message",
      (tester) async {
        await pumpScreen(tester, const RegisterScreen());

        await fillField(tester, 0, 'Juan Dela Cruz');
        await fillField(tester, 1, 'juan.delacruz@gmail.com');
        await fillField(tester, 2, '09171234567');
        await fillField(tester, 3, 'password123');
        await fillField(tester, 4, 'password321');
        await tapButton(tester, 'Register Account');

        expect(find.text('Passwords do not match'), findsWidgets);
      },
    );
  });
}
