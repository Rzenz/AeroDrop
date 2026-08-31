import 'package:flutter/material.dart';
import '../../core/widgets/neu_feedback.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_back_button.dart';

class NotificationDetailsPage extends StatelessWidget {
  final String notificationId;
  const NotificationDetailsPage({super.key, required this.notificationId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const NeuBackButton(),
                    const SizedBox(width: 16),
                    Text(
                      'Alert Center Log',
                      style: AppTextStyles.title(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        NeuCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.flight_takeoff_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'DISPATCH SYSTEM',
                                    style: AppTextStyles.title(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'AeroDrop Flight Dispatched',
                                style: AppTextStyles.title(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'June 25, 2026 at 10:12 PM',
                                style: AppTextStyles.body(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Divider(color: AppColors.border, height: 32),
                              Text(
                                'Your request DEL-892 has been scheduled for aerial dispatch. A quadcopter drone has been assigned and is currently carrying your payload to the destination. Please check the active tracking panel for updates.',
                                style: AppTextStyles.body(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ).copyWith(height: 1.6),
                              ),
                              const SizedBox(height: 28),
                              _metaItem(
                                Icons.inventory_2_rounded,
                                'Order Item',
                                'Microscope Slides & Samples',
                              ),
                              _metaItem(
                                Icons.confirmation_num_rounded,
                                'Order ID',
                                'DEL-892',
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 100.ms),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      NeuButton(
                        text: 'Mark Alert As Read',
                        onPressed: () {
                          showNeuSnack(
                            context,
                            'Notification marked as read!',
                            tone: NeuToneKind.success,
                          );
                          context.pop();
                        },
                        icon: Icons.check_rounded,
                      ),
                      const SizedBox(height: 12),
                      NeuButton(
                        text: 'Delete Alert Log',
                        variant: NeuButtonVariant.danger,
                        onPressed: () {
                          showNeuSnack(
                            context,
                            'Notification deleted!',
                            tone: NeuToneKind.error,
                          );
                          context.pop();
                        },
                        icon: Icons.delete_outline_rounded,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 16),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.title(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
