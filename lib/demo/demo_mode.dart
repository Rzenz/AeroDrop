// DEMO ONLY — remove before release.
//
// A floating "Demo" tab on every page that opens a picker of every screen
// in the app, and switches off the router's sign-in and role checks so each
// one opens without an account. To remove: delete this folder and the code
// marked `// DEMO` in lib/app.dart and lib/config/router/app_router.dart.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';

/// While true, the router's guard lets every location through. Off until a
/// page is picked, so the app behaves normally until the demo is used.
final ValueNotifier<bool> demoBypass = ValueNotifier(false);

class _DemoPage {
  const _DemoPage(this.label, this.location, {this.extra});
  final String label;
  final String location;
  final Object? extra;
}

const _groups = <String, List<_DemoPage>>{
  'Website': [_DemoPage('Landing page', '/')],
  'Sign in': [
    _DemoPage('Splash', '/splash'),
    _DemoPage('Onboarding', '/onboarding'),
    _DemoPage('Welcome', '/welcome'),
    _DemoPage('Log in', '/login'),
    _DemoPage('Register', '/register'),
    _DemoPage('Vendor register', '/register?role=vendor'),
    _DemoPage('Forgot password', '/forgot-password'),
    _DemoPage(
      'Email code',
      '/email-sent',
      extra: {'email': 'student@uclm.edu.ph', 'type': 'verification'},
    ),
    _DemoPage('Verification', '/verification'),
    _DemoPage('Complete profile', '/complete-profile'),
    _DemoPage('Account pending', '/account-pending'),
  ],
  'Customer': [
    _DemoPage('Dashboard', '/user'),
    _DemoPage('Shop', '/user/shop'),
    _DemoPage('Orders', '/user/orders'),
    _DemoPage('Track', '/user/track'),
    _DemoPage('Notifications', '/user/notifications'),
    _DemoPage('Profile', '/user/profile'),
    _DemoPage('Edit profile', '/user/profile/edit'),
    _DemoPage('Change password', '/user/profile/change-password'),
    _DemoPage('Settings', '/user/settings'),
    _DemoPage('Cart', '/user/cart'),
    _DemoPage('Checkout', '/user/checkout'),
    _DemoPage('Payment', '/user/payment'),
  ],
  'Vendor': [
    _DemoPage('Dashboard', '/vendor'),
    _DemoPage('Orders', '/vendor/orders'),
    _DemoPage('Products', '/vendor/products'),
    _DemoPage('Add product', '/vendor/products/add'),
    _DemoPage('Profile', '/vendor/profile'),
    _DemoPage('Edit profile', '/vendor/profile/edit'),
    _DemoPage('Notifications', '/vendor/notifications'),
  ],
  'Admin': [
    _DemoPage('Dashboard', '/admin'),
    _DemoPage('Users', '/admin/users'),
    _DemoPage('Drones', '/admin/drones'),
    _DemoPage('Deliveries', '/admin/deliveries'),
    _DemoPage('Analytics', '/admin/analytics'),
    _DemoPage('Weather', '/admin/weather'),
    _DemoPage('Support', '/admin/support'),
    _DemoPage('Settings', '/admin/settings'),
    _DemoPage('Reports', '/admin/reports'),
    _DemoPage('No-fly zones', '/admin/routes/no-fly-zones'),
    _DemoPage('Notifications', '/admin/notifications'),
  ],
  'Shared': [
    _DemoPage('About', '/shared/about'),
    _DemoPage('Help and support', '/shared/help'),
    _DemoPage('Privacy policy', '/shared/privacy-policy'),
    _DemoPage('Terms and conditions', '/shared/terms-conditions'),
  ],
};

/// Lays the Demo tab over [child]. Used from MaterialApp.router's builder,
/// which sits above the Navigator — so the picker opens through
/// [navigatorKey] and navigates through [router] directly.
class DemoOverlay extends StatefulWidget {
  const DemoOverlay({
    super.key,
    required this.router,
    required this.navigatorKey,
    required this.child,
  });

  final GoRouter router;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<DemoOverlay> createState() => _DemoOverlayState();
}

class _DemoOverlayState extends State<DemoOverlay> {
  /// The tab's vertical centre as a fraction of the window height — it can
  /// be dragged along the right edge when it covers something.
  double _y = 0.42;
  bool _pickerOpen = false;

  Future<void> _open() async {
    final navContext = widget.navigatorKey.currentContext;
    // The tab sits above the dialog's barrier, so a second tap would stack
    // a second picker.
    if (navContext == null || _pickerOpen) return;
    _pickerOpen = true;
    final current = widget.router.routerDelegate.currentConfiguration.uri.path;
    await showDialog<void>(
      context: navContext,
      barrierColor: Colors.black54,
      builder: (_) => _DemoPicker(
        current: current,
        onPick: (page) {
          demoBypass.value = true;
          Navigator.of(navContext, rootNavigator: true).pop();
          widget.router.go(page.location, extra: page.extra);
        },
        onExit: () {
          demoBypass.value = false;
          Navigator.of(navContext, rootNavigator: true).pop();
          widget.router.go('/');
        },
      ),
    );
    _pickerOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    const tabHeight = 84.0;
    final top = (_y * height - tabHeight / 2).clamp(
      MediaQuery.paddingOf(context).top + 8,
      height - tabHeight - 8,
    );
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 0,
          top: top,
          child: GestureDetector(
            onVerticalDragUpdate: (d) => setState(
              () => _y = ((_y * height + d.delta.dy) / height).clamp(0.0, 1.0),
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: demoBypass,
              builder: (context, on, _) =>
                  _DemoTab(height: tabHeight, active: on, onTap: _open),
            ),
          ),
        ),
      ],
    );
  }
}

class _DemoTab extends StatelessWidget {
  const _DemoTab({
    required this.height,
    required this.active,
    required this.onTap,
  });

  final double height;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Demo: open any page',
      child: Material(
        color: AppColors.accent,
        elevation: 6,
        shadowColor: Colors.black45,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(12),
          ),
          child: SizedBox(
            width: 30,
            height: height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? const Color(0xFF0B1030) : Colors.white70,
                  ),
                ),
                const SizedBox(height: 6),
                const RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    'DEMO',
                    style: TextStyle(
                      color: Color(0xFF0B1030),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoPicker extends StatelessWidget {
  const _DemoPicker({
    required this.current,
    required this.onPick,
    required this.onExit,
  });

  final String current;
  final ValueChanged<_DemoPage> onPick;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: AppColors.surfaceRaised,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: size.height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Demo — open any page',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign-in checks are off while you browse. '
                          'Pages that need an account show their empty state.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final MapEntry(key: group, value: pages)
                        in _groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Text(
                          group.toUpperCase(),
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final page in pages)
                            _PageChip(
                              page: page,
                              selected:
                                  Uri.parse(page.location).path == current,
                              onTap: () => onPick(page),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: demoBypass,
                      builder: (context, on, _) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          on ? 'Demo mode is on' : 'Demo mode is off',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onExit,
                    child: Text(
                      'Exit demo',
                      style: TextStyle(color: AppColors.accentText),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageChip extends StatelessWidget {
  const _PageChip({
    required this.page,
    required this.selected,
    required this.onTap,
  });

  final _DemoPage page;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentFill : AppColors.surfaceSunken,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            page.label,
            style: TextStyle(
              color: selected ? AppColors.onAccentFill : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
