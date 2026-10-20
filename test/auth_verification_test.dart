import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/features/web/auth/web_otp_email_sent_screen.dart';
import 'package:aerodrop/features/web/auth/web_verification_page.dart';
import 'package:aerodrop/features/auth/widgets/auth_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two code-entry screens — after sign-in (`/verification`) and after
/// registering or asking for a password reset (`/email-sent`) — share a
/// centred card over the campus photograph and a single-field code input.
void main() {
  AppTheme.isDarkMode = true;

  Future<List<String>> pumpCatching(
    WidgetTester tester,
    Widget screen,
    Size size, {
    double textScale = 1,
  }) async {
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    addTearDown(() => FlutterError.onError = previous);

    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: screen,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    // Leave no countdown or snack timer running past the test.
    await tester.pumpWidget(const SizedBox());
    FlutterError.onError = previous;
    return errors;
  }

  const screens = <String, Widget>{
    'after sign-in': WebVerificationPage(),
    'after registering': WebOtpEmailSentScreen(email: 'owner@example.com'),
    'password reset (Google account)': WebOtpEmailSentScreen(
      email: 'owner@example.com',
      type: 'reset',
      isGoogleOnly: true,
    ),
  };

  const sizes = <String, Size>{
    'small phone': Size(320, 640),
    'phone': Size(390, 844),
    'laptop': Size(1366, 768),
    'desktop': Size(1440, 900),
  };

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    group(name, () {
      for (final MapEntry(key: label, value: size) in sizes.entries) {
        for (final scale in const [1.0, 1.5]) {
          testWidgets('lays out on $label at ${scale}x', (tester) async {
            final errors = await pumpCatching(
              tester,
              screen,
              size,
              textScale: scale,
            );
            expect(errors.where((e) => e.contains('overflowed')), isEmpty);
          });
        }
      }

      testWidgets('the card fits a desktop window without scrolling', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(1440, 900)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(theme: AppTheme.darkTheme, home: screen),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        expect(scroll.position.maxScrollExtent.floorToDouble(), 0);
        await tester.pumpWidget(const SizedBox());
      });
    });
  }

  group('code input', () {
    Future<(TextEditingController, List<String>)> pumpInput(
      WidgetTester tester,
    ) async {
      final controller = TextEditingController();
      final completed = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: AuthCodeInput(
                controller: controller,
                length: 6,
                onCompleted: completed.add,
              ),
            ),
          ),
        ),
      );
      return (controller, completed);
    }

    testWidgets('a pasted code lands whole and submits once', (tester) async {
      final (controller, completed) = await pumpInput(tester);
      await tester.enterText(find.byType(EditableText), '482913');
      await tester.pump();
      expect(controller.text, '482913');
      expect(completed, ['482913']);
      // Every digit is drawn in its own cell.
      for (final d in '482913'.split('')) {
        expect(find.text(d), findsWidgets);
      }
    });

    testWidgets('keeps digits only, and no more than six', (tester) async {
      final (controller, completed) = await pumpInput(tester);
      await tester.enterText(find.byType(EditableText), '4a8-29 1');
      await tester.pump();
      expect(controller.text, '48291');
      expect(completed, isEmpty);

      await tester.enterText(find.byType(EditableText), '4829137');
      await tester.pump();
      expect(controller.text.length, 6);
    });
  });
}
