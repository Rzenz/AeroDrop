// Shared set-up for the unit testing documentation cases (CASE-001 to CASE-010).
import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps [screen] on a 390 x 844 phone (or [size]) in the app's default dark theme.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  Size size = const Size(390, 844),
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  AppTheme.isDarkMode = true;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.darkTheme, home: screen),
    ),
  );
  await tester.pump(const Duration(seconds: 2));
}

/// Taps a button by its label, scrolling it into view first.
Future<void> tapButton(WidgetTester tester, String label) async {
  final button = find.text(label);
  if (button.evaluate().isEmpty) {
    // Lazily built lists only create the button once it is scrolled to.
    await tester.dragUntilVisible(
      button,
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
  }
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Fills the [index]-th text field on the screen.
Future<void> fillField(WidgetTester tester, int index, String text) async {
  await tester.enterText(find.byType(TextFormField).at(index), text);
  await tester.pump();
}

/// An AuthNotifier stand-in whose login() answers like the Supabase backend.
class FakeAuth extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuth({this.loginSucceeds = false, this.loginError})
    : super(const AuthState());

  final bool loginSucceeds;
  final Object? loginError;

  @override
  Future<bool> login(
    String email,
    String password, {
    String? expectedRole,
  }) async {
    if (loginSucceeds) {
      state = AuthState(
        user: AeroDropUser.fromMap({
          'id': 'u1',
          'email': email,
          'full_name': 'Maria Santos',
          'phone_number': '+639171234567',
          'role': 'user',
        }),
        isVerified: true,
        sessionUnlocked: true,
      );
      return true;
    }
    state = state.copyWith(errorMessage: formatAuthErrorMessage(loginError!));
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<bool>.value(false);
}
