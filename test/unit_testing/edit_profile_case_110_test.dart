import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/providers/location_provider.dart';
import 'package:aerodrop/features/profile/edit_profile_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';
import '_router.dart';

/// A signed-in customer; updateProfile() succeeds and records the new name.
class _Customer extends StateNotifier<AuthState> implements AuthNotifier {
  _Customer()
    : super(AuthState(
        user: AeroDropUser.fromMap({'id': 'maria', 'email': 'maria.santos@uclm.edu.ph', 'full_name': 'Maria Santos', 'phone_number': '+639171234567', 'role': 'user'}),
        isVerified: true,
        sessionUnlocked: true,
      ));
  final savedNames = <Object?>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #updateProfile) savedNames.add(invocation.positionalArguments.first);
    return Future<bool>.value(true);
  }
}

void main() {
  group('Test Case ID: CASE-110', () {
    testWidgets(
      'Test Case Description: Customer changes their Full Name to "Maria L. Santos" on Edit Profile and taps Save Changes | '
      "Expected Result: The profile is saved, 'Profile updated successfully!' is shown and the previous screen returns",
      (tester) async {
        final customer = _Customer();
        await pumpRouted(
          tester,
          const EditProfileScreen(),
          overrides: [authProvider.overrideWith((ref) => customer), campusLocationsProvider.overrideWith((ref) async => const [])],
          size: const Size(600, 1400),
        );
        await tester.enterText(find.byType(EditableText).first, 'Maria L. Santos');
        await tapButton(tester, 'Save Changes');
        await tester.pump(const Duration(milliseconds: 300));

        expect(customer.savedNames, ['Maria L. Santos']);
        expect(find.text('Profile updated successfully!'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text(kPreviousScreen), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
