import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/auth_provider.dart';

class AdminShell extends ConsumerWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      drawer: _AdminDrawer(user: user, ref: ref),
      appBar: _AdminAppBar(context: context),
      body: child,
    );
  }
}

class _AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final BuildContext context;
  const _AdminAppBar({required this.context});

  String _titleForRoute(String loc) {
    if (loc.startsWith('/admin/users')) return 'Users';
    if (loc.startsWith('/admin/drones')) return 'Drone Fleet';
    if (loc.startsWith('/admin/deliveries')) return 'Deliveries';
    if (loc.startsWith('/admin/analytics')) return 'Analytics';
    if (loc.startsWith('/admin/settings')) return 'Settings';
    return 'Command Deck';
  }

  @override
  Widget build(BuildContext ctx) {
    final loc = GoRouterState.of(context).uri.toString();
    return AppBar(
      backgroundColor: AppColors.bgDark,
      elevation: 0,
      centerTitle: false,
      leading: Builder(
        builder: (c) => GestureDetector(
          onTap: () => Scaffold.of(c).openDrawer(),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: const Icon(Icons.menu_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
      title: Text(
        _titleForRoute(loc),
        style: AppTextStyles.title(
            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_rounded, color: AppColors.danger, size: 14),
              SizedBox(width: 4),
              Text('ADMIN',
                  style: TextStyle(
                      color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AdminDrawer extends StatelessWidget {
  final dynamic user;
  final WidgetRef ref;
  const _AdminDrawer({this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'Admin';
    final email = user?.email ?? '';
    final loc = GoRouterState.of(context).uri.toString();

    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Drawer(
          backgroundColor: AppColors.bgDark.withValues(alpha: 0.95),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                    20, MediaQuery.of(context).padding.top + 20, 20, 24),
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        gradient: AppColors.purpleCyanGradient,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 16)
                        ],
                      ),
                      child: Center(
                        child: Text(name[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(name,
                        style: AppTextStyles.title(
                            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(email,
                        style: AppTextStyles.body(
                            fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('System Administrator',
                          style: TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // Nav items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  children: [
                    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard',
                        route: '/admin', current: loc, onTap: () => context.go('/admin')),
                    _NavItem(icon: Icons.people_rounded, label: 'Users',
                        route: '/admin/users', current: loc, onTap: () => context.go('/admin/users')),
                    _NavItem(icon: Icons.flight_takeoff_rounded, label: 'Drone Fleet',
                        route: '/admin/drones', current: loc, onTap: () => context.go('/admin/drones')),
                    _NavItem(icon: Icons.local_shipping_rounded, label: 'Deliveries',
                        route: '/admin/deliveries', current: loc,
                        onTap: () => context.go('/admin/deliveries')),
                    _NavItem(icon: Icons.bar_chart_rounded, label: 'Analytics',
                        route: '/admin/analytics', current: loc,
                        onTap: () => context.go('/admin/analytics')),
                    _NavItem(icon: Icons.settings_rounded, label: 'Settings',
                        route: '/admin/settings', current: loc,
                        onTap: () => context.go('/admin/settings')),
                  ],
                ),
              ),

              // Sign out
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                child: GestureDetector(
                  onTap: () {
                    ref.read(authProvider.notifier).logout();
                    context.go('/login');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: AppColors.danger, size: 18),
                        SizedBox(width: 8),
                        Text('Sign Out',
                            style: TextStyle(
                                color: AppColors.danger, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String current;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = current == route || (route != '/admin' && current.startsWith(route));
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.primaryGradient : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isActive ? Colors.white : AppColors.textSecondaryDark, size: 20),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    color: isActive ? Colors.white : AppColors.textSecondaryDark,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15)),
            if (isActive) ...[
              const Spacer(),
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
