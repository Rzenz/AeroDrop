import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/providers/auth_provider.dart';

class DeliveryRequestScreen extends ConsumerStatefulWidget {
  const DeliveryRequestScreen({super.key});

  @override
  ConsumerState<DeliveryRequestScreen> createState() =>
      _DeliveryRequestScreenState();
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
  String _paymentMethod = 'GCash';
  bool _loading = false;

  final _steps = ['Package', 'Location', 'Payment', 'Confirm'];

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

  bool _validateCurrentPage() {
    if (_currentPage == 0) {
      if (_weightController.text.trim().isEmpty) {
        _showValidationError('Package weight is required');
        return false;
      }
      final weight = double.tryParse(_weightController.text.trim());
      if (weight == null || weight <= 0) {
        _showValidationError('Please enter a valid weight greater than 0');
        return false;
      }
      if (_notesController.text.trim().isEmpty) {
        _showValidationError('Special instructions / notes are required');
        return false;
      }
    } else if (_currentPage == 1) {
      if (_pickupController.text.trim().isEmpty) {
        _showValidationError('Pickup location is required');
        return false;
      }
      if (_dropoffController.text.trim().isEmpty) {
        _showValidationError('Drop-off location is required');
        return false;
      }
      if (_recipientController.text.trim().isEmpty) {
        _showValidationError('Recipient name is required');
        return false;
      }
    }
    return true;
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _next() {
    if (!_validateCurrentPage()) return;
    if (_currentPage < 3) {
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
    if (_loading) return;
    final user = ref.read(authProvider).user;
    if (user == null) return;
    setState(() => _loading = true);

    ref.read(deliveryProvider.notifier).createDelivery(
          senderName: user.name,
          recipientName: _recipientController.text,
          recipientPhone: '+63 900 000 0000',
          deliveryAddress:
              'From ${_pickupController.text} to ${_dropoffController.text}',
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.go('/user/track');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: CustomAppBar(
        title: 'Make a Delivery',
        onBackPressed: _back,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F243A), AppColors.bgDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step Indicators / Progress bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_steps.length, (index) {
                        final isActive = index <= _currentPage;
                        final isCurrent = index == _currentPage;
                        return Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isActive ? AppColors.accentGradient : null,
                                color: isActive ? null : AppColors.cardDark,
                                border: Border.all(
                                  color: isActive ? AppColors.accent : AppColors.borderDark,
                                  width: 1.5,
                                ),
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: AppColors.accent.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: AppTextStyles.title(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? AppColors.bgDark : AppColors.textSecondaryDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _steps[index],
                              style: AppTextStyles.label(
                                fontSize: 9,
                                color: isCurrent ? Colors.white : AppColors.textSecondaryDark,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    // Progress line
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentPage + 1) / _steps.length,
                        backgroundColor: AppColors.borderDark,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.accent,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),

              // Step Page Views
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
                    _PaymentPage(
                      selectedMethod: _paymentMethod,
                      onMethodChanged: (v) =>
                          setState(() => _paymentMethod = v),
                    ),
                    _ConfirmPage(
                      pickup: _pickupController.text.isEmpty
                          ? 'UCLM Main Gate'
                          : _pickupController.text,
                      dropoff: _dropoffController.text.isEmpty
                          ? 'Engineering Block A'
                          : _dropoffController.text,
                      recipient: _recipientController.text.isEmpty
                          ? 'Self'
                          : _recipientController.text,
                      packageType: _packageType,
                      weight: _weightController.text,
                      paymentMethod: _paymentMethod,
                    ),
                  ],
                ),
              ),

              // Bottom Action button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: GradientButton(
                  text: _currentPage == 3 ? 'Confirm Order' : 'Continue',
                  isLoading: _loading,
                  onPressed: _next,
                  icon: _currentPage == 3
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Package Details',
            style: AppTextStyles.subHead(
              fontSize: 18,
              color: Colors.white,
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 16),
          DarkCard(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(24),
            borderGradient: const LinearGradient(
              colors: [Colors.white12, Colors.transparent],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SELECT ITEM TYPE',
                  style: AppTextStyles.label(
                    fontSize: 11,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: types.map((t) {
                    final sel = t == typeValue;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onTypeChanged(t);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: sel ? AppColors.accentGradient : null,
                          color: sel ? null : AppColors.bgDark,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color:
                                sel ? AppColors.accent : AppColors.borderDark,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          t,
                          style: AppTextStyles.title(
                            fontSize: 13,
                            fontWeight:
                                sel ? FontWeight.bold : FontWeight.normal,
                            color: sel
                                ? AppColors.bgDark
                                : AppColors.textSecondaryDark,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  labelText: 'Weight (kg)',
                  hintText: '1.0',
                  prefixIcon: Icons.scale_rounded,
                  controller: weightController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  labelText: 'Special Instructions',
                  hintText: 'e.g. Fragile, keep upright...',
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Delivery Locations',
            style: AppTextStyles.subHead(
              fontSize: 18,
              color: Colors.white,
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 16),
          DarkCard(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(24),
            borderGradient: const LinearGradient(
              colors: [Colors.white12, Colors.transparent],
            ),
            child: Column(
              children: [
                CustomTextField(
                  labelText: 'Pickup Location',
                  hintText: 'e.g. UCLM Main Gate',
                  prefixIcon: Icons.location_on_rounded,
                  controller: pickupController,
                ),
                // Route path connector line
                Row(
                  children: [
                    const SizedBox(width: 24),
                    Container(
                      width: 2,
                      height: 28,
                      color: AppColors.borderDark,
                    ),
                  ],
                ),
                CustomTextField(
                  labelText: 'Drop-off Location',
                  hintText: 'e.g. Engineering Block A',
                  prefixIcon: Icons.flag_rounded,
                  controller: dropoffController,
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  labelText: 'Recipient Name',
                  hintText: 'Name of person receiving',
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

class _PaymentPage extends StatelessWidget {
  final String selectedMethod;
  final ValueChanged<String> onMethodChanged;

  const _PaymentPage({
    required this.selectedMethod,
    required this.onMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final paymentOptions = [
      (
        name: 'GCash',
        icon: Icons.account_balance_wallet_rounded,
        subtitle: 'Instant mobile e-wallet transfer',
        color: AppColors.primaryLight
      ),
      (
        name: 'Cash',
        icon: Icons.payments_rounded,
        subtitle: 'Pay cash upon drone delivery arrival',
        color: AppColors.success
      ),
      (
        name: 'Credit / Debit Card',
        icon: Icons.credit_card_rounded,
        subtitle: 'Visa, Mastercard, or JCB cards',
        color: AppColors.accent
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Payment Method',
            style: AppTextStyles.subHead(
              fontSize: 18,
              color: Colors.white,
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 16),
          ...paymentOptions.map((opt) {
            final isSel = opt.name == selectedMethod;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onMethodChanged(opt.name);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSel
                      ? opt.color.withValues(alpha: 0.1)
                      : AppColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSel ? opt.color : AppColors.borderDark,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: opt.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(opt.icon, color: opt.color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.name,
                            style: AppTextStyles.title(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            opt.subtitle,
                            style: AppTextStyles.body(
                              fontSize: 11.5,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSel)
                      Icon(
                        Icons.check_circle_rounded,
                        color: opt.color,
                        size: 22,
                      ),
                  ],
                ),
              ),
            );
          }),
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
  final String paymentMethod;

  const _ConfirmPage({
    required this.pickup,
    required this.dropoff,
    required this.recipient,
    required this.packageType,
    required this.weight,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Confirm Details',
            style: AppTextStyles.subHead(
              fontSize: 18,
              color: Colors.white,
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 16),
          // Receipt Style Container
          GlassCard(
            padding: const EdgeInsets.all(24),
            borderRadius: BorderRadius.circular(24),
            borderGradient: const LinearGradient(
              colors: [AppColors.accent, AppColors.primary, Colors.transparent],
              stops: [0.0, 0.5, 1.0],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _confirmItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Package Type',
                  val: packageType,
                ),
                _confirmItem(
                  icon: Icons.scale_outlined,
                  label: 'Weight',
                  val: '$weight kg',
                ),
                _confirmItem(
                  icon: Icons.my_location_outlined,
                  label: 'Pickup',
                  val: pickup,
                ),
                _confirmItem(
                  icon: Icons.location_on_outlined,
                  label: 'Drop-off',
                  val: dropoff,
                ),
                _confirmItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Recipient',
                  val: recipient,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: AppColors.borderDark, height: 1),
                ),
                _confirmItem(
                  icon: Icons.payment_outlined,
                  label: 'Payment Method',
                  val: paymentMethod,
                  color: AppColors.accent,
                ),
              ],
            ),
          ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05),
        ],
      ),
    );
  }

  Widget _confirmItem({
    required IconData icon,
    required String label,
    required String val,
    Color color = Colors.white,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.textSecondaryDark,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 13.5,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              val,
              style: AppTextStyles.title(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
