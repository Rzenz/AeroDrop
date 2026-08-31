import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_back_button.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
                // Header
                Row(
                  children: [
                    const NeuBackButton(),
                    const SizedBox(width: 16),
                    Text(
                      'About AeroDrop',
                      style: AppTextStyles.title(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 36),

                // Info body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Large icon
                        ShaderMask(
                          shaderCallback: (b) =>
                              AppColors.primaryGradient.createShader(b),
                          child: Icon(
                            Icons.flight_takeoff_rounded,
                            size: 72,
                            color: AppColors.textPrimary,
                          ),
                        ).animate().scale(
                          duration: 500.ms,
                          curve: Curves.elasticOut,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'AeroDrop Campus Delivery',
                          style: AppTextStyles.title(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Version 1.0.0 (Build 2026.06.25)',
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),

                        // System description
                        NeuCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Autonomous Aerial Distribution',
                                style: AppTextStyles.title(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'AeroDrop is an official campus initiative designed for fast, contactless delivery of essential academic payloads, document sets, medical resources, and lab equipment across platforms at UCLM.',
                                style: AppTextStyles.body(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),
                        const SizedBox(height: 20),

                        // Hardware specifications
                        NeuCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'System Hardware Architecture',
                                style: AppTextStyles.title(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildHardwareRow(
                                'Flight Controller',
                                'Pixhawk 6X Autopilot Core',
                              ),
                              _buildHardwareRow(
                                'Telemetry Transceiver',
                                'UHF RFD900x Dual Antenna',
                              ),
                              _buildHardwareRow(
                                'Obstacle Sensing',
                                'Lidar 360° Laser Scan Grid',
                              ),
                              _buildHardwareRow(
                                'Airframe Chassis',
                                'Carbon Fiber AeroCarrier Quad-V3',
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05),
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

  Widget _buildHardwareRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, color: AppColors.secondary, size: 6),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.caption(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: AppTextStyles.subHead(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
