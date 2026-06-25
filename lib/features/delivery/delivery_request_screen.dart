import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/providers/auth_provider.dart';

class DeliveryRequestScreen extends ConsumerStatefulWidget {
  const DeliveryRequestScreen({super.key});

  @override
  ConsumerState<DeliveryRequestScreen> createState() => _DeliveryRequestScreenState();
}

class _DeliveryRequestScreenState extends ConsumerState<DeliveryRequestScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _recipientController = TextEditingController();
  final _weightController = TextEditingController(text: '1.0');
  final _notesController = TextEditingController();
  String _packageType = 'Documents';
  bool _loading = false;

  final _steps = ['Package', 'Location', 'Confirm'];

  @override
  void dispose() {
    _pageController.dispose();
    _pickupController.dispose();
    _dropoffController.dispose();
    _recipientController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentPage++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentPage--);
    } else {
      context.pop();
    }
  }

  void _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    setState(() => _loading = true);

    ref.read(deliveryProvider.notifier).createDelivery(
          senderName: user.name,
          recipientName: _recipientController.text.isEmpty
              ? user.name
              : _recipientController.text,
          recipientPhone: '+63 900 000 0000',
          deliveryAddress: 'From ${_pickupController.text.isEmpty ? 'Main Gate' : _pickupController.text} to ${_dropoffController.text.isEmpty ? 'Eng. Block A' : _dropoffController.text}',
          packageName: 'AeroDrop $_packageType',
          packageWeight: double.tryParse(_weightController.text) ?? 1.0,
          packageType: _packageType,
        );

    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Delivery request submitted!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.go('/user/track');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _back,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('New Delivery Request',
                              style: AppTextStyles.title(
                                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text('Step ${_currentPage + 1} of 3 — ${_steps[_currentPage]}',
                              style: AppTextStyles.body(
                                  fontSize: 12, color: AppColors.textSecondaryDark)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Page indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: 3,
                  effect: ExpandingDotsEffect(
                    dotColor: AppColors.borderDark,
                    activeDotColor: AppColors.primary,
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 4,
                  ),
                ),
              ),

              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _PackagePage(
                      typeValue: _packageType,
                      onTypeChanged: (v) => setState(() => _packageType = v!),
                      weightController: _weightController,
                      notesController: _notesController,
                    ),
                    _LocationPage(
                      pickupController: _pickupController,
                      dropoffController: _dropoffController,
                      recipientController: _recipientController,
                    ),
                    _ConfirmPage(
                      pickup: _pickupController.text.isEmpty ? 'UCLM Main Gate' : _pickupController.text,
                      dropoff: _dropoffController.text.isEmpty ? 'Engineering Block A' : _dropoffController.text,
                      recipient: _recipientController.text.isEmpty ? 'Self' : _recipientController.text,
                      packageType: _packageType,
                      weight: _weightController.text,
                    ),
                  ],
                ),
              ),

              // Bottom action
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: CustomButton(
                  text: _currentPage == 2 ? 'Request Delivery' : 'Continue',
                  isLoading: _loading,
                  onPressed: _next,
                  icon: _currentPage == 2
                      ? Icons.flight_takeoff_rounded
                      : Icons.arrow_forward_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackagePage extends StatelessWidget {
  final String typeValue;
  final ValueChanged<String?> onTypeChanged;
  final TextEditingController weightController;
  final TextEditingController notesController;

  const _PackagePage({
    required this.typeValue,
    required this.onTypeChanged,
    required this.weightController,
    required this.notesController,
  });

  @override
  Widget build(BuildContext context) {
    final types = ['Documents', 'Medicine', 'Electronics', 'Food', 'Other'];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Package Details',
              style: AppTextStyles.title(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))
              .animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 20),
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Package Type',
                    style: AppTextStyles.body(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryDark)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: types.map((t) {
                    final sel = t == typeValue;
                    return GestureDetector(
                      onTap: () => onTypeChanged(t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: sel ? AppColors.primaryGradient : null,
                          color: sel ? null : AppColors.cardDark2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? AppColors.primary : AppColors.borderDark,
                          ),
                        ),
                        child: Text(t,
                            style: TextStyle(
                                color: sel ? Colors.white : AppColors.textSecondaryDark,
                                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  labelText: 'Weight (kg)',
                  hintText: '1.0',
                  prefixIcon: Icons.scale_rounded,
                  controller: weightController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  labelText: 'Special Instructions',
                  hintText: 'Fragile, keep upright...',
                  prefixIcon: Icons.notes_rounded,
                  controller: notesController,
                  maxLines: 3,
                ),
              ],
            ),
          ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05),
        ],
      ),
    );
  }
}

class _LocationPage extends StatelessWidget {
  final TextEditingController pickupController;
  final TextEditingController dropoffController;
  final TextEditingController recipientController;

  const _LocationPage({
    required this.pickupController,
    required this.dropoffController,
    required this.recipientController,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery Location',
              style: AppTextStyles.title(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))
              .animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 20),
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                CustomTextField(
                  labelText: 'Pickup Location',
                  hintText: 'e.g. UCLM Main Gate',
                  prefixIcon: Icons.location_on_rounded,
                  controller: pickupController,
                ),
                const SizedBox(height: 16),
                // Route line connector visual
                Row(
                  children: [
                    const SizedBox(width: 22),
                    Container(
                      width: 2,
                      height: 24,
                      decoration: const BoxDecoration(
                        gradient: AppColors.purpleCyanGradient,
                      ),
                    ),
                  ],
                ),
                CustomTextField(
                  labelText: 'Drop-off Location',
                  hintText: 'e.g. Engineering Block A',
                  prefixIcon: Icons.flag_rounded,
                  controller: dropoffController,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  labelText: 'Recipient Name',
                  hintText: 'Who receives this package?',
                  prefixIcon: Icons.person_rounded,
                  controller: recipientController,
                ),
              ],
            ),
          ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05),
        ],
      ),
    );
  }
}

class _ConfirmPage extends StatelessWidget {
  final String pickup;
  final String dropoff;
  final String recipient;
  final String packageType;
  final String weight;

  const _ConfirmPage({
    required this.pickup,
    required this.dropoff,
    required this.recipient,
    required this.packageType,
    required this.weight,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review & Confirm',
              style: AppTextStyles.title(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))
              .animate().fadeIn(),
          const SizedBox(height: 20),
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                _confirmRow(Icons.local_shipping_rounded, 'Type', packageType, AppColors.primary),
                _confirmRow(Icons.scale_rounded, 'Weight', '$weight kg', AppColors.secondary),
                _confirmRow(Icons.location_on_rounded, 'Pickup', pickup, AppColors.warning),
                _confirmRow(Icons.flag_rounded, 'Drop-off', dropoff, AppColors.success),
                _confirmRow(Icons.person_rounded, 'Recipient', recipient, AppColors.info),
              ],
            ),
          ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(16),
            gradient: LinearGradient(colors: [
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.secondary.withValues(alpha: 0.06),
            ]),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.secondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'An available drone will be auto-assigned once you submit.',
                    style: AppTextStyles.body(fontSize: 13, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ).animate(delay: 200.ms).fadeIn(),
        ],
      ),
    );
  }

  Widget _confirmRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 14),
          Text(label,
              style: AppTextStyles.body(fontSize: 13, color: AppColors.textSecondaryDark)),
          const Spacer(),
          Text(value,
              style: AppTextStyles.title(
                  fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}
