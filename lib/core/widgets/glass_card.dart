import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// True BackdropFilter glassmorphism card.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final double opacity;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final Gradient? gradient;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.blur = 12,
    this.opacity = 0.08,
    this.borderColor,
    this.borderRadius,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(20);
    final border = borderColor ?? (isDark ? AppColors.borderDark : AppColors.borderLight);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: gradient ??
                LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withValues(alpha: opacity),
                          Colors.white.withValues(alpha: opacity * 0.4),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.7),
                          Colors.white.withValues(alpha: 0.4),
                        ],
                ),
            borderRadius: radius,
            border: Border.all(color: border.withValues(alpha: 0.6), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}
