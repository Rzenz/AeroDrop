import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import 'neu_surface.dart';

/// Standalone floating action button.
///
/// Accent-filled with a soft halo — the FAB is the one control allowed to
/// announce itself loudly, because it is the screen's single primary action.
class AnimatedFAB extends StatelessWidget {
  const AnimatedFAB({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 56,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) => NeuPressable(
    onTap: onPressed,
    width: size,
    height: size,
    borderRadius: BorderRadius.circular(size / 2),
    color: AppColors.accentFill,
    alignment: Alignment.center,
    depth: NeuDepth.medium,
    semanticLabel: tooltip,
    scaleOnPress: 0.92,
    child: Icon(icon, color: AppColors.onAccentFill, size: size * 0.44),
  );

  /// Shadow used when this FAB is composed into a nav dock.
  static List<BoxShadow> get halo =>
      AppShadows.glow(AppColors.accentFill, alpha: 0.28);
}
