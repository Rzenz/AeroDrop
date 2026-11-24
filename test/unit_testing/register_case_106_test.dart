import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/features/auth/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';
import '_router.dart';

/// An AuthNotifier stand-in whose register() succeeds like the Supabase backend
/// does when the email still has to be confirmed.
class _RegisterAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _RegisterAuth() : super(const AuthState());
  final calls = <Symbol>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation.memberName);
    return Future<bool>.value(true);
  }
}

void main() {
  group('Test Case ID: CASE-106', () {
    testWidgets(
      'Test Case Description: User fills in all registration fields correctly, accepts the terms and taps Register Account | '
      'Expected Result: The account is created and the user is taken to the email verification screen',
      (tester) async {
        final auth = _RegisterAuth();
        await pumpRouted(tester, const RegisterScreen(), overrides: [authProvider.overrideWith((ref) => auth)], size: const Size(600, 1400), destinations: ['/email-sent']);
        await fillField(tester, 0, 'Juan Dela Cruz');
        await fillField(tester, 1, 'juan.delacruz@uclm.edu.ph');
        await fillField(tester, 2, '09171234567');
        await fillField(tester, 3, 'Campus#2026');
        await fillField(tester, 4, 'Campus#2026');
        await tester.ensureVisible(find.byType(Checkbox).first);
        await tester.tap(find.byType(Checkbox).first);
        await tester.pump();
        await tapButton(tester, 'Register Account');
        await tester.pump(const Duration(seconds: 1));

        expect(auth.calls, contains(#register));
        expect(find.text(opened('/email-sent')), findsOneWidget);
      },
    );
  });
}
