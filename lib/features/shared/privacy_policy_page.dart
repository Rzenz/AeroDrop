import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
                      'Privacy Policy',
                      style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 36),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('1. Information Collection'),
                          _buildSectionText(
                            'AeroDrop collects basic user account profile details (Name, Email, and Department) and location specifications during flight dispatch requests. Live telemetry and flight coordinate parameters are audited solely for campus airspace coordination.'
                          ),
                          const SizedBox(height: 20),
                          _buildSectionTitle('2. Use of Information'),
                          _buildSectionText(
                            'The collected specifications are utilized strictly to orchestrate automated drone dispatches, ensure proper package delivery to platforms, audit operator access roles, and prevent unauthorized airspace access.'
                          ),
                          const SizedBox(height: 20),
                          _buildSectionTitle('3. Airspace Safety & Security'),
                          _buildSectionText(
                            'We do not share any user metrics or coordinates with external third-party agencies. All flight logs and payload histories are stored locally inside UCLM secure servers and are subjected to role-based access restrictions.'
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: AppTextStyles.title(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary),
      ),
    );
  }

  Widget _buildSectionText(String text) {
    return Text(
      text,
      style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark).copyWith(height: 1.5),
    );
  }
}
