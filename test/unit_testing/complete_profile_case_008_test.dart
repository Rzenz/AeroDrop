import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/widgets/neu_button.dart';
import 'package:aerodrop/features/auth/complete_profile_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

class _NoPhone extends StateNotifier<AuthState> implements AuthNotifier {
  _NoPhone()
    : super(AuthState(
        user: AeroDropUser.fromMap({'id': 'maria', 'email': 'maria.santos@uclm.edu.ph', 'full_name': 'Maria Santos', 'phone_number': null, 'role': 'user'}),
        isVerified: true,
        sessionUnlocked: true,
      ));
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<bool>.value(false);
}

NeuButton _save(WidgetTester tester) => tester.widget<NeuButton>(
  find.ancestor(of: find.text('Save and continue'), matching: find.byType(NeuButton)),
);

void main() {
  group('Test Case ID: CASE-008', () {
    testWidgets(
      'Test Case Description: Google-signed-in customer without a mobile number enters 12345 on Complete your profile | '
      'Expected Result: The number is rejected and Save and continue stays disabled until a valid mobile number is entered',
      (tester) async {
        await pumpScreen(tester, const CompleteProfileScreen(), overrides: [authProvider.overrideWith((ref) => _NoPhone())]);

        await fillField(tester, 0, '12345');
        expect(_save(tester).onPressed, isNull);

        await fillField(tester, 0, '09171234567');
        expect(_save(tester).onPressed, isA<VoidCallback>());
      },
    );
  });
}
