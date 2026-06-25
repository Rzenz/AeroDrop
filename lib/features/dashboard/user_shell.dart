import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class UserShell extends StatelessWidget {
  final Widget child;
  const UserShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/user/track')) return 1;
    if (loc.startsWith('/user/history')) return 2;
    if (loc.startsWith('/user/profile')) return 3;
    return 0;
  }

  void _onTap(int index, BuildContext context) {
    HapticFeedback.selectionClick();
    switch (index) {
      case 0: context.go('/user'); break;
      case 1: context.go('/user/track'); break;
      case 2: context.go('/user/history'); break;
      case 3: context.go('/user/profile'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex(context);

    const icons = [
      Icons.dashboard_rounded,
      Icons.location_on_rounded,
      Icons.receipt_long_rounded,
      Icons.person_rounded,
    ];
    const labels = ['Home', 'Track', 'History', 'Profile'];

    return Scaffold(
      extendBody: true, // body goes under the translucent nav bar
      body: child,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push('/user/request');
        },
        backgroundColor: AppColors.primary,
        elevation: 8,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppColors.purpleCyanGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AnimatedBottomNavigationBar.builder(
        itemCount: 4,
        tabBuilder: (index, isActive) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icons[index],
                color: isActive ? AppColors.primary : AppColors.textSecondaryDark,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                labels[index],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? AppColors.primary : AppColors.textSecondaryDark,
                ),
              ),
            ],
          );
        },
        activeIndex: selected,
        gapLocation: GapLocation.center,
        notchSmoothness: NotchSmoothness.verySmoothEdge,
        onTap: (i) => _onTap(i, context),
        backgroundColor: AppColors.cardDark,
        splashColor: AppColors.primary.withValues(alpha: 0.15),
        splashSpeedInMilliseconds: 300,
        shadow: BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 24,
          offset: const Offset(0, -4),
        ),
      ),
    );
  }
}
