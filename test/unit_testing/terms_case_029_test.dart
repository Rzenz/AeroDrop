import 'package:aerodrop/features/shared/terms_conditions_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-029', () {
    testWidgets(
      'Test Case Description: User opens Terms and conditions from Settings | '
      'Expected Result: The Terms & Conditions page shows its sections, starting with Payload Responsibilities',
      (tester) async {
        await pumpScreen(tester, const TermsConditionsPage());

        expect(find.text('Terms & Conditions'), findsOneWidget);
        expect(find.text('1. Payload Responsibilities'), findsOneWidget);
        expect(find.text('2. Automated Flight Paths'), findsOneWidget);
        expect(find.textContaining('0.5 kg per-trip'), findsOneWidget);
      },
    );
  });
}
