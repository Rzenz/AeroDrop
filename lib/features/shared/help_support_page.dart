import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> faqs = [
      {
        'q': 'How do I request a delivery?',
        'a': 'Navigate to your Dashboard and tap the "+" FAB button or "Request Delivery". Input the recipient details, select the target building landing pad, pick your payment choice, and review before confirming checkout.'
      },
      {
        'q': 'What payloads can be delivered?',
        'a': 'We support academic documents, books, laboratory samples, medical aid kits, and electronics up to a maximum chassis weight limit of 5.0 kg.'
      },
      {
        'q': 'What happens in severe weather?',
        'a': 'The fleet system automatically halts and queues dispatches if wind speeds exceed 15 knots or during heavy rain precipitation.'
      },
    ];

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
                      'Help & Campus Support',
                      style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 36),

                // FAQs
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Frequently Asked Questions',
                          style: AppTextStyles.title(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        ...faqs.asMap().entries.map((e) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.value['q']!,
                                    style: AppTextStyles.title(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    e.value['a']!,
                                    style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark),
                                  ),
                                ],
                              ),
                            ),
                          ).animate(delay: Duration(milliseconds: 100 + e.key * 80)).fadeIn().slideY(begin: 0.05);
                        }),
                        const SizedBox(height: 24),

                        // Contact info
                        Text(
                          'Direct Contacts',
                          style: AppTextStyles.title(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildContactRow(Icons.mail_outline_rounded, 'fleet-support@uclm.edu'),
                              const Divider(color: AppColors.borderDark, height: 24),
                              _buildContactRow(Icons.phone_outlined, 'Local Campus Tel: +63 32 400 9011'),
                            ],
                          ),
                        ).animate(delay: 400.ms).fadeIn(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }
}
