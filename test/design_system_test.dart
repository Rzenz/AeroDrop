// Layout regression tests for the neumorphic design system.
//
// These pump the shared components at the extremes the app actually ships to —
// a 320pt phone, a tablet, and a 2x text scale — and fail on any RenderFlex
// overflow. Overflow is the failure mode a shadow-heavy redesign is most
// likely to introduce, and it is invisible in `flutter analyze`.
import 'package:aerodrop/core/theme/app_colors.dart';
import 'package:aerodrop/core/theme/app_shadows.dart';
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/core/widgets/analytics_card.dart';
import 'package:aerodrop/core/widgets/empty_state_widget.dart';
import 'package:aerodrop/core/widgets/neu_button.dart';
import 'package:aerodrop/core/widgets/custom_app_bar.dart';
import 'package:aerodrop/core/widgets/neu_avatar.dart';
import 'package:aerodrop/core/widgets/neu_back_button.dart';
import 'package:aerodrop/core/widgets/neu_card.dart';
import 'package:aerodrop/core/widgets/neu_input.dart';
import 'package:aerodrop/core/widgets/neu_list_tile.dart';
import 'package:aerodrop/core/widgets/neu_action_fan.dart';
import 'package:aerodrop/core/widgets/neu_nav_dock.dart';
import 'package:aerodrop/features/dashboard/widgets/aerodrop_bottom_navigation.dart';
import 'package:aerodrop/core/widgets/neu_surface.dart';
import 'package:aerodrop/core/widgets/neu_text_field.dart';
import 'package:aerodrop/core/widgets/section_header.dart';
import 'package:aerodrop/core/widgets/status_chip.dart';
import 'package:aerodrop/features/auth/login_screen.dart';
import 'package:aerodrop/features/auth/onboarding_screen.dart';
import 'package:aerodrop/features/auth/register_screen.dart';
import 'package:aerodrop/features/auth/welcome_screen.dart';
import 'package:aerodrop/core/widgets/cart_button.dart';
import 'package:aerodrop/core/widgets/receipt_printer.dart';
import 'package:aerodrop/mock_data/cart_mock.dart';
import 'package:aerodrop/features/orders/receipt_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sizes worth guarding: the smallest phone still in circulation, a common
/// modern phone, and a tablet.
const _sizes = <String, Size>{
  'small phone': Size(320, 640),
  'phone': Size(390, 844),
  'tablet': Size(834, 1112),
};

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
  double textScale = 1.0,
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  AppTheme.isDarkMode = brightness == Brightness.dark;

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

/// Pumps a whole screen. Unlike [_pump] it does not wrap the subject in a
/// Scaffold or a scroll view — a screen brings its own, and nesting them gives
/// the child unbounded height, which hides exactly the overflows these tests
/// exist to catch.
Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required Size size,
  double textScale = 1.0,
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  AppTheme.isDarkMode = brightness == Brightness.dark;

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme,
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
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  // Long strings are the realistic overflow trigger: vendor names, package
  // titles and addresses are all user-supplied.
  const longText =
      'Extraordinarily Long Vendor Name That Should Ellipsize Cleanly';

  group('components lay out without overflow', () {
    for (final entry in _sizes.entries) {
      testWidgets('${entry.key} — buttons', (tester) async {
        await _pump(
          tester,
          const Column(
            children: [
              NeuButton(text: longText, icon: Icons.check),
              NeuButton(text: 'Loading', isLoading: true),
              NeuButton(text: 'Disabled', onPressed: null),
              NeuButton(text: 'Ghost', variant: NeuButtonVariant.ghost),
              NeuButton(text: 'Neutral', variant: NeuButtonVariant.neutral),
              NeuButton(text: 'Danger', variant: NeuButtonVariant.danger),
            ],
          ),
          size: entry.value,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('${entry.key} — stat card grid', (tester) async {
        await _pump(
          tester,
          GridView(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              // Deliberately tighter than anything the app ships, so the card
              // is proven to degrade rather than overflow.
              childAspectRatio: 1.6,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            children: [
              AnalyticsCard(
                title: 'Total deliveries completed this month',
                value: '1,284',
                change: '+12.4%',
                isPositive: true,
                icon: Icons.local_shipping_rounded,
                iconColor: Colors.blue,
              ),
              AnalyticsCard(
                title: 'Revenue',
                value: '₱1,284,000.00',
                change: '-3.1%',
                isPositive: false,
                icon: Icons.payments_rounded,
                iconColor: Colors.green,
              ),
            ],
          ),
          size: entry.value,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('${entry.key} — nav dock', (tester) async {
        await _pump(
          tester,
          NeuNavDock(
            selectedIndex: 1,
            onTap: (_) {},
            items: const [
              NeuNavItem(icon: Icons.dashboard_rounded, label: 'Home'),
              NeuNavItem(icon: Icons.inventory_2_rounded, label: 'Products'),
              NeuNavItem(icon: Icons.receipt_long_rounded, label: 'Orders'),
              NeuNavItem(icon: Icons.notifications_rounded, label: 'Alerts'),
              NeuNavItem(icon: Icons.person_rounded, label: 'Profile'),
            ],
          ),
          size: entry.value,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('${entry.key} — cards, headers, chips', (tester) async {
        await _pump(
          tester,
          Column(
            children: [
              const SectionHeader(
                title: longText,
                subtitle: longText,
                actionLabel: 'See all',
              ),
              NeuCard(
                accent: Colors.orange,
                onTap: () {},
                child: Row(
                  children: [
                    const Expanded(child: Text(longText)),
                    StatusChip.delivery('intransit'),
                  ],
                ),
              ),
              const NeuPanel(child: Text(longText)),
              const NeuAccentCard(child: Text(longText)),
              Wrap(
                children: [
                  StatusChip.drone('maintenance'),
                  StatusChip.delivery('cancelled'),
                  StatusChip.delivery('unknown-status'),
                ],
              ),
            ],
          ),
          size: entry.value,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('text field renders focused, error and disabled states', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    await _pump(
      tester,
      Form(
        key: key,
        child: Column(
          children: [
            NeuTextField(
              labelText: 'Email',
              hintText: 'you@example.com',
              prefixIcon: Icons.email_outlined,
              validator: (_) => 'That email address is not valid',
            ),
            const NeuTextField(
              labelText: 'Disabled',
              hintText: 'Cannot edit',
              enabled: false,
            ),
          ],
        ),
      ),
      size: const Size(320, 640),
    );

    // Focus the first field.
    await tester.tap(find.byType(TextFormField).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    // Trigger validation and confirm the message surfaces.
    key.currentState!.validate();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('That email address is not valid'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('components survive 2x text scaling', (tester) async {
    await _pump(
      tester,
      Column(
        children: [
          const NeuButton(text: 'Confirm delivery request'),
          const SectionHeader(title: 'Active deliveries', actionLabel: 'All'),
          NeuCard(child: Row(children: [StatusChip.delivery('pending')])),
        ],
      ),
      size: const Size(320, 640),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty and error states render in both themes', (tester) async {
    for (final brightness in Brightness.values) {
      await _pump(
        tester,
        const SizedBox(
          height: 560,
          child: EmptyStateWidget(
            title: 'No deliveries yet',
            subtitle: 'Your completed drops will appear here.',
            actionLabel: 'Browse vendors',
          ),
        ),
        size: const Size(320, 640),
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);

      await _pump(
        tester,
        const SizedBox(
          height: 560,
          child: ErrorStateWidget(message: 'Could not reach the server.'),
        ),
        size: const Size(320, 640),
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('inset surfaces paint without error', (tester) async {
    await _pump(
      tester,
      const Column(
        children: [
          NeuSurface(
            style: NeuStyle.inset,
            depth: NeuDepth.high,
            padding: EdgeInsets.all(24),
            child: Text('Debossed'),
          ),
          NeuSurface(
            style: NeuStyle.raised,
            depth: NeuDepth.high,
            padding: EdgeInsets.all(24),
            child: Text('Embossed'),
          ),
          // A zero-size surface must not blow up the painter.
          SizedBox(
            width: 0,
            height: 0,
            child: NeuSurface(style: NeuStyle.inset, child: SizedBox()),
          ),
        ],
      ),
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('core surfaces render in light mode', (tester) async {
    await _pump(
      tester,
      Column(
        children: [
          const NeuButton(text: 'Confirm'),
          const NeuButton(text: 'Neutral', variant: NeuButtonVariant.neutral),
          const SectionHeader(title: 'Active deliveries', actionLabel: 'All'),
          NeuCard(child: Row(children: [StatusChip.delivery('delivered')])),
          const NeuTextField(labelText: 'Email', hintText: 'you@example.com'),
          NeuNavDock(
            selectedIndex: 0,
            onTap: (_) {},
            items: const [
              NeuNavItem(icon: Icons.home_rounded, label: 'Home'),
              NeuNavItem(icon: Icons.person_rounded, label: 'Profile'),
            ],
          ),
        ],
      ),
      size: const Size(390, 844),
      brightness: Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });

  test('shadow tokens follow the active brightness', () {
    AppTheme.isDarkMode = true;
    final dark = AppShadows.raised(NeuDepth.low);
    final darkFloating = AppShadows.floating;

    AppTheme.isDarkMode = false;
    final light = AppShadows.raised(NeuDepth.low);
    final lightFloating = AppShadows.floating;

    // The cache is keyed on brightness; a stale entry here would mean every
    // light-mode surface painted with dark-mode shadows.
    expect(dark.first.color, isNot(equals(light.first.color)));
    expect(darkFloating.first.color, isNot(equals(lightFloating.first.color)));

    // And flipping back must return the original values, not a third set.
    AppTheme.isDarkMode = true;
    expect(AppShadows.raised(NeuDepth.low).first.color, dark.first.color);
  });

  group('list tiles, inputs and filters', () {
    for (final entry in _sizes.entries) {
      testWidgets('${entry.key} — tiles and controls', (tester) async {
        await _pump(
          tester,
          Column(
            children: [
              const NeuSearchField(hintText: longText),
              const SizedBox(height: 12),
              NeuFilterBar(
                options: const ['All', 'Meals', 'Drinks', 'Supplies', longText],
                selectedIndex: 1,
                onSelected: (_) {},
              ),
              const SizedBox(height: 12),
              NeuSegmented(
                options: const ['Active', 'History', longText],
                selectedIndex: 0,
                onSelected: (_) {},
              ),
              const SizedBox(height: 12),
              NeuTileGroup(
                label: 'Account',
                children: [
                  NeuListTile(
                    leading: const NeuAvatar(name: 'Rupert Onada', size: 40),
                    title: longText,
                    subtitle: longText,
                    onTap: () {},
                  ),
                  NeuListTile(
                    icon: Icons.notifications_rounded,
                    title: longText,
                    trailing: const Text('₱1,284,000.00'),
                  ),
                  NeuListTile(
                    icon: Icons.logout_rounded,
                    title: 'Sign out',
                    destructive: true,
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const NeuDetailRow(label: longText, value: '₱1,284,000.00'),
              const NeuDetailRow(
                label: 'Total',
                value: '₱1,284,000.00',
                emphasis: true,
              ),
              const SizedBox(height: 12),
              const NeuProgressBar(value: 0.62),
              // Out-of-range values must clamp, not overflow the rail.
              const NeuProgressBar(value: 1.9),
              const NeuProgressBar(value: -0.4),
            ],
          ),
          size: entry.value,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  // The back button is the control users reach for most, so its geometry is
  // pinned rather than left to each screen. This fails if a screen-level
  // override or a tweak to NeuIconButton changes the shared size, and if the
  // tap target ever drops under the 44pt accessibility minimum.
  group('back button', () {
    testWidgets('is the same size standalone and inside a header', (
      tester,
    ) async {
      await _pump(
        tester,
        Column(
          children: [
            CustomAppBar(title: 'Settings', onBackPressed: () {}),
            NeuBackButton(onPressed: () {}),
          ],
        ),
        size: const Size(390, 844),
      );

      final found = find.byType(NeuBackButton);
      expect(found, findsNWidgets(2));

      final sizes = {tester.getSize(found.at(0)), tester.getSize(found.at(1))};
      expect(sizes.length, 1, reason: 'header and standalone must match');

      final rendered = sizes.single;
      expect(rendered.width, greaterThanOrEqualTo(44));
      expect(rendered.height, greaterThanOrEqualTo(44));
    });

    testWidgets('keeps its tap target at 2x text scale', (tester) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: NeuBackButton(onPressed: () {}),
        ),
        size: const Size(320, 640),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);

      final size = tester.getSize(find.byType(NeuBackButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  // The welcome screen stacks four buttons under a fixed-share hero, which
  // makes it the screen most likely to run out of vertical room. These pump
  // the full entrance so a mid-animation transform cannot hide an overflow.
  group('welcome screen', () {
    for (final entry in _sizes.entries) {
      for (final scale in const [1.0, 1.5, 2.0]) {
        testWidgets('${entry.key} at ${scale}x text', (tester) async {
          await _pumpScreen(
            tester,
            const WelcomeScreen(),
            size: entry.value,
            textScale: scale,
          );
          // Run the whole 1750ms entrance, not just the first frame.
          await tester.pump(const Duration(milliseconds: 900));
          await tester.pump(const Duration(milliseconds: 900));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  // Sign-in and registration share a hero, a stagger and a field treatment,
  // so a change to any of the three lands on both. Registration is pumped in
  // each role because the vendor branch swaps the whole form underneath.
  group('auth screens', () {
    for (final entry in _sizes.entries) {
      for (final scale in const [1.0, 1.5]) {
        testWidgets('sign-in ${entry.key} at ${scale}x', (tester) async {
          await _pumpScreen(
            tester,
            const LoginScreen(),
            size: entry.value,
            textScale: scale,
          );
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull);
        });

        testWidgets('register ${entry.key} at ${scale}x', (tester) async {
          await _pumpScreen(
            tester,
            const RegisterScreen(),
            size: entry.value,
            textScale: scale,
          );
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull);

          // Switch to the vendor wizard and lay that out too.
          await tester.tap(find.text('Vendor'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  // The customer dock cuts a notch out of itself for the cart action, which
  // makes its item slots narrower than the vendor dock's. These check that the
  // labels still fit either side of the bite at every width and text scale.
  group('nav dock', () {
    for (final entry in _sizes.entries) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        testWidgets('customer ${entry.key} at ${scale}x', (tester) async {
          await _pumpScreen(
            tester,
            Scaffold(
              backgroundColor: AppColors.base,
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: AeroDropBottomNavigation(
                    selectedIndex: 0,
                    cartCount: 12,
                    onTap: (_) {},
                    onFabPressed: () {},
                  ),
                ),
              ),
            ),
            size: entry.value,
            textScale: scale,
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
        });

        testWidgets('vendor ${entry.key} at ${scale}x', (tester) async {
          await _pumpScreen(
            tester,
            Scaffold(
              backgroundColor: AppColors.base,
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: NeuNavDock(
                    items: const [
                      NeuNavItem(icon: Icons.dashboard_rounded, label: 'Home'),
                      NeuNavItem(
                        icon: Icons.inventory_2_rounded,
                        label: 'Products',
                      ),
                      NeuNavItem(
                        icon: Icons.receipt_long_rounded,
                        label: 'Orders',
                      ),
                      NeuNavItem(
                        icon: Icons.notifications_rounded,
                        label: 'Alerts',
                      ),
                      NeuNavItem(icon: Icons.person_rounded, label: 'Profile'),
                    ],
                    selectedIndex: 1,
                    onTap: (_) {},
                  ),
                ),
              ),
            ),
            size: entry.value,
            textScale: scale,
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  // The admin fan puts six labelled buttons above the dock. It arcs them in
  // one row where there is width and breaks to two where there is not, so both
  // branches need checking, and the halfway frame catches anything that only
  // overflows mid-travel.
  group('action fan', () {
    final actions = <NeuFanAction>[
      NeuFanAction(
        icon: Icons.bar_chart_rounded,
        label: 'Analytics',
        onTap: () {},
      ),
      NeuFanAction(
        icon: Icons.map_rounded,
        label: 'Flight\nBoundaries',
        active: true,
        onTap: () {},
      ),
      NeuFanAction(
        icon: Icons.wb_sunny_rounded,
        label: 'Weather',
        onTap: () {},
      ),
      NeuFanAction(
        icon: Icons.analytics_outlined,
        label: 'System\nLogs',
        onTap: () {},
      ),
      NeuFanAction(
        icon: Icons.settings_rounded,
        label: 'Settings',
        onTap: () {},
      ),
      NeuFanAction(
        icon: Icons.logout_rounded,
        label: 'Sign Out',
        destructive: true,
        onTap: () {},
      ),
    ];

    for (final entry in _sizes.entries) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final open in const [0.0, 0.45, 1.0]) {
          testWidgets('${entry.key} at ${scale}x, open $open', (tester) async {
            final controller = AnimationController(
              vsync: const TestVSync(),
              duration: const Duration(milliseconds: 460),
            )..value = open;
            addTearDown(controller.dispose);

            await _pumpScreen(
              tester,
              Scaffold(
                backgroundColor: AppColors.base,
                body: Stack(
                  children: [
                    const SizedBox.expand(),
                    NeuActionFan(
                      progress: controller,
                      onDismiss: () {},
                      actions: actions,
                    ),
                  ],
                ),
                bottomNavigationBar: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: NeuNavDock(
                      items: const [
                        NeuNavItem(
                          icon: Icons.dashboard_rounded,
                          label: 'Dashboard',
                        ),
                        NeuNavItem(
                          icon: Icons.local_shipping_rounded,
                          label: 'Deliveries',
                          badge: 9,
                        ),
                        NeuNavItem(
                          icon: Icons.flight_takeoff_rounded,
                          label: 'Fleet',
                        ),
                        NeuNavItem(icon: Icons.people_rounded, label: 'Users'),
                      ],
                      selectedIndex: 1,
                      onTap: (_) {},
                      centerAction: NeuFanToggle(
                        progress: controller,
                        onPressed: () {},
                      ),
                    ),
                  ),
                ),
              ),
              size: entry.value,
              textScale: scale,
            );
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  // The receipt is the tallest thing the app renders and its paper is a fixed
  // width of monospace columns, so it is the most likely place for a line to
  // run past its edge. Pumped mid-feed as well as finished, because the paper
  // is measured at full height while only part of it is revealed.
  group('receipt', () {
    final data = ReceiptData(
      orderRef: 'ORD-4F2A9C71',
      vendorName: 'Extraordinarily Long Canteen Name That Must Ellipsize',
      lines: const [
        ReceiptLine(
          name: 'Chicken adobo rice bowl with extra egg and rice',
          quantity: 2,
          unitPrice: 89,
        ),
        ReceiptLine(name: 'Iced barako coffee', quantity: 1, unitPrice: 65),
        ReceiptLine(name: 'Calculus textbook', quantity: 1, unitPrice: 420.5),
      ],
      subtotal: 663.5,
      deliveryFee: 20,
      total: 683.5,
      paymentLabel: 'Cash on delivery',
      placedAt: DateTime(2026, 8, 30, 14, 32),
      dropoffName: 'RTL Building Roof Deck, North Wing',
    );

    for (final entry in _sizes.entries) {
      for (final scale in const [1.0, 1.5]) {
        for (final settle in const [700, 3200]) {
          testWidgets('${entry.key} at ${scale}x, ${settle}ms', (tester) async {
            await _pumpScreen(
              tester,
              ReceiptScreen(data: data),
              size: entry.value,
              textScale: scale,
            );
            var t = 400;
            while (t < settle) {
              await tester.pump(const Duration(milliseconds: 200));
              t += 200;
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  // The printer is a ported component with its own stages and two feed modes.
  // Every stage is laid out, because processing draws no paper at all and
  // complete draws it at full height — different trees, different failures.
  group('receipt printer', () {
    for (final stage in ReceiptPrinterStage.values) {
      for (final motion in ReceiptFeedMotion.values) {
        testWidgets('${stage.name} / ${motion.name}', (tester) async {
          await _pumpScreen(
            tester,
            Scaffold(
              backgroundColor: AppColors.base,
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ReceiptPrinter(
                  stage: stage,
                  feedMotion: motion,
                  screen: const SizedBox(height: 40),
                  paper: Container(height: 420, color: const Color(0xFFF4F3EF)),
                ),
              ),
            ),
            size: const Size(390, 844),
          );
          // Mid-feed and settled: a stepped table can overrun at a keyframe
          // boundary without ever showing it at either end.
          await tester.pump(const Duration(milliseconds: 800));
          expect(tester.takeException(), isNull);
          await tester.pump(const Duration(milliseconds: 1200));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  // The cart button reacts to a global notifier and the flight lives in the
  // root overlay, so both outlive the widget that started them. These check
  // the badge tracks the cart and that a flight cleans itself up rather than
  // leaving an entry behind.
  group('cart', () {
    setUp(cartNotifier.clear);
    tearDown(cartNotifier.clear);

    CartItem item(String id) => CartItem(
      productId: id,
      productName: 'Adobo bowl',
      vendorId: 'v1',
      vendorName: 'Canteen',
      imageUrl: '',
      unitPrice: 89,
    );

    testWidgets('badge follows the cart and bumps on add', (tester) async {
      await _pumpScreen(
        tester,
        Scaffold(
          backgroundColor: AppColors.base,
          appBar: AppBar(actions: [NeuCartButton(onPressed: () {})]),
          body: const SizedBox.expand(),
        ),
        size: const Size(390, 700),
      );

      expect(find.text('1'), findsNothing);

      cartNotifier.addItem(item('p1'));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      // Through the bump and out the other side.
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      // 44pt minimum survives the scale.
      expect(
        tester.getSize(find.byType(NeuCartButton)).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('flight removes its overlay entry', (tester) async {
      final source = GlobalKey();
      await _pumpScreen(
        tester,
        Scaffold(
          backgroundColor: AppColors.base,
          appBar: AppBar(actions: [NeuCartButton(onPressed: () {})]),
          body: Center(child: SizedBox(key: source, width: 120, height: 120)),
        ),
        size: const Size(390, 700),
      );

      flyToCart(
        source.currentContext!,
        from: const Rect.fromLTWH(100, 300, 84, 84),
        thumbnail: const ColoredBox(color: Color(0xFF4FB1F6)),
      );
      await tester.pump();
      expect(find.byType(ColoredBox), findsWidgets);

      // Past the 520ms flight; the entry removes itself on completion.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('arrival fires after the flight, not on the tap', (
      tester,
    ) async {
      final source = GlobalKey();
      var arrived = false;

      await _pumpScreen(
        tester,
        Scaffold(
          backgroundColor: AppColors.base,
          appBar: AppBar(actions: [NeuCartButton(onPressed: () {})]),
          body: Center(child: SizedBox(key: source, width: 10, height: 10)),
        ),
        size: const Size(390, 700),
      );

      flyToCart(
        source.currentContext!,
        from: const Rect.fromLTWH(100, 300, 84, 84),
        thumbnail: const ColoredBox(color: Color(0xFF4FB1F6)),
        onArrive: () => arrived = true,
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(arrived, isFalse, reason: 'still in the air');

      await tester.pump(const Duration(milliseconds: 600));
      expect(arrived, isTrue, reason: 'landed');
    });

    testWidgets('flight is a no-op with no cart on screen', (tester) async {
      final source = GlobalKey();
      await _pumpScreen(
        tester,
        Scaffold(
          backgroundColor: AppColors.base,
          body: Center(child: SizedBox(key: source, width: 10, height: 10)),
        ),
        size: const Size(390, 700),
      );

      // No NeuCartButton is mounted, so there is nothing to aim at. This must
      // return quietly rather than throw or leave an entry running.
      var arrived = false;
      flyToCart(
        source.currentContext!,
        from: const Rect.fromLTWH(100, 300, 84, 84),
        thumbnail: const ColoredBox(color: Color(0xFF4FB1F6)),
        announce: 'Adobo bowl added to cart',
        onArrive: () => arrived = true,
      );
      // No flight to wait for, so the confirmation must not wait either.
      expect(arrived, isTrue);

      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
    });
  });

  // The vendor door on sign-in only relabels the screen — the credentials
  // check and the post-login redirect stay driven by the account's real role.
  // What must hold is that it flips in both directions and takes the hero's
  // subtitle with it.
  //
  // Two single-tap tests rather than one that taps twice: NeuButton debounces
  // on wall-clock time to stop double-submits, pumped time does not move that
  // clock, and burning real milliseconds lets google_fonts start a network
  // fetch that fails the test for unrelated reasons.
  group('sign-in vendor door', () {
    testWidgets('customer to vendor', (tester) async {
      await _pumpScreen(
        tester,
        const LoginScreen(),
        size: const Size(390, 900),
      );
      await tester.pump(const Duration(milliseconds: 900));

      expect(find.text('Login as vendor'), findsOneWidget);
      expect(find.text('Vendor sign-in'), findsNothing);

      await tester.tap(find.text('Login as vendor'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Login as customer'), findsOneWidget);
      expect(find.text('Vendor sign-in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('vendor back to customer', (tester) async {
      await _pumpScreen(
        tester,
        const LoginScreen(asVendor: true),
        size: const Size(390, 900),
      );
      await tester.pump(const Duration(milliseconds: 900));

      // Routed straight to the vendor door.
      expect(find.text('Vendor sign-in'), findsOneWidget);
      expect(find.text('Login as customer'), findsOneWidget);

      await tester.tap(find.text('Login as customer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Not a one-way switch — a mistap has a way back.
      expect(find.text('Login as vendor'), findsOneWidget);
      expect(find.text('Vendor sign-in'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // One onboarding screen now, and it is the first thing anyone sees. The
  // banner takes a fixed share of the height, so the copy and the call to
  // action have to fit whatever is left at any text size.
  group('onboarding', () {
    for (final entry in _sizes.entries) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        testWidgets('${entry.key} at ${scale}x', (tester) async {
          await _pumpScreen(
            tester,
            const OnboardingScreen(),
            size: entry.value,
            textScale: scale,
          );
          await tester.pump(const Duration(milliseconds: 700));
          await tester.pump(const Duration(milliseconds: 700));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
