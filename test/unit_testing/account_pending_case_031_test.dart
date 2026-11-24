import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/features/auth/presentation/pages/account_pending_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

class _PendingVendor extends StateNotifier<AuthState> implements AuthNotifier {
  _PendingVendor()
    : super(
        AuthState(
          user: AeroDropUser.fromMap({
            'id': 'pan',
            'email': 'pandemandaue@uclm.edu.ph',
            'full_name': 'Elena Bautista',
            'phone_number': '+639171234567',
            // An applicant stays a customer account until an admin approves the store.
            'role': 'user',
            'vendor_status': 'pending',
            'business_name': 'Pan de Mandaue',
            'created_at': '2026-11-16T08:00:00Z',
          }),
          isVerified: true,
          sessionUnlocked: true,
        ),
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<bool>.value(false);
}

void main() {
  group('Test Case ID: CASE-031', () {
    testWidgets(
      'Test Case Description: Vendor applicant Pan de Mandaue signs in before an admin approves the store | '
      "Expected Result: The Application Under Review page is shown with status 'Pending Review'",
      (tester) async {
        final pan = _PendingVendor();
        expect(pan.state.user!.isPendingVendor, isTrue);
        expect(pan.state.user!.isVendor, isFalse);

        await pumpScreen(tester, const AccountPendingPage(), overrides: [authProvider.overrideWith((ref) => pan)]);

        expect(find.text('Application Under Review'), findsOneWidget);
        expect(find.text('Pan de Mandaue'), findsOneWidget);
        expect(find.text('Pending Review'), findsOneWidget);
      },
    );
  });
}
