import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'aerodrop_floating_action_button.dart';

class AeroDropBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onFabPressed;

  const AeroDropBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.onFabPressed,
  });

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.home_rounded,
      Icons.radar_rounded,
      Icons.receipt_long_rounded,
      Icons.person_rounded,
    ];

    final labels = ['Home', 'Track', 'History', 'Profile'];

    return ClipRRect(
      borderRadius: BorderRadius.circular(32), // Rounded corners (28-32px)
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Premium Glassmorphism
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.cardDark.withValues(alpha: 0.8), // Dark theme surface
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08), // Subtle premium border
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildNavItem(context, 0, icons[0], labels[0])),
              Expanded(child: _buildNavItem(context, 1, icons[1], labels[1])),
              AeroDropFloatingActionButton(onPressed: onFabPressed),
              Expanded(child: _buildNavItem(context, 2, icons[2], labels[2])),
              Expanded(child: _buildNavItem(context, 3, icons[3], labels[3])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    String label,
  ) {
    final isActive = selectedIndex == index;
    
    // Theme-compatible colors
    final activeIconColor = AppColors.primaryDark; // Blue icon inside yellow pill
    final inactiveColor = AppColors.textSecondaryDark; // Slate gray for inactive
    final yellowIndicator = AppColors.accent; // Brand Vivid Yellow

    return Material(
      color: Colors.transparent,
      child: Center(
        child: InkWell(
          onTap: () => onTap(index),
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          splashColor: AppColors.primaryLight.withValues(alpha: 0.1),
          highlightColor: AppColors.primaryLight.withValues(alpha: 0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? yellowIndicator // Solid Yellow active indicator pill
                  : Colors.transparent,
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
                  size: 22,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTextStyles.label(
                    fontSize: 10,
                    color: isActive ? activeIconColor : inactiveColor,
                  ).copyWith(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
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
