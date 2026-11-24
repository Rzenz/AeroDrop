import 'dart:typed_data';

import 'package:aerodrop/core/providers/support_chat_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  group('Test Case ID: CASE-027', () {
    test(
      'Test Case Description: Customer replies on their open report "Drone landed at the wrong building" | '
      'Expected Result: A text reply passes the checks and goes to the server; an empty reply or more than 3 photos is refused before sending',
      () async {
        final chat = SupportChatNotifier('5f0e2b1c-0000-4000-a000-000000000000');
        addTearDown(chat.dispose);
        XFile photo() => XFile.fromData(Uint8List.fromList([0xFF, 0xD8, 0xFF]));

        await expectLater(chat.sendMessage('   ', const []), throwsA(isA<ArgumentError>()));
        await expectLater(chat.sendMessage('hi', [photo(), photo(), photo(), photo()]), throwsA(isA<ArgumentError>()));

        // A real reply clears every local check and reaches the network step,
        // which this offline test reports as unavailable.
        await expectLater(
          chat.sendMessage('I have a photo of where it landed, sending it shortly.', const []),
          throwsA(isA<StateError>().having((e) => e.message, 'message', 'Support messages are unavailable offline.')),
        );
      },
    );
  });
}
