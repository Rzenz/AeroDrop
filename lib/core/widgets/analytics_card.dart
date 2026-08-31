import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'neu_card.dart';
import 'neu_surface.dart';

/// A single metric: value, label, delta, and an icon that identifies it.
///
/// The icon well is inset while the card is raised — that contrast is what
/// keeps a grid of these from reading as a flat wall of boxes.
class AnalyticsCard extends StatelessWidget {
  const AnalyticsCard({
    super.key,
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.icon,
    required this.iconColor,
    this.animDelay = 0,
    this.onTap,
  });

  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final IconData icon;
  final Color iconColor;
  final int animDelay;
  final VoidCallback? onTap;

  /// Height this card needs at the current text scale. Callers should feed
  /// this to `SliverGridDelegate.mainAxisExtent` — a fixed `childAspectRatio`
  /// makes tile height a function of screen *width*, which has nothing to do
  /// with how tall the content actually is and overflows on narrow phones.
  static double preferredHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);
    return 124 * scale;
  }

  @override
  Widget build(BuildContext context) {
    final deltaColor = isPositive ? AppColors.success : AppColors.danger;

    final header = Row(
      children: [
        NeuSurface(
          style: NeuStyle.inset,
          depth: NeuDepth.flat,
          width: 32,
          height: 32,
          alignment: Alignment.center,
          borderRadius: AppRadii.brSm,
          color: AppColors.surfaceSunken,
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: AppSpacing.xs),
        const Spacer(),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: deltaColor.withValues(alpha: 0.12),
              borderRadius: AppRadii.brPill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPositive
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: deltaColor,
                  size: 11,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    change,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label(
                      fontSize: 10,
                      color: AppColors.readable(deltaColor),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return NeuCardEntrance(
      index: animDelay ~/ 60,
      child: NeuCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        borderRadius: AppRadii.brLg,
        semanticLabel: '$title: $value, $change',
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Only take flexible children when the height is actually bounded —
            // a flex child under unbounded constraints throws.
            final bounded = constraints.maxHeight.isFinite;

            final body = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.numeric(fontSize: 22),
                ),
                const SizedBox(height: 2),
                _label(bounded),
              ],
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                header,
                const SizedBox(height: AppSpacing.xs + 2),
                if (bounded) Flexible(child: body) else body,
              ],
            );
          },
        ),
      ),
    );
  }

  /// The metric label. Given a bounded height it becomes flexible so it can
  /// give up its second line instead of overflowing the tile.
  Widget _label(bool bounded) {
    final text = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondary),
    );
    return bounded ? Flexible(child: text) : text;
  }
}
