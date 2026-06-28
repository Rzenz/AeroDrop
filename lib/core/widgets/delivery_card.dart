import 'package:flutter/material.dart';
import '../models/delivery_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'status_chip.dart';
import 'animated_card.dart';

class DeliveryCard extends StatelessWidget {
  final DeliveryModel delivery;
  final VoidCallback? onTap;

  const DeliveryCard({
    super.key,
    required this.delivery,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isInTransit = delivery.status == DeliveryStatus.inTransit;

    return AnimatedCard(
      onTap: onTap,
      borderGradient: LinearGradient(
        colors: isInTransit
            ? [AppColors.accent, AppColors.primary]
            : [AppColors.borderDark, AppColors.borderDark.withValues(alpha: 0.4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Stack(
        children: [
          // Subtle background decoration for active items
          if (isInTransit)
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.08),
                ),
              ),
            ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    delivery.id,
                    style: AppTextStyles.label(
                      fontSize: 11,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  StatusChip.delivery(delivery.status.name),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                delivery.packageName,
                style: AppTextStyles.title(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      delivery.deliveryAddress,
                      style: AppTextStyles.body(
                        fontSize: 12.5,
                        color: AppColors.textSecondaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (isInTransit) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ETA: ${delivery.eta}',
                      style: AppTextStyles.body(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                    Text(
                      '${(delivery.progress * 100).toInt()}%',
                      style: AppTextStyles.body(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: delivery.progress,
                    backgroundColor: AppColors.borderDark,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                    minHeight: 5,
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      delivery.packageType,
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    Text(
                      '${delivery.packageWeight} kg',
                      style: AppTextStyles.body(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
