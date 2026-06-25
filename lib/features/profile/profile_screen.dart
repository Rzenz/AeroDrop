import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/delivery_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final deliveries = ref.watch(deliveryProvider);
    final name = user?.name ?? 'User';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Gradient header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  24, MediaQuery.of(context).padding.top + 24, 24, 36),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppColors.purpleCyanGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ).animate().scale(curve: Curves.elasticOut, duration: 500.ms),
                  const SizedBox(height: 12),
                  Text(name,
                      style: AppTextStyles.title(
                          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))
                      .animate().fadeIn(delay: 150.ms),
                  Text(email,
                      style: AppTextStyles.body(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7)))
                      .animate().fadeIn(delay: 250.ms),
                ],
              ),
            ),

            // Stats row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  _StatBox('${deliveries.length}', 'Deliveries', AppColors.primary),
                  const SizedBox(width: 12),
                  _StatBox(
                    '${deliveries.where((d) => d.status.name == 'delivered').length}',
                    'Completed',
                    AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  _StatBox('4.9', 'Rating', AppColors.warning),
                ],
              ).animate().fadeIn(delay: 300.ms),
            ),

            const SizedBox(height: 24),

            // Menu tiles
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.edit_rounded,
                    label: 'Edit Profile',
                    color: AppColors.primary,
                    onTap: () => context.push('/user/profile/edit'),
                  ).animate(delay: 350.ms).fadeIn().slideX(begin: 0.04),
                  _MenuTile(
                    icon: Icons.notifications_rounded,
                    label: 'Notifications',
                    color: AppColors.secondary,
                    onTap: () => context.go('/user/notifications'),
                  ).animate(delay: 420.ms).fadeIn().slideX(begin: 0.04),
                  _MenuTile(
                    icon: Icons.history_rounded,
                    label: 'Delivery History',
                    color: AppColors.success,
                    onTap: () => context.go('/user/history'),
                  ).animate(delay: 490.ms).fadeIn().slideX(begin: 0.04),
                  _MenuTile(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    color: AppColors.warning,
                    onTap: () {},
                  ).animate(delay: 560.ms).fadeIn().slideX(begin: 0.04),
                  const SizedBox(height: 12),
                  _MenuTile(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    color: AppColors.danger,
                    trailing: false,
                    onTap: () {
                      ref.read(authProvider.notifier).logout();
                      context.go('/login');
                    },
                  ).animate(delay: 630.ms).fadeIn().slideX(begin: 0.04),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatBox(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: AppTextStyles.title(
                    fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark)),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool trailing;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.trailing = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: AppTextStyles.title(
                    fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            if (trailing) ...[
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondaryDark, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
