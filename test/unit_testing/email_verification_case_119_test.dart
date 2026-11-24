import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/widgets/verify_email_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth(AeroDropUser user) : super(AuthState(user: user, isVerified: true, sessionUnlocked: true));
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<bool>.value(false);
}

void main() {
  group('Test Case ID: CASE-119', () {
    testWidgets(
      'Test Case Description: Customer whose email is already verified signs in | '
      'Expected Result: Home opens without the "Verify your email" banner, so the customer can order',
      (tester) async {
        final paolo = AeroDropUser.fromMap({
          'id': 'paolo',
          'email': 'paolo.reyes@uclm.edu.ph',
          'full_name': 'Paolo Reyes',
          'phone_number': '+639171234567',
          'role': 'user',
          'email_verified_at': '2026-11-17T02:00:00Z',
        });
        expect(paolo.needsEmailVerification, isFalse);
        await pumpScreen(
          tester,
          const Scaffold(body: VerifyEmailBannerFrame(child: Center(child: Text('Home')))),
          overrides: [authProvider.overrideWith((ref) => _Auth(paolo))],
        );

        expect(find.text('Home'), findsOneWidget);
        expect(find.textContaining('Verify your email to start ordering.'), findsNothing);
        expect(find.text('Verify email'), findsNothing);
      },
    );
  });
}
