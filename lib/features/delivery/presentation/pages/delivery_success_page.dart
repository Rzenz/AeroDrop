import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/glass_card.dart';

class DeliverySuccessPage extends StatelessWidget {
  const DeliverySuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
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
                  style: AppTextStyles.title(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 12),
                Text(
                  'Your drone request has been received and scheduled for immediate dispatch.',
                  style: AppTextStyles.body(fontSize: 14, color: AppColors.textSecondaryDark),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 32),
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tracking ID', style: AppTextStyles.body(fontSize: 14, color: AppColors.textSecondaryDark)),
                      Text('DEL-948', style: AppTextStyles.title(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.08),
                const SizedBox(height: 48),
                CustomButton(
                  text: 'Track Live Flight',
                  onPressed: () => context.go('/user/track'),
                  icon: Icons.map_rounded,
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Return Home Deck',
                  gradient: const LinearGradient(colors: [Color(0xFF333333), Color(0xFF222222)]),
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
