import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/utils/logout_helper.dart';

import '../../core/services/supabase_service.dart';
import '../../core/widgets/neu_action_fan.dart';
import '../../core/widgets/neu_nav_dock.dart';

/// One admin destination.
class _Dest {
  const _Dest(this.icon, this.label, this.route);

  final IconData icon;
  final String label;
  final String route;
}

/// The four an admin lives in day to day. These get the dock.
const _primary = <_Dest>[
  _Dest(Icons.dashboard_rounded, 'Dashboard', '/admin'),
  _Dest(Icons.local_shipping_rounded, 'Deliveries', '/admin/deliveries'),
  _Dest(Icons.flight_takeoff_rounded, 'Fleet', '/admin/drones'),
  _Dest(Icons.people_rounded, 'Users', '/admin/users'),
];

/// The rest, plus sign out. These fan out of the centre button.
const _extra = <_Dest>[
  _Dest(Icons.bar_chart_rounded, 'Analytics', '/admin/analytics'),
  _Dest(Icons.map_rounded, 'Flight\nBoundaries', '/admin/routes/no-fly-zones'),
  _Dest(Icons.wb_sunny_rounded, 'Weather', '/admin/weather'),
  _Dest(Icons.analytics_outlined, 'System\nLogs', '/admin/reports'),
  _Dest(Icons.settings_rounded, 'Settings', '/admin/settings'),
];

/// The admin pages paint themselves dark whatever the app theme says, so the
/// dock has to be told the same rather than resolving its own. Without this it
/// renders in the light palette on a dark page the moment the user switches
/// the theme, which reads as a bright bar pasted over the screen.
final List<BoxShadow> _adminDockShadows = [
  BoxShadow(
    color: AppColors.neuDarkShadowDark.withValues(alpha: 0.7),
    offset: const Offset(0, 12),
    blurRadius: 28,
    spreadRadius: -6,
  ),
  BoxShadow(
    color: AppColors.neuLightShadowDark.withValues(alpha: 0.35),
    offset: const Offset(-4, -4),
    blurRadius: 12,
  ),
];

bool _isActive(String route, String current) =>
    current == route || (route != '/admin' && current.startsWith(route));

/// Navigation shell for the admin role.
///
/// The drawer is gone. Nine destinations behind a hamburger meant every one of
/// them cost two taps and none were visible; the dock puts the four that
/// matter one tap away on every screen and matches the customer shell, and the
/// remaining five fan out of the same centre button the customer shell uses
/// for its cart.
class AdminShell extends ConsumerStatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fan;

  @override
  void initState() {
    super.initState();
    _fan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      // Opening is a flourish; closing is getting out of the way. The skills
      // are explicit that these should not take the same time.
      reverseDuration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _fan.dispose();
    super.dispose();
  }

  bool get _open =>
      _fan.status == AnimationStatus.forward ||
      _fan.status == AnimationStatus.completed;

  void _toggle() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _fan.value = _open ? 0 : 1;
      setState(() {});
      return;
    }
    _open ? _fan.reverse() : _fan.forward();
    setState(() {});
  }

  void _close() {
    if (!_open) return;
    MediaQuery.disableAnimationsOf(context) ? _fan.value = 0 : _fan.reverse();
    setState(() {});
  }

  /// Height the dock occupies at the bottom of the body. The centre action
  /// overhangs above this, but that band is transparent, so content passing
  /// under it reads as scrolling behind a floating control.
  double _dockSpace(BuildContext context) =>
      70 + 12 + MediaQuery.paddingOf(context).bottom;

  void _goto(String route) {
    _close();
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    if (SupabaseService.isConfigured) {
      Future.microtask(() {
        ref.read(deliveryProvider.notifier).loadAdminDeliveriesFromSupabase();
      });
    }

    final loc = GoRouterState.of(context).uri.toString();
    final pending = ref.watch(pendingDeliveriesCountProvider);
    final selected = _primary.indexWhere((d) => _isActive(d.route, loc));

    return PopScope(
      // An open fan is a layer over the page; back should shut it rather than
      // leave the screen with it still hanging there.
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: const _AdminAppBar(),
        // The dock lives in the body rather than in bottomNavigationBar so the
        // fan's scrim can pass behind it. In the bar slot the scrim stopped at
        // the dock's edge, which left it lit like a panel while everything
        // around it dimmed.
        body: Stack(
          children: [
            // Room reserved for the dock, so the admin screens underneath —
            // none of which know about it — keep their last row visible.
            Padding(
              padding: EdgeInsets.only(bottom: _dockSpace(context)),
              child: widget.child,
            ),
            NeuActionFan(
              progress: _fan,
              onDismiss: _close,
              bottomInset: _dockSpace(context),
              actions: [
                for (final d in _extra)
                  NeuFanAction(
                    icon: d.icon,
                    label: d.label,
                    active: _isActive(d.route, loc),
                    onTap: () => _goto(d.route),
                  ),
                NeuFanAction(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  destructive: true,
                  onTap: () {
                    _close();
                    showLogoutConfirmation(context, ref);
                  },
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: NeuNavDock(
                    items: [
                      for (final d in _primary)
                        NeuNavItem(
                          icon: d.icon,
                          label: d.label,
                          badge: d.route == '/admin/deliveries'
                              ? pending
                              : null,
                        ),
                    ],
                    selectedIndex: selected < 0 ? 0 : selected,
                    onTap: (i) => _goto(_primary[i].route),
                    surfaceColor: AppColors.bgDark,
                    borderColor: AppColors.borderDark,
                    shadows: _adminDockShadows,
                    selectedColor: AppColors.accent,
                    unselectedColor: AppColors.textTertiaryDark,
                    centerAction: NeuFanToggle(
                      progress: _fan,
                      onPressed: _toggle,
                      semanticLabel: _open ? 'Close menu' : 'More destinations',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ponytail: removed stale BuildContext field — use the build()'s own context.
class _AdminAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _AdminAppBar();

  String _titleForRoute(String loc) {
    if (loc.startsWith('/admin/users')) return 'Users & Vendors';
    if (loc.startsWith('/admin/drones')) return 'Drone Fleet';
    if (loc.startsWith('/admin/deliveries')) return 'Deliveries';
    if (loc.startsWith('/admin/analytics')) return 'Analytics';
    if (loc.startsWith('/admin/routes/no-fly-zones')) {
      return 'Flight Boundaries';
    }
    if (loc.startsWith('/admin/reports')) return 'System Logs';
    if (loc.startsWith('/admin/weather')) return 'Weather Controls';
    if (loc.startsWith('/admin/settings')) return 'Settings';
    return 'Command Deck';
  }

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final loc = GoRouterState.of(ctx).uri.toString();
    final user = ref.watch(authProvider).user;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AppBar(
            backgroundColor: AppColors.bgDark.withValues(alpha: 0.8),
            elevation: 0,
            centerTitle: false,
            titleSpacing: 20,
            title: Text(
              _titleForRoute(loc),
              style: AppTextStyles.title(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            actions: [
              _ProfileButton(user: user),
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      color: AppColors.accent,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'ADMIN',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// The admin's own avatar, and the way into their profile.
///
/// It replaces the drawer header, which was where that link used to live.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.user});

  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final name = (user?.name as String?) ?? 'Admin';
    final avatar = user?.avatarUrl as String?;

    return Semantics(
      button: true,
      label: 'Your admin profile',
      child: GestureDetector(
        onTap: user?.id == null
            ? null
            : () => context.push('/admin/users/${user.id}'),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: avatar == null ? AppColors.accentGradient : null,
            shape: BoxShape.circle,
            image: avatar == null
                ? null
                : DecorationImage(
                    image: NetworkImage(avatar),
                    fit: BoxFit.cover,
                  ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: avatar != null
              ? null
              : Text(
                  name.isEmpty ? 'A' : name[0].toUpperCase(),
                  style: AppTextStyles.title(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.bgDark,
                  ),
                ),
        ),
      ),
    );
  }
}
