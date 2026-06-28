import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Analytical Reports',
                      style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 36),

                // Subtitle info
                Text(
                  'Select report module to view telemetry audits, client exports, and delivery histories.',
                  style: AppTextStyles.body(fontSize: 13, color: AppColors.textSecondaryDark),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 24),

                // Report selection tiles
                Expanded(
                  child: ListView(
                    children: [
                      _buildReportCategoryCard(
                        context: context,
                        title: 'Delivery History & Dispatch Logs',
                        desc: 'Export logs of campus delivery requests, payloads, delivery timings, and success rates.',
                        icon: Icons.inventory_2_outlined,
                        color: AppColors.primary,
                        routePath: '/admin/reports/deliveries',
                        delay: 150,
                      ),
                      _buildReportCategoryCard(
                        context: context,
                        title: 'Drone Diagnostics & Fleet Health',
                        desc: 'Detailed telemetry logs, battery cycle decay metrics, status uptimes, and maintenance schedules.',
                        icon: Icons.electric_bolt_rounded,
                        color: AppColors.secondary,
                        routePath: '/admin/reports/drones',
                        delay: 220,
                      ),
                      _buildReportCategoryCard(
                        context: context,
                        title: 'User Activity & Access Audits',
                        desc: 'Review faculty vs student transaction volume, system log actions, and sign-in credentials.',
                        icon: Icons.supervised_user_circle_outlined,
                        color: AppColors.warning,
                        routePath: '/admin/reports/users',
                        delay: 290,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportCategoryCard({
    required BuildContext context,
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required String routePath,
    required int delay,
  }) {
    return GestureDetector(
      onTap: () => context.push(routePath),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.title(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondaryDark, size: 14),
            ],
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: delay)).fadeIn().slideY(begin: 0.05);
  }
}
