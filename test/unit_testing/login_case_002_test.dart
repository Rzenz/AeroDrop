import 'package:aerodrop/features/auth/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-002', () {
    testWidgets(
      'Test Case Description: User taps Login with empty email and password | '
      "Expected Result: Login fails with 'Email is required' and 'Password is required'",
      (tester) async {
        await pumpScreen(tester, const LoginScreen());

        await tapButton(tester, 'Login');

        expect(find.text('Email is required'), findsWidgets);
        expect(find.text('Password is required'), findsWidgets);
      },
    );
  });
}
