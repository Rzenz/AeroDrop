import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';

class DeliveryCompletedPage extends StatefulWidget {
  const DeliveryCompletedPage({super.key});

  @override
  State<DeliveryCompletedPage> createState() => _DeliveryCompletedPageState();
}

class _DeliveryCompletedPageState extends State<DeliveryCompletedPage> {
  int _rating = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2B48), AppColors.bgDark, Color(0xFF070D14)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Glowing Success Circle
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.2),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 64,
                    ),
                  ),
                )
                .animate()
                .scale(curve: Curves.elasticOut, duration: 800.ms)
                .shimmer(delay: 800.ms, duration: 1500.ms, color: Colors.white24),

                const SizedBox(height: 40),

                // Success Message
                Text(
                  'Package Delivered Safely!',
                  style: AppTextStyles.display(
                    fontSize: 28,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),

                const SizedBox(height: 12),

                Text(
                  'Your drone has safely landed and released the payload at the designated platform.',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.textSecondaryDark,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0),

                const SizedBox(height: 48),

                // Rating Card
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  borderRadius: BorderRadius.circular(24),
                  borderGradient: const LinearGradient(
                    colors: [AppColors.success, Colors.transparent],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'RATE YOUR EXPERIENCE',
                        style: AppTextStyles.label(
                          fontSize: 11,
                          color: AppColors.textSecondaryDark,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starIndex = index + 1;
                          final isSelected = starIndex <= _rating;
                          return IconButton(
                            icon: Icon(
                              isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isSelected ? const Color(0xFFFFC107) : AppColors.textSecondaryDark,
                              size: 36,
                            ),
                            onPressed: () {
                              setState(() {
                                _rating = starIndex;
                              });
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(delay: 500.ms)
                .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

                const SizedBox(height: 48),

                // Back Home Button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: AppColors.accentGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.go('/user'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.home_rounded, color: AppColors.bgDark, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Return to Home',
                              style: AppTextStyles.title(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.bgDark,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: 650.ms),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
