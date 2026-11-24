import 'package:aerodrop/features/auth/register_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-113', () {
    testWidgets(
      'Test Case Description: Vendor applicant switches Create your account to Vendor, enters the business name "Pan de Mandaue" and taps Continue | '
      "Expected Result: The wizard moves on to step 2 of 4 without an error",
      (tester) async {
        await pumpScreen(tester, const RegisterScreen(), size: const Size(600, 1400));
        await tapButton(tester, 'Vendor');
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Step 1 of 4'), findsOneWidget);
        await fillField(tester, 0, 'Pan de Mandaue');
        await tapButton(tester, 'Continue');
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Business Name Required'), findsNothing);
        expect(find.text('Step 2 of 4'), findsOneWidget);
      },
    );
  });
}
