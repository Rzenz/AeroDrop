import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Compact status pill.
///
/// Carries a colour *and* a filled dot: status is load-bearing information, so
/// it must survive greyscale and colour-blind viewing. The tinted fill stays at
/// 12% so a list of chips does not turn into a row of coloured blocks.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.dense = false,
  });

  final String label;
  final Color color;
  final bool dense;

  factory StatusChip.delivery(String statusStr) {
    final key = statusStr.toLowerCase();
    final (Color color, String label) = switch (key) {
      'pending' => (AppColors.warning, 'PENDING'),
      'assigning' => (AppColors.info, 'ASSIGNING'),
      'intransit' ||
      'in_transit' ||
      'transit' => (AppColors.primary, 'IN TRANSIT'),
      'delivered' => (AppColors.success, 'DELIVERED'),
      'cancelled' => (AppColors.danger, 'CANCELLED'),
      _ => (AppColors.textTertiary, statusStr.toUpperCase()),
    };
    return StatusChip(label: label, color: color);
  }

  factory StatusChip.drone(String statusStr) {
    final key = statusStr.toLowerCase();
    final (Color color, String label) = switch (key) {
      'available' => (AppColors.success, 'AVAILABLE'),
      'assigned' => (AppColors.primaryLight, 'ASSIGNED'),
      'busy' => (AppColors.accent, 'BUSY'),
      'charging' => (AppColors.info, 'CHARGING'),
      'maintenance' => (AppColors.warning, 'MAINTENANCE'),
      'offline' => (AppColors.danger, 'OFFLINE'),
      _ => (AppColors.textTertiary, statusStr.toUpperCase()),
    };
    return StatusChip(label: label, color: color);
  }

  @override
  Widget build(BuildContext context) {
    // The fill and border stay saturated; only the label needs adjusting,
    // because text carries the stricter contrast requirement.
    final labelColor = AppColors.readable(color);

    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 7 : 9,
          vertical: dense ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadii.brPill,
          border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label(
                  fontSize: dense ? 9 : 10,
                  color: labelColor,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
