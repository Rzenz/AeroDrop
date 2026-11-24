import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/providers/location_provider.dart';
import 'package:aerodrop/features/profile/edit_profile_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';
import '_router.dart';

/// The Kape Kanto vendor; updateProfile() succeeds and records the store name.
class _Vendor extends StateNotifier<AuthState> implements AuthNotifier {
  _Vendor()
    : super(AuthState(
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
      ));
  final savedStores = <Object?>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #updateProfile) savedStores.add(invocation.namedArguments[#businessName]);
    return Future<bool>.value(true);
  }
}

void main() {
  group('Test Case ID: CASE-111', () {
    testWidgets(
      'Test Case Description: Vendor changes the Business Name to "Kape Kanto Express" on Edit Profile and taps Save Changes | '
      "Expected Result: The store details are saved and 'Vendor details updated successfully.' is shown",
      (tester) async {
        final vendor = _Vendor();
        await pumpRouted(
          tester,
          const EditProfileScreen(),
          overrides: [authProvider.overrideWith((ref) => vendor), campusLocationsProvider.overrideWith((ref) async => const [])],
          size: const Size(600, 1600),
        );
        final businessName = find.byType(EditableText).at(3);
        expect(tester.widget<EditableText>(businessName).controller.text, 'Kape Kanto');
        await tester.enterText(businessName, 'Kape Kanto Express');
        await tapButton(tester, 'Save Changes');
        await tester.pump(const Duration(milliseconds: 300));

        expect(vendor.savedStores, ['Kape Kanto Express']);
        expect(find.text('Vendor details updated successfully.'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
