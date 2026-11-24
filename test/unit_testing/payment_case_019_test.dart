import 'package:aerodrop/core/utils/card_validator.dart';
import 'package:aerodrop/features/payment/widgets/simulated_card_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-019', () {
    testWidgets(
      'Test Case Description: Customer pays P147.19 by card with an invalid card number (4111 1111 1111 1112) | '
      "Expected Result: Payment is not made and 'Invalid card number checksum' is shown",
      (tester) async {
        expect(CardValidator.isValidLuhn('4111111111111112'), isFalse);
        expect(CardValidator.isValidLuhn('4111111111111111'), isTrue);

        await pumpScreen(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => SimulatedCardDialog.show(context, amount: 147.19),
                child: const Text('Open card form'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open card form'));
        await tester.pump(const Duration(seconds: 1));

        await fillField(tester, 0, 'Maria Santos');
        await fillField(tester, 1, '4111111111111112');
        await fillField(tester, 2, '1228');
        await fillField(tester, 3, '123');
        await tapButton(tester, 'Pay ₱147.19');

        expect(find.text('Invalid card number checksum'), findsWidgets);
        expect(find.text('Credit / Debit Card'), findsOneWidget); // dialog stays open
      },
    );
  });
}
