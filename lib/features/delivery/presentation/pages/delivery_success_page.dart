import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/neu_button.dart';
import '../../../../core/widgets/neu_card.dart';

class DeliverySuccessPage extends StatelessWidget {
  const DeliverySuccessPage({super.key});

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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Lottie.asset(
                    'assets/lottie/drone_fly.json',
                    repeat: true,
                  ),
                ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),
                const SizedBox(height: 32),
                Text(
                  'Order Placed Successfully!',
                  style: AppTextStyles.title(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 12),
                Text(
                  'Your drone request has been received and scheduled for immediate dispatch.',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 32),
                NeuCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tracking ID',
                        style: AppTextStyles.body(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'DEL-948',
                        style: AppTextStyles.title(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.08),
                const SizedBox(height: 48),
                NeuButton(
                  text: 'Track Live Flight',
                  onPressed: () => context.go('/user/track'),
                  icon: Icons.map_rounded,
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 16),
                NeuButton(
                  text: 'Return Home Deck',
                  variant: NeuButtonVariant.neutral,
                  onPressed: () => context.go('/user'),
                  icon: Icons.home_rounded,
                ).animate().fadeIn(delay: 500.ms),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
