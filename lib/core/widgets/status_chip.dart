import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
  });

  factory StatusChip.delivery(String statusStr) {
    Color color;
    String label = statusStr.toUpperCase();
    switch (statusStr.toLowerCase()) {
      case 'pending':
        color = AppColors.warning;
        break;
      case 'assigning':
        color = AppColors.secondary;
        break;
      case 'intransit':
      case 'in_transit':
      case 'transit':
        color = AppColors.primary;
        label = 'IN TRANSIT';
        break;
      case 'delivered':
        color = AppColors.success;
        break;
      case 'cancelled':
        color = AppColors.danger;
        break;
      default:
        color = Colors.grey;
    }
    return StatusChip(label: label, color: color);
  }

  factory StatusChip.drone(String statusStr) {
    Color color;
    String label = statusStr.toUpperCase();
    switch (statusStr.toLowerCase()) {
      case 'available':
        color = AppColors.success;
        break;
      case 'busy':
        color = AppColors.primary;
        break;
      case 'maintenance':
        color = AppColors.warning;
        break;
      case 'offline':
        color = AppColors.danger;
        break;
      default:
        color = Colors.grey;
    }
    return StatusChip(label: label, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: AppTextStyles.body(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
