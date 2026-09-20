import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/neu_nav_dock.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/providers/order_provider.dart';

/// Navigation shell for the vendor role.
///
/// Five destinations and no centre action — vendors act inside each screen
/// rather than from the dock.
class VendorShell extends ConsumerWidget {
  const VendorShell({super.key, required this.child});

  final Widget child;

  static const _routes = [
    '/vendor',
    '/vendor/products',
    '/vendor/orders',
    '/vendor/notifications',
    '/vendor/profile',
  ];

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/vendor/products')) return 1;
    if (loc.startsWith('/vendor/orders')) return 2;
    if (loc.startsWith('/vendor/notifications')) return 3;
    if (loc.startsWith('/vendor/profile')) return 4;
    return 0;
  }

  void _onTap(int index, BuildContext context) {
    if (index == _selectedIndex(context)) return;
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final actionOrdersCount = ref.watch(vendorActionOrdersCountProvider);

    final items = [
      const NeuNavItem(icon: Icons.dashboard_rounded, label: 'Home'),
      const NeuNavItem(icon: Icons.inventory_2_rounded, label: 'Products'),
      NeuNavItem(
        icon: Icons.receipt_long_rounded,
        label: 'Orders',
        badge: actionOrdersCount > 0 ? actionOrdersCount : null,
      ),
      NeuNavItem(
        icon: Icons.notifications_rounded,
        label: 'Alerts',
        badge: unreadCount > 0 ? unreadCount : null,
      ),
      const NeuNavItem(icon: Icons.person_rounded, label: 'Profile'),
    ];

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: NeuNavDock(
            items: items,
            selectedIndex: _selectedIndex(context),
            onTap: (i) => _onTap(i, context),
          ),
        ),
      ),
    );
  }
}
