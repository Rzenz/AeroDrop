import 'package:aerodrop/features/auth/register_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-030', () {
    testWidgets(
      'Test Case Description: Vendor applicant switches Create your account to Vendor and taps Continue without a business name | '
      "Expected Result: The wizard stays on step 1 and shows 'Business Name Required'",
      (tester) async {
        // Wide enough for the test font, which is wider than the app's.
        await pumpScreen(tester, const RegisterScreen(), size: const Size(600, 1400));

        await tapButton(tester, 'Vendor');
        await tester.pump(const Duration(seconds: 1));
        await tapButton(tester, 'Continue');

        expect(find.text('Business Name Required'), findsOneWidget);
        expect(find.text('Please enter your store/business name to proceed.'), findsOneWidget);
      },
    );
  });
}
