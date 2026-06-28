import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/glass_card.dart';

class DroneReportsPage extends StatefulWidget {
  const DroneReportsPage({super.key});

  @override
  State<DroneReportsPage> createState() => _DroneReportsPageState();
}

class _DroneReportsPageState extends State<DroneReportsPage> {
  String _selectedDrone = 'DRN-001 (AeroCarrier Falcon)';
  bool _isExporting = false;

  void _export() async {
    setState(() => _isExporting = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isExporting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Diagnostics logs for $_selectedDrone exported to /Downloads/AeroDrop_Fleet_Logs.csv'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
                      'Fleet Diagnostics',
                      style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 36),

                // Form details
                Expanded(
                  child: SingleChildScrollView(
                    child: GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.electric_bolt_rounded, color: AppColors.secondary, size: 48).animate().scale(),
                          const SizedBox(height: 16),
                          Text(
                            'Fleet Diagnostic Diagnostics Reports',
                            style: AppTextStyles.title(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),

                          _buildLabel('Hardware Asset'),
                          _buildDropdown(
                            value: _selectedDrone,
                            items: const [
                              'DRN-001 (AeroCarrier Falcon)',
                              'DRN-002 (SkyLifter Titan)',
                              'DRN-003 (AeroCarrier Hawk)',
                            ],
                            onChanged: (val) => setState(() => _selectedDrone = val!),
                          ),
                          const SizedBox(height: 24),

                          // Diagnostic Summary Preview
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardDark2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderDark),
                            ),
                            child: Column(
                              children: [
                                _buildSummaryRow('Total Battery Cycle count', '142 cycles'),
                                const SizedBox(height: 8),
                                _buildSummaryRow('Accumulated flight timing', '4,820 mins'),
                                const SizedBox(height: 8),
                                _buildSummaryRow('Uptime Percentage', '99.2%'),
                                const SizedBox(height: 8),
                                _buildSummaryRow('Offline / Outage Events', '3 incidents'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),
                ),

                // Button
                CustomButton(
                  text: 'Download Diagnostic csv logs',
                  icon: Icons.download_outlined,
                  isLoading: _isExporting,
                  onPressed: _export,
                ).animate().fadeIn(delay: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: AppTextStyles.body(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.cardDark,
          items: items.map((e) {
            return DropdownMenuItem(
              value: e,
              child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 13)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark)),
        Text(value, style: AppTextStyles.title(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}
