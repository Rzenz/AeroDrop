import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';

/// A single shimmering placeholder block.
///
/// Skeletons are painted on the *sunken* surface: a loading placeholder is an
/// empty well waiting to be filled, not a raised card that already exists.
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = 10,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: AppColors.surfaceSunken,
    highlightColor: AppColors.surfaceRaised,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );
}

/// A row-shaped skeleton matching the proportions of [AnimatedCard], so the
/// layout does not shift when real content arrives.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 84});

  final double height;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Shimmer.fromColors(
      baseColor: AppColors.surfaceSunken,
      highlightColor: AppColors.surfaceRaised,
      child: Container(
        height: height,
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: AppRadii.brLg,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: AppRadii.brSm,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: AppRadii.brXs,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    height: 10,
                    width: 130,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: AppRadii.brXs,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
