import 'package:aerodrop/core/providers/support_chat_provider.dart';
import 'package:aerodrop/features/shared/help_support_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-026', () {
    testWidgets(
      'Test Case Description: User opens New Report and taps Submit Report without a subject or message | '
      "Expected Result: Report is not sent and 'Please enter a subject' is shown",
      (tester) async {
        await pumpScreen(
          tester,
          const HelpSupportPage(),
          overrides: [mySupportReportsProvider.overrideWith((ref) async => const [])],
        );

        await tapButton(tester, 'New Report');
        await tapButton(tester, 'Submit Report');

        expect(find.text('Please enter a subject'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
