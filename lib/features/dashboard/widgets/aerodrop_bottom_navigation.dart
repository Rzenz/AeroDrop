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
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onFabPressed;
  final int cartCount;

  static const _items = [
    NeuNavItem(icon: Icons.home_rounded, label: 'Home'),
    NeuNavItem(icon: Icons.storefront_rounded, label: 'Shop'),
    NeuNavItem(icon: Icons.receipt_long_rounded, label: 'Orders'),
    NeuNavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) => NeuNavDock(
    items: _items,
    selectedIndex: selectedIndex,
    onTap: onTap,
    centerActionAfterIndex: 1,
    centerAction: AeroDropFloatingActionButton(
      onPressed: onFabPressed,
      badgeCount: cartCount,
    ),
  );
}
