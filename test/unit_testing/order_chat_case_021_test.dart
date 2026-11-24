import 'package:aerodrop/core/providers/order_chat_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test Case ID: CASE-021', () {
    test(
      'Test Case Description: Customer sends "Please leave it with the guard if I am not there." to Kape Kanto | '
      'Expected Result: The message passes the checks and goes to the server; an empty or over-long message is refused before sending',
      () async {
        final chat = OrderChatNotifier('68efac5f-0000-4000-a000-000000000000');
        addTearDown(chat.dispose);

        await expectLater(chat.sendMessage('   '), throwsA(isA<ArgumentError>()));
        await expectLater(chat.sendMessage('x' * (kOrderMessageMaxLength + 1)), throwsA(isA<ArgumentError>()));

        // A real message clears every local check and reaches the network step,
        // which this offline test reports as unavailable.
        await expectLater(
          chat.sendMessage('Please leave it with the guard if I am not there.'),
          throwsA(isA<StateError>().having((e) => e.message, 'message', 'Messaging is unavailable offline.')),
        );
      },
    );
  });
}
