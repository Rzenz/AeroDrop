import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/drone_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'status_chip.dart';
import 'animated_card.dart';

class DroneCard extends StatelessWidget {
  final DroneModel drone;
  final VoidCallback? onTap;

  const DroneCard({
    super.key,
    required this.drone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color batteryColor;
    if (drone.batteryLevel > 50) {
      batteryColor = AppColors.success;
    } else if (drone.batteryLevel > 20) {
      batteryColor = AppColors.warning;
    } else {
      batteryColor = AppColors.danger;
    }

    // Determine status glow color
    Color statusColor;
    switch (drone.status) {
      case DroneStatus.available:
        statusColor = AppColors.success;
        break;
      case DroneStatus.busy:
        statusColor = AppColors.primary;
        break;
      case DroneStatus.maintenance:
        statusColor = AppColors.warning;
        break;
      case DroneStatus.offline:
        statusColor = AppColors.danger;
        break;
    }

    return AnimatedCard(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Ambient background glow from the status
              Positioned(
                top: -40,
                right: -40,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        statusColor.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Circular Battery Arc Indicator
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            value: drone.batteryLevel / 100,
                            strokeWidth: 4.5,
                            backgroundColor: (isDark ? AppColors.borderDark : AppColors.borderLight).withValues(alpha: 0.5),
                            valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
                          ),
                        ),
                        // Inside battery stats
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${drone.batteryLevel.toInt()}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                            Icon(
                              drone.status == DroneStatus.busy 
                                  ? Icons.bolt_rounded 
                                  : Icons.battery_charging_full_rounded,
                              size: 11,
                              color: batteryColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 18),

                    // Middle details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  drone.name,
                                  style: AppTextStyles.title(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Pulsing Status Dot next to chip
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusColor.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ).animate(onPlay: (c) => c.repeat(reverse: true))
                               .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.3, 1.3), duration: 800.ms)
                               .fadeIn(duration: 800.ms),
                              const SizedBox(width: 6),
                              StatusChip.drone(drone.status.name),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            drone.modelType,
                            style: AppTextStyles.body(
                              fontSize: 12,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.scale_outlined, color: AppColors.secondary, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Limit: ${drone.maxPayload} kg',
                                style: AppTextStyles.body(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  drone.currentCoordinates.split(',').first,
                                  style: AppTextStyles.body(
                                    fontSize: 11,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
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
}
