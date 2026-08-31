import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/neu_nav_dock.dart';

/// Navigation shell for the vendor role.
///
/// Five destinations and no centre action — vendors act inside each screen
/// rather than from the dock.
class VendorShell extends StatelessWidget {
  const VendorShell({super.key, required this.child});

  final Widget child;

  static const _items = [
    NeuNavItem(icon: Icons.dashboard_rounded, label: 'Home'),
    NeuNavItem(icon: Icons.inventory_2_rounded, label: 'Products'),
    NeuNavItem(icon: Icons.receipt_long_rounded, label: 'Orders'),
    NeuNavItem(icon: Icons.notifications_rounded, label: 'Alerts'),
    NeuNavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

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
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: NeuNavDock(
            items: _items,
            selectedIndex: _selectedIndex(context),
            onTap: (i) => _onTap(i, context),
          ),
        ),
      ),
    );
  }
}
