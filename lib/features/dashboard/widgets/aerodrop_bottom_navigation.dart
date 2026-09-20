import 'package:flutter/material.dart';

import '../../../core/widgets/neu_nav_dock.dart';
import 'aerodrop_floating_action_button.dart';

/// The customer navigation dock: four destinations with the cart action
/// sitting between Shop and Orders.
class AeroDropBottomNavigation extends StatelessWidget {
  const AeroDropBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.onFabPressed,
    this.cartCount = 0,
    this.ordersCount = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onFabPressed;
  final int cartCount;
  final int ordersCount;

  @override
  Widget build(BuildContext context) {
    final items = [
      const NeuNavItem(icon: Icons.home_rounded, label: 'Home'),
      const NeuNavItem(icon: Icons.storefront_rounded, label: 'Shop'),
      NeuNavItem(
        icon: Icons.receipt_long_rounded,
        label: 'Orders',
        badge: ordersCount > 0 ? ordersCount : null,
      ),
      const NeuNavItem(icon: Icons.person_rounded, label: 'Profile'),
    ];

    return NeuNavDock(
      items: items,
      selectedIndex: selectedIndex,
      onTap: onTap,
      centerActionAfterIndex: 1,
      centerAction: AeroDropFloatingActionButton(
        onPressed: onFabPressed,
        badgeCount: cartCount,
      ),
    );
  }
}
