import 'package:aerodrop/core/theme/app_colors.dart';
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/features/web/landing/landing_page.dart';
import 'package:aerodrop/features/web/landing/web_nav_bar.dart';
import 'package:aerodrop/features/web/web_breakpoints.dart';
import 'package:aerodrop/features/web/web_tokens.dart';
import 'package:aerodrop/features/web/widgets/web_home_screen_drop.dart';
import 'package:aerodrop/features/web/widgets/web_phone_browse.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The landing page is the one screen a stranger sees before signing in, and
/// the only one in the app laid out for a desktop viewport.
///
/// An earlier version of this file pumped three widths but only *scrolled* at
/// one of them, and passed while the page overflowed at every width between
/// 360 and 1120. A RenderFlex overflow throws during paint, so a section that
/// is never scrolled into view is never checked. These tests scroll at every
/// width they cover and treat any framework exception as a failure.
void main() {
  // Tokens resolve through this static. Set to the app's default so the tests
  // also prove the page does not depend on the app's brightness — it paints
  // its own surfaces from WebInk.
  AppTheme.isDarkMode = true;

  /// The last location the page navigated to, query string included.
  String? lastLocation;

  GoRouter buildRouter() => GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const LandingPage()),
      GoRoute(
        path: '/user/shop',
        builder: (_, state) {
          lastLocation = state.uri.toString();
          return const SizedBox.shrink();
        },
      ),
      // Every destination the page links to, so a tap resolves rather than
      // throwing on an unknown route.
      for (final path in const [
        '/login',
        '/register',
        '/shared/about',
        '/shared/help',
        '/shared/privacy-policy',
        '/shared/terms-conditions',
      ])
        GoRoute(
          path: path,
          builder: (_, state) {
            lastLocation = state.uri.toString();
            return const SizedBox.shrink();
          },
        ),
    ],
  );

  /// Collects framework errors raised while [body] runs.
  Future<List<String>> collectingErrors(Future<void> Function() body) async {
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final where = RegExp(
        r'(\S+\.dart:\d+:\d+)',
      ).firstMatch(details.toString());
      errors.add('${details.exception} @ ${where?.group(1) ?? "unknown"}');
    };
    try {
      await body();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  Future<void> pumpPage(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
    // The hero waits up to 1.5s for its webfonts, then plays a staggered
    // entrance; settle so no entrance timer outlives the test.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  group('lays out cleanly while scrolling', () {
    // Phones, tablets, laptops and desktops, plus both sides of each
    // breakpoint boundary — 719/720 and 1119/1120 are where the hero and the
    // nav change composition, and both broke in an earlier pass.
    const widths = [360.0, 719.0, 720.0, 900.0, 1119.0, 1120.0, 1440.0, 1920.0];

    for (final width in widths) {
      testWidgets('${width.toInt()}px', (tester) async {
        final errors = await collectingErrors(() async {
          await pumpPage(tester, Size(width, 900));
          final scrollable = find.byType(Scrollable).first;
          for (var i = 0; i < 12; i++) {
            await tester.drag(scrollable, const Offset(0, -760));
            await tester.pump(const Duration(milliseconds: 300));
          }
          tester.takeException();
        });
        expect(
          errors,
          isEmpty,
          reason: 'at ${width.toInt()}px:\n${errors.toSet().join("\n")}',
        );
      });
    }
  });

  testWidgets('short viewport does not overflow', (tester) async {
    // A laptop in a split-screen window is shorter than anything above.
    final errors = await collectingErrors(() async {
      await pumpPage(tester, const Size(1280, 560));
      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 14; i++) {
        await tester.drag(scrollable, const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 300));
      }
      tester.takeException();
    });
    expect(errors, isEmpty, reason: errors.toSet().join('\n'));
  });

  group('nav bar', () {
    /// Regression: `width: double.infinity` on the rule under the primary
    /// action resolved to actual infinity, because a Row gives its children
    /// unbounded horizontal constraints. The bar collapsed and every item
    /// painted on top of the wordmark at the left edge.
    testWidgets('items sit side by side, never stacked', (tester) async {
      await pumpPage(tester, const Size(1440, 900));

      Rect rectOf(String label) => tester.getRect(
        find.descendant(of: find.byType(WebNavBar), matching: find.text(label)),
      );

      // Left to right: section links, the centred wordmark, then the way in.
      const order = [
        'About Us',
        'Contacts',
        'Download the app',
        'AeroDrop',
        'Sign in',
        'Browse vendors',
      ];

      final rects = [for (final label in order) rectOf(label)];

      for (var i = 1; i < rects.length; i++) {
        expect(
          rects[i].left,
          greaterThan(rects[i - 1].right - 1),
          reason:
              '"${order[i]}" starts at ${rects[i].left} but '
              '"${order[i - 1]}" ends at ${rects[i - 1].right} — they overlap',
        );
      }

      // And the row actually spans the bar rather than bunching at one end.
      final bar = tester.getRect(find.byType(WebNavBar));
      expect(rects.last.right, greaterThan(bar.width * 0.6));
    });

    testWidgets('sign in opens the login page', (tester) async {
      await pumpPage(tester, const Size(1440, 900));
      lastLocation = null;

      await tester.tap(
        find.descendant(
          of: find.byType(WebNavBar),
          matching: find.text('Sign in'),
        ),
      );
      await tester.pumpAndSettle();

      // Marked as from the landing page, so the app router shows the form
      // even to a visitor who still has a session.
      expect(lastLocation, '/login?from=landing');
    });

    testWidgets('collapses to a menu below the expanded breakpoint', (
      tester,
    ) async {
      await pumpPage(tester, const Size(900, 900));
      expect(
        find.descendant(
          of: find.byType(WebNavBar),
          matching: find.text('About Us'),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    });
  });

  group('hero headline', () {
    /// Regression: a fixed display size orphaned "fly." onto a third line at
    /// viewports where the hero column was narrower than the headline.
    test('display size shrinks to fit its longest line', () {
      const line = 'WATCH IT FLY.';

      final wide = WebType.fitDisplay(
        longestLine: line,
        maxWidth: 2000,
        brk: WebBreak.expanded,
      );
      final narrow = WebType.fitDisplay(
        longestLine: line,
        maxWidth: 400,
        brk: WebBreak.expanded,
      );

      // Plenty of room: capped at the breakpoint's preferred size.
      expect(wide, 112.0);
      // Cramped: scaled down rather than wrapping.
      expect(narrow, lessThan(112.0));
      expect(narrow, greaterThanOrEqualTo(44.0));
    });

    for (final width in const [360.0, 720.0, 1120.0, 1920.0]) {
      testWidgets('renders on two lines at ${width.toInt()}px', (tester) async {
        await pumpPage(tester, Size(width, 900));

        // Each word is its own Text so it can rise through its own mask.
        // "WATCH" and "FLY." sharing a top edge means the second line held.
        final watch = tester.getRect(find.text('WATCH'));
        final fly = tester.getRect(find.text('FLY.'));
        final order = tester.getRect(find.text('ORDER'));
        expect(fly.top, moreOrLessEquals(watch.top, epsilon: 1));
        expect(watch.top, greaterThan(order.top));
      });
    }
  });

  group('canteen tiles', () {
    testWidgets('show the four canteens', (tester) async {
      await pumpPage(tester, const Size(1440, 900));
      for (final name in const [
        'Annex Building Canteen',
        'Old Building Canteen',
        'Engineering Building Canteen',
        'Maritime Building Canteen',
      ]) {
        // On its tile, and in the phone as a chip and as a store row.
        expect(find.text(name), findsNWidgets(3), reason: name);
      }
      // Each description is about its own canteen.
      for (final building in const [
        'Annex',
        'Old Building',
        'Engineering',
        'Maritime',
      ]) {
        expect(
          find.textContaining('$building canteen'),
          findsOneWidget,
          reason: building,
        );
      }
      expect(find.textContaining('Cafés'), findsNothing);
      expect(find.textContaining('Bakeries'), findsNothing);
    });

    testWidgets('open the Shop searched to their building', (tester) async {
      await pumpPage(tester, const Size(1440, 900));
      lastLocation = null;

      // The tiles run past a 900px fold; scroll the link to the middle of
      // the viewport, clear of the fixed navigation bar.
      await Scrollable.ensureVisible(
        tester.element(find.text('Browse Annex')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Browse Annex'));
      await tester.pumpAndSettle();

      expect(lastLocation, '/user/shop?search=Annex');
    });

    testWidgets('encode multi-word buildings', (tester) async {
      await pumpPage(tester, const Size(1440, 900));
      lastLocation = null;

      // Bring the tile to mid-viewport — not to the top edge, where the
      // floating nav bar would take the tap.
      final link = find.text('Browse Old Building');
      await tester.drag(
        find.byType(Scrollable).first,
        Offset(0, 450 - tester.getCenter(link).dy),
      );
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(
        Uri.parse(lastLocation!).queryParameters['search'],
        'Old Building',
      );
    });

    testWidgets('activate from the keyboard', (tester) async {
      await pumpPage(tester, const Size(1440, 900));
      lastLocation = null;

      // Tab through the bar's controls into the first tile.
      for (var i = 0; i < 12 && lastLocation == null; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.context;
        final inTile =
            focused != null &&
            find
                .descendant(
                  of: find.byWidget(focused.widget),
                  matching: find.text('Browse Annex'),
                )
                .evaluate()
                .isNotEmpty;
        if (inTile) {
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
        }
      }

      expect(lastLocation, '/user/shop?search=Annex');
    });

    testWidgets('select their chip in the phone on hover', (tester) async {
      await pumpPage(tester, const Size(1440, 900));

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      // The Maritime tile's heading: the top of the right column, inside the
      // first viewport. The tile comes before the phone in the tree.
      await gesture.moveTo(
        tester.getCenter(find.text('Maritime Building Canteen').first),
      );
      await tester.pumpAndSettle();

      final phone = find.byType(WebPhoneBrowse);
      // Inside the phone the chip comes before the store row.
      Color? chipFill(String name) =>
          (tester
                      .widget<AnimatedContainer>(
                        find
                            .ancestor(
                              of: find
                                  .descendant(
                                    of: phone,
                                    matching: find.text(name),
                                  )
                                  .first,
                              matching: find.byType(AnimatedContainer),
                            )
                            .first,
                      )
                      .decoration!
                  as BoxDecoration)
              .color;

      expect(chipFill('Maritime Building Canteen'), AppColors.accent);
      expect(chipFill('All'), isNot(AppColors.accent));

      double rowOpacity(String name) => tester
          .widget<AnimatedOpacity>(
            find
                .ancestor(
                  of: find
                      .descendant(of: phone, matching: find.text(name))
                      .last,
                  matching: find.byType(AnimatedOpacity),
                )
                .first,
          )
          .opacity;
      expect(rowOpacity('Maritime Building Canteen'), 1);
      expect(rowOpacity('Annex Building Canteen'), lessThan(1));
    });
  });

  group('nav sections', () {
    testWidgets('scroll to their section and mark it current', (tester) async {
      await pumpPage(tester, const Size(1440, 900));

      await tester.tap(
        find.descendant(
          of: find.byType(WebNavBar),
          matching: find.text('Contacts'),
        ),
      );
      await tester.pumpAndSettle();

      final title = tester.getRect(find.text('Talk to the team behind it.'));
      expect(title.top, inInclusiveRange(0, 900));

      // The current section's link is drawn in full-strength text.
      final link = tester.widget<AnimatedDefaultTextStyle>(
        find
            .ancestor(
              of: find.descendant(
                of: find.byType(WebNavBar),
                matching: find.text('Contacts'),
              ),
              matching: find.byType(AnimatedDefaultTextStyle),
            )
            .first,
      );
      expect(link.style.color, WebInk.text);
    });
  });

  group('about', () {
    testWidgets('meets the team: four names and their roles', (tester) async {
      await pumpPage(tester, const Size(1440, 900));
      await tester.tap(
        find.descendant(
          of: find.byType(WebNavBar),
          matching: find.text('About Us'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Meet our team'), findsOneWidget);
      for (final name in const [
        'Kim Andrie Ogdol',
        'Erickson Tiu',
        'Rozencrantz Oñada',
        'Lurinylle Clark Ardiente',
      ]) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Project Manager'), findsOneWidget);
      expect(find.text('Hacker'), findsNWidgets(2));
      expect(find.text('Hipster'), findsOneWidget);
      expect(find.text('Fly it again'), findsNothing);
    });

    for (final size in const [
      Size(1440, 900),
      Size(820, 1180),
      Size(375, 812),
    ]) {
      testWidgets('the team lays out at ${size.width.toInt()}px', (
        tester,
      ) async {
        final errors = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.exceptionAsString());
        await pumpPage(tester, size);
        await tester.scrollUntilVisible(
          find.text('Lurinylle Clark Ardiente'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        FlutterError.onError = previous;
        expect(errors.where((e) => e.contains('overflowed')), isEmpty);
      });
    }
  });

  group('contacts', () {
    testWidgets('help and support opens the in-app ticket form', (
      tester,
    ) async {
      await pumpPage(tester, const Size(1440, 900));
      lastLocation = null;

      final row = find.text('Send a ticket from the app');
      await tester.drag(
        find.byType(Scrollable).first,
        Offset(0, 450 - tester.getCenter(row).dy),
      );
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(lastLocation, '/shared/help');
    });

    testWidgets('lists no placeholder phone number or email', (tester) async {
      await pumpPage(tester, const Size(1440, 900));
      expect(find.textContaining('345-6789'), findsNothing);
      expect(find.textContaining('@aerodrop'), findsNothing);
      expect(find.text('github.com/Rzenz/AeroDrop'), findsNothing);
    });
  });

  group('download', () {
    testWidgets('switches install steps by platform', (tester) async {
      await pumpPage(tester, const Size(1440, 900));
      await tester.tap(
        find.descendant(
          of: find.byType(WebNavBar),
          matching: find.text('Download the app'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('iPhone'));
      await tester.pumpAndSettle();
      expect(find.text('Open the App Store on your iPhone.'), findsOneWidget);

      await tester.tap(find.text('Android'));
      await tester.pumpAndSettle();
      expect(
        find.text('Open the Google Play Store on your Android phone.'),
        findsOneWidget,
      );
    });

    testWidgets('offers Android and iPhone only', (tester) async {
      await pumpPage(tester, const Size(1440, 900));
      expect(find.text('Android'), findsOneWidget);
      expect(find.text('iPhone'), findsOneWidget);
      expect(find.text('Computer'), findsNothing);
    });

    testWidgets('replays the drop on every platform tap', (tester) async {
      await pumpPage(tester, const Size(1440, 900));
      await tester.tap(
        find.descendant(
          of: find.byType(WebNavBar),
          matching: find.text('Download the app'),
        ),
      );
      await tester.pumpAndSettle();

      // The icon's label fades in only once it has landed, so its opacity
      // says where the drop is.
      double labelOpacity() => tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.descendant(
                    of: find.byType(WebHomeScreenDrop),
                    matching: find.text('AeroDrop'),
                  ),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;

      expect(labelOpacity(), 1, reason: 'the first drop has finished');

      for (final platform in const ['iPhone', 'Android', 'Android']) {
        await tester.tap(find.text(platform));
        await tester.pump(const Duration(milliseconds: 300));
        expect(labelOpacity(), 0, reason: 'tapping $platform restarts it');
        await tester.pumpAndSettle();
        expect(labelOpacity(), 1, reason: 'and it lands again');
      }
    });

    testWidgets('shows the chosen store\'s badge', (tester) async {
      await pumpPage(tester, const Size(1440, 900));
      await tester.tap(
        find.descendant(
          of: find.byType(WebNavBar),
          matching: find.text('Download the app'),
        ),
      );
      await tester.pumpAndSettle();

      // Tests run as Android, so the guide opens on Google Play.
      expect(find.text('Google Play'), findsOneWidget);
      expect(find.text('App Store'), findsNothing);

      await tester.tap(find.text('iPhone'));
      await tester.pumpAndSettle();
      expect(find.text('App Store'), findsOneWidget);
      expect(find.text('Google Play'), findsNothing);

      expect(find.textContaining('public store release'), findsNothing);
    });
  });

  testWidgets('reaches the footer', (tester) async {
    await pumpPage(tester, const Size(1440, 900));
    for (var i = 0; i < 14; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -760));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.textContaining('drone flight operations'), findsOneWidget);
    expect(find.textContaining('A capstone project by BSIT'), findsNothing);
  });

  group('breakpoints', () {
    testWidgets('resolve from viewport width', (tester) async {
      for (final (width, expected) in const [
        (719.0, WebBreak.compact),
        (720.0, WebBreak.medium),
        (1119.0, WebBreak.medium),
        (1120.0, WebBreak.expanded),
      ]) {
        late WebBreak resolved;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: Size(width, 800)),
            child: Builder(
              builder: (context) {
                resolved = webBreakOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(resolved, expected, reason: 'at ${width}px');
      }
    });
  });
}
