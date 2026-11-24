import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/providers/location_provider.dart';
import 'package:aerodrop/features/profile/edit_profile_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

class _Customer extends StateNotifier<AuthState> implements AuthNotifier {
  _Customer()
    : super(AuthState(
        user: AeroDropUser.fromMap({'id': 'maria', 'email': 'maria.santos@uclm.edu.ph', 'full_name': 'Maria Santos', 'phone_number': '+639171234567', 'role': 'user'}),
        isVerified: true,
        sessionUnlocked: true,
      ));
  int saves = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    saves++;
    return Future<bool>.value(false);
  }
}

void main() {
  group('Test Case ID: CASE-024', () {
    testWidgets(
      'Test Case Description: Customer clears their Full Name on Edit Profile and taps Save Changes | '
      "Expected Result: Profile is not saved and 'Enter name' is shown",
      (tester) async {
        final customer = _Customer();
        await pumpScreen(
          tester,
          const EditProfileScreen(),
          overrides: [authProvider.overrideWith((ref) => customer), campusLocationsProvider.overrideWith((ref) async => const [])],
          size: const Size(600, 1400),
        );

        final name = find.byType(EditableText).first;
        expect(tester.widget<EditableText>(name).controller.text, 'Maria Santos');
        await tester.enterText(name, '');
        await tapButton(tester, 'Save Changes');

        expect(find.text('Enter name'), findsWidgets);
        expect(customer.saves, 0);
      },
    );
  });
}
