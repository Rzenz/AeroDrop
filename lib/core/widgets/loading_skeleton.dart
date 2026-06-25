import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

/// Shimmer skeleton using the shimmer package.
class LoadingSkeleton extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const LoadingSkeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.cardDark2 : const Color(0xFFE8ECF8),
      highlightColor: isDark ? AppColors.borderDark : const Color(0xFFF5F7FF),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark2 : const Color(0xFFE8ECF8),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Full card-sized shimmer skeleton for list rows.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.cardDark2 : const Color(0xFFE8ECF8),
      highlightColor: isDark ? AppColors.borderDark : const Color(0xFFF5F7FF),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 80,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark2 : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
