import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'neu_card.dart';
import 'neu_surface.dart';

/// The standard row: an icon well, a title, optional supporting text, and a
/// trailing affordance.
///
/// Settings, menus, profile options and detail rows all collapse onto this so
/// they share one height, one icon size and one chevron. Screens that hand-roll
/// their own row are where inconsistency creeps back in.
class NeuListTile extends StatelessWidget {
  const NeuListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.leading,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron = true,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Tints the icon and its well. Defaults to the brand blue, or danger when
  /// [destructive].
  final Color? iconColor;

  /// Replaces the icon well entirely (an avatar, a thumbnail, a checkbox).
  final Widget? leading;

  /// Replaces the chevron (a switch, a value, a badge).
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Sign-out, delete, revoke. Colours the title and icon with the danger tone
  /// so the row reads as consequential before it is tapped.
  final bool destructive;

  final bool showChevron;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tint = destructive
        ? AppColors.danger
        : (iconColor ?? AppColors.primaryText);
    final titleColor = destructive ? AppColors.danger : AppColors.textPrimary;
    final wellSize = dense ? 34.0 : 38.0;

    return NeuCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: dense ? AppSpacing.xs + 2 : AppSpacing.sm,
      ),
      borderRadius: AppRadii.brMd,
      semanticLabel: subtitle == null ? title : '$title. $subtitle',
      child: Row(
        children: [
          if (leading != null)
            leading!
          else if (icon != null)
            NeuSurface(
              style: NeuStyle.inset,
              depth: NeuDepth.flat,
              width: wellSize,
              height: wellSize,
              alignment: Alignment.center,
              borderRadius: AppRadii.brSm,
              color: Color.alphaBlend(
                tint.withValues(alpha: 0.12),
                AppColors.surfaceSunken,
              ),
              child: Icon(icon, size: dense ? 17 : 19, color: tint),
            ),
          if (leading != null || icon != null)
            const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.subHead(
                    fontSize: dense ? 14 : 14.5,
                    color: titleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTextStyles.caption(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.xs),
            trailing!,
          ] else if (onTap != null && showChevron) ...[
            const SizedBox(width: AppSpacing.xxs),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ],
      ),
    );
  }
}

/// A labelled group of [NeuListTile]s.
///
/// The label sits *outside* the group, so the tiles keep a clean edge and the
/// eye can scan headings without them competing with row titles.
class NeuTileGroup extends StatelessWidget {
  const NeuTileGroup({super.key, this.label, required this.children});

  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xxs,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              label!.toUpperCase(),
              style: AppTextStyles.label(
                fontSize: 11,
                color: AppColors.textTertiary,
                letterSpacing: 0.9,
              ),
            ),
          ),
        ],
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          children[i],
        ],
      ],
    );
  }
}

/// A label/value row for read-only detail panels — order summaries, receipts,
/// specification blocks.
class NeuDetailRow extends StatelessWidget {
  const NeuDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
    this.valueColor,
  });

  final String label;
  final String value;

  /// Totals and headline figures. Bumps the size and weight of the value.
  final bool emphasis;

  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs - 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body(
                fontSize: emphasis ? 14 : 13,
                color: emphasis
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            textAlign: TextAlign.right,
            style: emphasis
                ? AppTextStyles.numeric(
                    fontSize: 16,
                    color: valueColor ?? AppColors.accentText,
                  )
                : AppTextStyles.body(
                    fontSize: 13,
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
          ),
        ],
      ),
    );
  }
}
