import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-004', () {
    testWidgets(
      'Test Case Description: User enters a registered email and correct password | '
      'Expected Result: Login succeeds and the user is taken to the customer Home dashboard',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final router = GoRouter(
          initialLocation: '/login',
          routes: [
            GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
            GoRoute(
              path: '/user',
              builder: (_, _) => const Scaffold(body: Text('Customer Home')),
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith((ref) => FakeAuth(loginSucceeds: true)),
            ],
            child: MaterialApp.router(
              theme: AppTheme.darkTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 2));

        await fillField(tester, 0, 'maria.santos@uclm.edu.ph');
        await fillField(tester, 1, 'demo1234');
        await tapButton(tester, 'Login');
        await tester.pump(const Duration(seconds: 1));

        expect(router.state.uri.toString(), '/user');
        expect(find.text('Customer Home'), findsOneWidget);
      },
    );
  });
}
