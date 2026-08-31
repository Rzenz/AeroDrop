import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'neu_card.dart';

/// A list-row card: leading slot, title/subtitle stack, trailing affordance.
///
/// Thin wrapper over [NeuCard] — it exists so the dozens of list rows across
/// the app share one row rhythm rather than each re-deciding its own padding.
class AnimatedCard extends StatelessWidget {
  const AnimatedCard({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.child,
    this.onTap,
    this.accent,
    this.padding,
    this.borderRadius,
    this.animate = true,
    this.index = 0,
  });

  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Custom content. When supplied, title/subtitle/leading/trailing are ignored.
  final Widget? child;

  final VoidCallback? onTap;

  /// Semantic rim colour — status, brand, category.
  final Color? accent;

  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final bool animate;
  final int index;

  @override
  Widget build(BuildContext context) {
    final content =
        child ??
        Row(
          children: [
            if (leading != null) ...[leading!, AppSpacing.gapMd],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: AppTextStyles.subHead(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ] else if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ],
          ],
        );

    final card = NeuCard(
      onTap: onTap,
      accent: accent,
      depth: NeuDepth.low,
      padding: padding ?? AppSpacing.allMd,
      borderRadius: borderRadius ?? AppRadii.brLg,
      child: content,
    );

    return NeuCardEntrance(index: index, enabled: animate, child: card);
  }
}
