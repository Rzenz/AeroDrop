import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/neu_button.dart';
import '../../../../core/widgets/neu_card.dart';
import '../../../../core/widgets/neu_back_button.dart';

class DeliverySummaryPage extends StatelessWidget {
  const DeliverySummaryPage({super.key});

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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const NeuBackButton(),
                    const SizedBox(width: 16),
                    Text(
                      'Delivery Summary',
                      style: AppTextStyles.title(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        NeuCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sender Details',
                                style: AppTextStyles.body(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _rowItem('Sender Name', 'John Doe'),
                              _rowItem('Contact Number', '+63 900 000 0000'),
                              _rowItem('Pickup Hub', 'Engineering Block A'),
                            ],
                          ),
                        ).animate().fadeIn(delay: 100.ms),
                        const SizedBox(height: 16),
                        NeuCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recipient Details',
                                style: AppTextStyles.body(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _rowItem('Recipient Name', 'Jane Smith'),
                              _rowItem('Contact Number', '+63 901 111 2222'),
                              _rowItem(
                                'Drop-off Location',
                                'Main Library Lobby',
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 16),
                        NeuCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Package Information',
                                style: AppTextStyles.body(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _rowItem('Category', 'Documents'),
                              _rowItem('Weight', '0.8 kg'),
                              _rowItem('Notes', 'Fragile printout envelopes'),
                            ],
                          ),
                        ).animate().fadeIn(delay: 300.ms),
                        const SizedBox(height: 16),
                        NeuCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cost Analysis',
                                style: AppTextStyles.body(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _rowItem('Base Delivery Fee', '₱45.00'),
                              _rowItem('Priority Dispatch', '₱15.00'),
                              Divider(color: AppColors.border, height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Fee',
                                    style: AppTextStyles.title(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '₱60.00',
                                    style: AppTextStyles.title(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: NeuButton(
                    text: 'Proceed to Checkout',
                    onPressed: () => context.go('/user/delivery/success'),
                    icon: Icons.payment_rounded,
                  ),
                ).animate().fadeIn(delay: 500.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.title(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
