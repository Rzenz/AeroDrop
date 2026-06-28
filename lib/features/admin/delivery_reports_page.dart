import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/glass_card.dart';

class DeliveryReportsPage extends StatefulWidget {
  const DeliveryReportsPage({super.key});

  @override
  State<DeliveryReportsPage> createState() => _DeliveryReportsPageState();
}

class _DeliveryReportsPageState extends State<DeliveryReportsPage> {
  String _selectedFormat = 'PDF Document (.pdf)';
  String _dateRange = 'Last 30 Days';
  bool _isExporting = false;

  void _export() async {
    setState(() => _isExporting = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isExporting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Delivery reports successfully saved to /Downloads/AeroDrop_Deliveries_$_dateRange.${_selectedFormat.contains('PDF') ? 'pdf' : 'csv'}!'),
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
                      'Delivery Analytics',
                      style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 36),

                // Form card
                Expanded(
                  child: SingleChildScrollView(
                    child: GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary, size: 48).animate().scale(),
                          const SizedBox(height: 16),
                          Text(
                            'Configure Dispatch Analytics Export',
                            style: AppTextStyles.title(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          
                          // Dropdowns
                          _buildLabel('Analysis Date Span'),
                          _buildDropdown(
                            value: _dateRange,
                            items: const ['Today', 'Last 7 Days', 'Last 30 Days', 'This Semester'],
                            onChanged: (val) => setState(() => _dateRange = val!),
                          ),
                          const SizedBox(height: 20),
                          _buildLabel('Document File Extension'),
                          _buildDropdown(
                            value: _selectedFormat,
                            items: const ['PDF Document (.pdf)', 'CSV Spreadsheet (.csv)'],
                            onChanged: (val) => setState(() => _selectedFormat = val!),
                          ),
                          const SizedBox(height: 24),

                          // Summary metrics preview
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardDark2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderDark),
                            ),
                            child: Column(
                              children: [
                                _buildSummaryRow('Est. Record Count', '842 dispatches'),
                                const SizedBox(height: 8),
                                _buildSummaryRow('Average Transit Duration', '6.8 mins'),
                                const SizedBox(height: 8),
                                _buildSummaryRow('Total Delivery Weight', '124.5 kg'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),
                ),

                // Export Button
                CustomButton(
                  text: 'Compile & Export Logs',
                  icon: Icons.download_for_offline_outlined,
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
