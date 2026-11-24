import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/features/auth/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-003', () {
    testWidgets(
      'Test Case Description: User enters a registered email with a wrong password | '
      "Expected Result: Login fails with 'Incorrect credentials or invalid verification code.'",
      (tester) async {
        await pumpScreen(
          tester,
          const LoginScreen(),
          overrides: [
            authProvider.overrideWith(
              (ref) => FakeAuth(
                loginError: const AuthException(
                  'Invalid login credentials',
                  code: 'invalid_credentials',
                ),
              ),
            ),
          ],
        );

        await fillField(tester, 0, 'maria.santos@uclm.edu.ph');
        await fillField(tester, 1, 'wrongpass1');
        await tapButton(tester, 'Login');

        expect(
          find.text('Incorrect credentials or invalid verification code.'),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
