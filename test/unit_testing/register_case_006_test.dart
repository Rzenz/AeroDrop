import 'package:aerodrop/core/widgets/neu_button.dart';
import 'package:aerodrop/features/auth/presentation/controllers/register_controller.dart';
import 'package:aerodrop/features/auth/register_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-006', () {
    testWidgets(
      'Test Case Description: User enters an invalid phone number (12345) | '
      'Expected Result: Phone is rejected and the Register Account button stays disabled',
      (tester) async {
        expect(
          RegisterController.validatePhone('12345'),
          'Please enter a valid phone number (e.g. 09123456789 or +639123456789)',
        );

        await pumpScreen(tester, const RegisterScreen());
        await fillField(tester, 0, 'Juan Dela Cruz');
        await fillField(tester, 1, 'juan.delacruz@gmail.com');
        await fillField(tester, 2, '12345');
        await fillField(tester, 3, 'password123');
        await fillField(tester, 4, 'password123');

        final register = tester.widget<NeuButton>(
          find.ancestor(
            of: find.text('Register Account'),
            matching: find.byType(NeuButton),
          ),
        );
        expect(register.onPressed, isNull);

        // A valid number enables it again.
        await fillField(tester, 2, '09171234567');
        final enabled = tester.widget<NeuButton>(
          find.ancestor(
            of: find.text('Register Account'),
            matching: find.byType(NeuButton),
          ),
        );
        expect(enabled.onPressed, isA<VoidCallback>());
      },
    );
  });
}
