import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/providers/location_provider.dart';
import 'package:aerodrop/features/profile/edit_profile_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

class _Vendor extends StateNotifier<AuthState> implements AuthNotifier {
  _Vendor()
    : super(
        AuthState(
          user: AeroDropUser.fromMap({
            'id': 'kape',
            'email': 'kapekanto@uclm.edu.ph',
            'full_name': 'Jose Ramirez',
            'phone_number': '+639171234567',
            'role': 'vendor',
            'vendor_status': 'active',
            'business_name': 'Kape Kanto',
            'business_category': 'Cafe',
            'business_description': 'Brewed coffee, iced lattes and pastries by the Main Building lobby.',
          }),
          isVerified: true,
          sessionUnlocked: true,
        ),
      );
  int saves = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    saves++;
    return Future<bool>.value(false);
  }
}

void main() {
  group('Test Case ID: CASE-037', () {
    testWidgets(
      'Test Case Description: Vendor clears the Business Name on Edit Profile and taps Save Changes | '
      "Expected Result: Profile is not saved and 'Enter business name' is shown",
      (tester) async {
        final vendor = _Vendor();
        await pumpScreen(
          tester,
          const EditProfileScreen(),
          overrides: [
            authProvider.overrideWith((ref) => vendor),
            campusLocationsProvider.overrideWith((ref) async => const []),
          ],
          // Wide enough for the test font, which is wider than the app's.
          size: const Size(600, 1600),
        );

        final businessName = find.byType(EditableText).at(3);
        expect(tester.widget<EditableText>(businessName).controller.text, 'Kape Kanto');
        await tester.enterText(businessName, '');
        await tapButton(tester, 'Save Changes');

        expect(find.text('Enter business name'), findsWidgets);
        expect(vendor.saves, 0);
      },
    );
  });
}
