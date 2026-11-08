import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:aerodrop/config/router/app_router.dart';
import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/providers/notification_provider.dart';
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/features/shared/privacy_policy_page.dart';
import 'package:aerodrop/features/shared/terms_conditions_page.dart';

// Fixed auth state, so the real router redirect runs without Supabase.
class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

const _signedOut = AuthState();

final _signedIn = AuthState(
  user: AeroDropUser(
    id: 'u1',
    name: 'Test Customer',
    email: 'customer@example.com',
    phoneNumber: '+639171234567',
    role: 'user',
  ),
  isVerified: true,
  sessionUnlocked: true,
);

/// Opens [path] through the app's router and returns where it ended up.
Future<String> _landOn(WidgetTester tester, AuthState auth, String path) async {
  late GoRouter router;
  AppTheme.isDarkMode = true;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _Auth(auth)),
        unreadNotificationCountProvider.overrideWithValue(0),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          router = ref.watch(routerProvider);
          return MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
          );
        },
      ),
    ),
  );
  router.go(path);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  // The router starts at /splash, which sends a signed-in user to their
  // shell, and that shell reaches for Supabase, which tests do not
  // initialise. Those errors are about the shell, not the redirect under
  // test, so they are dropped; the page itself is checked below.
  tester.takeException();
  final landed = router.routerDelegate.currentConfiguration.uri.path;
  if (landed == '/shared/terms-conditions') {
    expect(find.byType(TermsConditionsPage), findsOneWidget);
  } else if (landed == '/shared/privacy-policy') {
    expect(find.byType(PrivacyPolicyPage), findsOneWidget);
  }

  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
  return landed;
}

void main() {
  for (final path in signedOutLegalPaths) {
    testWidgets('$path opens while signed out', (tester) async {
      expect(await _landOn(tester, _signedOut, path), path);
    });

    // isLoggingIn sends signed-in users home; the legal pages must not.
    testWidgets('$path still opens while signed in', (tester) async {
      expect(await _landOn(tester, _signedIn, path), path);
    });
  }

  testWidgets('other /shared/ pages still need an account', (tester) async {
    expect(await _landOn(tester, _signedOut, '/shared/help'), '/welcome');
    expect(
      await _landOn(tester, _signedOut, '/shared/support/abc'),
      '/welcome',
    );
  });
}
