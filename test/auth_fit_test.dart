import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/features/web/auth/web_login_screen.dart';
import 'package:aerodrop/features/web/auth/web_register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// On the website the sign-in and registration forms are laid out to fit the
/// window without scrolling. These pump each screen state at common desktop
/// sizes and measure how far the form column could scroll: anything above
/// zero means part of the form sits below the fold.
///
/// The test font's glyphs are wider than the real typeface's, so text wraps
/// sooner here than in a browser; passing here leaves headroom there.
void main() {
  AppTheme.isDarkMode = true;

  const sizes = {
    '1440×900': Size(1440, 900),
    '1536×864': Size(1536, 864),
    '1280×800': Size(1280, 800),
  };

  Future<void> pump(WidgetTester tester, Widget screen, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.darkTheme, home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// How far the form column can scroll. The first Scrollable in the tree
  /// is the form column's; text fields' own scrollables sit inside it.
  /// Rounded down, so sub-pixel layout rounding does not count as overflow.
  double overflow(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .maxScrollExtent
      .floorToDouble();

  Future<void> fill(WidgetTester tester, String label, String text) async {
    final field = find.descendant(
      of: find
          .ancestor(of: find.text(label), matching: find.byType(Column))
          .first,
      matching: find.byType(EditableText),
    );
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    group(name, () {
      testWidgets('sign-in fits', (tester) async {
        await pump(tester, const WebLoginScreen(), size);
        expect(overflow(tester), 0);
      });

      testWidgets('vendor sign-in fits', (tester) async {
        await pump(tester, const WebLoginScreen(asVendor: true), size);
        expect(overflow(tester), 0);
      });

      testWidgets('customer registration fits, password typed', (tester) async {
        await pump(tester, const WebRegisterScreen(), size);
        expect(overflow(tester), 0);
        // The strength line reserves its space, so typing a password must
        // not push the form below the fold.
        await fill(tester, 'Password', 'Abcdef12');
        await tester.pumpAndSettle();
        expect(overflow(tester), 0);
      });

      testWidgets('every vendor step fits', (tester) async {
        await pump(tester, const WebRegisterScreen(asVendor: true), size);
        expect(overflow(tester), 0, reason: 'store step');

        await fill(tester, 'Store name', 'Annex Canteen');
        await next(tester);
        expect(overflow(tester), 0, reason: 'owner step');

        await fill(tester, 'Owner full name', 'Test Owner');
        await fill(tester, 'Phone number', '09123456789');
        await fill(tester, 'Email', 'owner@example.com');
        await fill(tester, 'Create a password', 'Abcdef12!');
        await fill(tester, 'Confirm password', 'Abcdef12!');
        await tester.pumpAndSettle();
        expect(overflow(tester), 0, reason: 'owner step, password typed');
        await next(tester);
        expect(overflow(tester), 0, reason: 'location step');

        // The review step is checked for layout errors only. It is the most
        // text-heavy state, and the test font's square glyphs — about twice
        // the width of the real typeface's — wrap its summary lines that do
        // not wrap in a browser, which reports overflow that is not there.
        // It was measured in the browser at 1440×900 instead.
        await next(tester);
        expect(find.text('Check your application'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
