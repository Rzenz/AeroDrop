import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/widgets/verify_email_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

AeroDropUser _paolo({String? verifiedAt}) => AeroDropUser.fromMap({
  'id': 'paolo',
  'email': 'paolo.reyes@uclm.edu.ph',
  'full_name': 'Paolo Reyes',
  'phone_number': '+639171234567',
  'role': 'user',
  'email_verified_at': verifiedAt,
});

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth(AeroDropUser user) : super(AuthState(user: user, isVerified: true, sessionUnlocked: true));
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<bool>.value(false);
}

void main() {
  group('Test Case ID: CASE-009', () {
    testWidgets(
      'Test Case Description: Customer whose email is not yet verified signs in with their password | '
      "Expected Result: Home shows 'Verify your email to start ordering.' with a Verify email button",
      (tester) async {
        expect(_paolo().needsEmailVerification, isTrue);
        expect(_paolo(verifiedAt: '2026-11-17T02:00:00Z').needsEmailVerification, isFalse);

        await pumpScreen(
          tester,
          const Scaffold(body: VerifyEmailBannerFrame(child: Center(child: Text('Home')))),
          overrides: [authProvider.overrideWith((ref) => _Auth(_paolo()))],
        );

        expect(find.textContaining('Verify your email to start ordering.'), findsOneWidget);
        expect(find.textContaining('paolo.reyes@uclm.edu.ph'), findsOneWidget);
        expect(find.text('Verify email'), findsOneWidget);
      },
    );
  });
}
