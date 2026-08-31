import 'package:flutter/material.dart';
import '../../../../core/widgets/neu_feedback.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/neu_button.dart';
import '../../../../core/widgets/neu_card.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/logout_helper.dart';

class AccountPendingPage extends ConsumerWidget {
  const AccountPendingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final businessName = user?.businessName ?? 'Your Application';
    final submittedDate = user?.createdAt != null
        ? '${user!.createdAt!.day}/${user.createdAt!.month}/${user.createdAt!.year}'
        : 'Unknown';

    return Scaffold(
      backgroundColor: AppColors.base,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.pending_actions_rounded,
                    color: AppColors.warning,
                    size: 48,
                  ),
                ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),
                const SizedBox(height: 32),
                Text(
                  'Application Under Review',
                  style: AppTextStyles.title(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 12),
                Text(
                  'Your vendor application is currently being reviewed by the campus flight team. You\'ll receive access once approved.',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 28),

                // Application summary card
                NeuCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.primaryLight,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Application Details',
                            style: AppTextStyles.subHead(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _Row(label: 'Business', value: businessName),
                      _Row(
                        label: 'Status',
                        value: 'Pending Review',
                        valueColor: AppColors.warning,
                      ),
                      _Row(label: 'Submitted', value: submittedDate),
                    ],
                  ),
                ).animate().fadeIn(delay: 250.ms),
                const SizedBox(height: 24),

                NeuCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    children: [
                      NeuButton(
                        text: 'Contact Administrator',
                        onPressed: () {
                          showNeuSnack(
                            context,
                            'Support request sent!',
                            tone: NeuToneKind.success,
                          );
                        },
                        icon: Icons.support_agent_rounded,
                      ),
                      const SizedBox(height: 12),
                      NeuButton(
                        text: 'Log Out',
                        variant: NeuButtonVariant.neutral,
                        onPressed: () => showLogoutConfirmation(context, ref),
                        icon: Icons.logout_rounded,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.08),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Row({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTextStyles.caption(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body(
                fontSize: 13,
                color: valueColor ?? Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
