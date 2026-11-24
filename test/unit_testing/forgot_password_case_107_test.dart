import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/features/auth/forgot_password_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';
import '_router.dart';

/// An AuthNotifier stand-in for a registered email-and-password account.
class _ResetAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _ResetAuth() : super(const AuthState());
  final sentTo = <String>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #sendPasswordReset) sentTo.add(invocation.positionalArguments.first as String);
    // checkIsGoogleOnlyAccount: no; sendPasswordReset: sent.
    return Future<bool>.value(invocation.memberName == #sendPasswordReset);
  }
}

void main() {
  group('Test Case ID: CASE-107', () {
    testWidgets(
      'Test Case Description: User requests a reset code with the registered email maria.santos@uclm.edu.ph | '
      'Expected Result: The reset code is sent and the user is taken to the code entry screen',
      (tester) async {
        final auth = _ResetAuth();
        await pumpRouted(tester, const ForgotPasswordScreen(), overrides: [authProvider.overrideWith((ref) => auth)], destinations: ['/email-sent']);
        await fillField(tester, 0, 'maria.santos@uclm.edu.ph');
        await tapButton(tester, 'Request Code');
        await tester.pump(const Duration(seconds: 1));

        expect(auth.sentTo, ['maria.santos@uclm.edu.ph']);
        expect(find.text(opened('/email-sent')), findsOneWidget);
      },
    );
  });
}
