import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class VendorShell extends StatelessWidget {
  final Widget child;
  const VendorShell({super.key, required this.child});

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
    HapticFeedback.selectionClick();
    switch (index) {
      case 0:
        context.go('/vendor');
        break;
      case 1:
        context.go('/vendor/products');
        break;
      case 2:
        context.go('/vendor/orders');
        break;
      case 3:
        context.go('/vendor/notifications');
        break;
      case 4:
        context.go('/vendor/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex(context);
    final icons = [
      Icons.dashboard_rounded,
      Icons.inventory_2_rounded,
      Icons.receipt_long_rounded,
      Icons.notifications_rounded,
      Icons.person_rounded,
    ];
    final labels = ['Home', 'Products', 'Orders', 'Notifications', 'Profile'];

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.cardDark.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    return Expanded(
                      child: _buildNavItem(
                        context,
                        index,
                        selected,
                        icons[index],
                        labels[index],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    int selectedIndex,
    IconData icon,
    String label,
  ) {
    final isActive = selectedIndex == index;
    final activeIconColor = AppColors.primaryDark;
    final inactiveColor = AppColors.textSecondaryDark;
    final yellowIndicator = AppColors.accent;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: InkWell(
          onTap: () => _onTap(index, context),
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          splashColor: AppColors.primaryLight.withValues(alpha: 0.1),
          highlightColor: AppColors.primaryLight.withValues(alpha: 0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              color: isActive ? yellowIndicator : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: yellowIndicator.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isActive ? activeIconColor : inactiveColor,
                  size: 20,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style:
                      AppTextStyles.label(
                        fontSize: 9.5,
                        color: isActive ? activeIconColor : inactiveColor,
                      ).copyWith(
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
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
