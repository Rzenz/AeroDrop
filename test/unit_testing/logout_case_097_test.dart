import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/core/utils/logout_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An AuthNotifier stand-in that records the sign-out.
class _FakeLogoutAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FakeLogoutAuth() : super(const AuthState());
  int logouts = 0;

  @override
  Future<bool> logout() async {
    logouts++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<bool>.value(false);
}

void main() {
  group('Test Case ID: CASE-097', () {
    testWidgets(
      'Test Case Description: Customer taps Log Out on the Profile screen and confirms | '
      'Expected Result: The account is signed out and the Welcome screen is shown',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        AppTheme.isDarkMode = true;
        final auth = _FakeLogoutAuth();
        final router = GoRouter(routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) => Center(
                  child: TextButton(
                    onPressed: () => showLogoutConfirmation(context, ref),
                    child: const Text('Profile: Log Out'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(path: '/welcome', builder: (_, _) => const Scaffold(body: Text('Welcome to AeroDrop'))),
        ]);
        await tester.pumpWidget(ProviderScope(
          overrides: [authProvider.overrideWith((ref) => auth)],
          child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
        ));
        await tester.pump();

        await tester.tap(find.text('Profile: Log Out'));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('Are you sure you want to log out of your account?'), findsOneWidget);

        await tester.tap(find.text('Log Out').last);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));

        expect(auth.logouts, 1);
        expect(find.text('Welcome to AeroDrop'), findsOneWidget);
      },
    );
  });
}
