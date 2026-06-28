import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

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
                      'Terms & Conditions',
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
                          _buildSectionTitle('1. Payload Responsibilities'),
                          _buildSectionText(
                            'Users are solely responsible for verifying that their delivery items do not exceed the 5.0 kg maximum weight threshold and are non-hazardous, dry, and securely sealed before handing them to the drone deck loader.'
                          ),
                          const SizedBox(height: 20),
                          _buildSectionTitle('2. Automated Flight Paths'),
                          _buildSectionText(
                            'Flights are controlled by autonomous autopilot firmware following safe campus corridors. Users must not interfere with flight corridors, geofenced areas, or attempt unauthorized remote commands.'
                          ),
                          const SizedBox(height: 20),
                          _buildSectionTitle('3. Liability and Accidents'),
                          _buildSectionText(
                            'UCLM and the drone fleet logistics team hold final authority for flight overrides. In the event of emergency landing, payload recovery will be handled by the nearest designated fleet support ground crew.'
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
