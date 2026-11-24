import 'package:aerodrop/features/payment/widgets/simulated_card_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-109', () {
    testWidgets(
      'Test Case Description: Customer pays P147.19 by card with a valid card number (4111 1111 1111 1111), expiry 12/28 and CVV 123 | '
      'Expected Result: The card is accepted, the card form closes and the payment goes ahead with the masked card',
      (tester) async {
        String? paidWith;
        await pumpScreen(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => paidWith = await SimulatedCardDialog.show(context, amount: 147.19),
                child: const Text('Open card form'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open card form'));
        await tester.pump(const Duration(seconds: 1));
        await fillField(tester, 0, 'Maria Santos');
        await fillField(tester, 1, '4111111111111111');
        await fillField(tester, 2, '1228');
        await fillField(tester, 3, '123');
        await tapButton(tester, 'Pay ₱147.19');
        await tester.pump(const Duration(seconds: 3));

        expect(find.text('Invalid card number checksum'), findsNothing);
        expect(find.text('Credit / Debit Card'), findsNothing); // dialog closed
        expect(paidWith, isNotNull);
        expect(paidWith, contains('1111'));
      },
    );
  });
}
