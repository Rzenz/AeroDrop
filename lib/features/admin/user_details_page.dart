import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/status_chip.dart';

class UserDetailsPage extends ConsumerWidget {
  final String email;
  const UserDetailsPage({super.key, required this.email});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ponytail: mocked user details lookup by email
    final name = email.split('@').first.replaceAll('.', ' ');
    final displayName = name.split(' ').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join(' ');
    final isFaculty = email.contains('.edu') && !email.contains('student');
    final role = isFaculty ? 'Faculty/Staff' : 'Student';
    final dept = isFaculty ? 'Engineering & Technology' : 'Computer Studies Council';
    final initials = displayName.isNotEmpty 
        ? displayName.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'U';

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
                      'User Profile Details',
                      style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 32),

                // Main Info
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Avatar & Name Card
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: const BoxDecoration(
                                  gradient: AppColors.cyanGradient,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                displayName,
                                style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                email,
                                style: AppTextStyles.body(fontSize: 13, color: AppColors.textSecondaryDark),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  StatusChip(
                                    label: 'Active',
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 8),
                                  StatusChip(
                                    label: role.toUpperCase(),
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),
                        const SizedBox(height: 20),

                        // Details Card
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Organization Information',
                                style: AppTextStyles.title(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 16),
                              _buildDetailRow(Icons.business_rounded, 'Department', dept),
                              _buildDivider(),
                              _buildDetailRow(Icons.badge_outlined, 'Role ID', 'UCLM-2026-8849'),
                              _buildDivider(),
                              _buildDetailRow(Icons.phone_outlined, 'Contact Number', '+63 912 345 6789'),
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
                        const SizedBox(height: 20),

                        // Stats Card
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStat('24', 'Total Orders'),
                              _buildVerticalDivider(),
                              _buildStat('23', 'Completed'),
                              _buildVerticalDivider(),
                              _buildStat('1', 'Active Flight'),
                            ],
                          ),
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Bottom Buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomButton(
                      text: 'Edit User Roles & Status',
                      icon: Icons.edit_rounded,
                      onPressed: () => context.push('/admin/users/edit?email=$email'),
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: 'View Activity Logs',
                      icon: Icons.analytics_outlined,
                      gradient: const LinearGradient(colors: [AppColors.cardDark, AppColors.cardDark]),
                      onPressed: () => context.push('/admin/users/activity?email=$email'),
                    ),
                  ],
                ).animate().fadeIn(delay: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.secondary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark)),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.title(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: AppColors.borderDark.withValues(alpha: 0.5), height: 1),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.borderDark,
    );
  }
}
