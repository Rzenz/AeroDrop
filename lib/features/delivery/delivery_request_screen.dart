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
import '../../core/services/supabase_service.dart';

class CampusLocation {
  final String id;
  final String name;
  final String type;
  final String? building;
  final double latitude;
  final double longitude;

  CampusLocation({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.building,
  });

  factory CampusLocation.fromMap(Map<String, dynamic> map) {
    return CampusLocation(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      building: map['building']?.toString(),
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

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
  String _priority = 'Standard';

  DateTime? _scheduledAt;
  bool _loading = false;
  bool _locationsLoading = false;

  List<CampusLocation> _pickupLocations = [];
  List<CampusLocation> _dropoffLocations = [];

  CampusLocation? _selectedPickup;
  CampusLocation? _selectedDropoff;

  final _steps = ['Package', 'Location', 'Payment', 'Confirm'];

  @override
  void initState() {
    super.initState();
    _loadCampusLocations();
  }

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

  Future<void> _loadCampusLocations() async {
    if (!SupabaseService.isConfigured) return;

    setState(() => _locationsLoading = true);

    try {
      final response = await SupabaseService.client
          .from('campus_locations')
          .select()
          .eq('is_active', true)
          .order('name');

      final locations = (response as List)
          .map(
            (item) => CampusLocation.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      final pickups = locations
          .where(
            (location) =>
                location.type == 'launch_pad' || location.type == 'both',
          )
          .toList();

      final dropoffs = locations
          .where(
            (location) =>
                location.type == 'dropoff_platform' ||
                location.type == 'both',
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _pickupLocations = pickups;
        _dropoffLocations = dropoffs;
      });
    } catch (error) {
      print('Campus locations load failed: $error');
    } finally {
      if (mounted) {
        setState(() => _locationsLoading = false);
      }
    }
  }

  double _calculatePaymentAmount() {
    final weight = double.tryParse(_weightController.text.trim()) ?? 1.0;

    const baseFee = 50.0;
    final weightFee = weight * 10.0;

    double priorityFee = 0.0;

    if (_priority == 'Express') {
      priorityFee = 25.0;
    } else if (_priority == 'Scheduled') {
      priorityFee = 10.0;
    }

    return baseFee + weightFee + priorityFee;
  }

  String _formatPeso(double value) {
    if (value == value.roundToDouble()) {
      return '₱${value.toStringAsFixed(0)}';
    }

    return '₱${value.toStringAsFixed(2)}';
  }

  String _formatSchedule(DateTime? value) {
    if (value == null) return 'Not selected';

    final hour = value.hour > 12
        ? value.hour - 12
        : value.hour == 0
            ? 12
            : value.hour;

    final minute = value.minute.toString().padLeft(2, '0');
    final amPm = value.hour >= 12 ? 'PM' : 'AM';

    return '${value.month}/${value.day}/${value.year} • $hour:$minute $amPm';
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark(),
          child: child!,
        );
      },
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark(),
          child: child!,
        );
      },
    );

    if (time == null) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
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

      if (_priority == 'Scheduled' && _scheduledAt == null) {
        _showValidationError('Please select a scheduled date and time');
        return false;
      }

      if (_notesController.text.trim().isEmpty) {
        _showValidationError('Special instructions / notes are required');
        return false;
      }
    } else if (_currentPage == 1) {
      final hasDbLocations =
          _pickupLocations.isNotEmpty && _dropoffLocations.isNotEmpty;

      if (hasDbLocations) {
        if (_selectedPickup == null) {
          _showValidationError('Pickup launch pad is required');
          return false;
        }

        if (_selectedDropoff == null) {
          _showValidationError('Drop-off platform is required');
          return false;
        }
      } else {
        if (_pickupController.text.trim().isEmpty) {
          _showValidationError('Pickup location is required');
          return false;
        }

        if (_dropoffController.text.trim().isEmpty) {
          _showValidationError('Drop-off location is required');
          return false;
        }
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

  void _showMessage(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.danger,
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

  Future<void> _submit() async {
    if (_loading) return;

    final user = ref.read(authProvider).user;

    if (user == null) {
      _showMessage('You must be logged in to request a delivery.', false);
      return;
    }

    final weight = double.tryParse(_weightController.text.trim()) ?? 1.0;

    final pickupName = _selectedPickup?.name ?? _pickupController.text.trim();
    final dropoffName = _selectedDropoff?.name ?? _dropoffController.text.trim();

    setState(() => _loading = true);

    final error = await ref.read(deliveryProvider.notifier).createDelivery(
          senderName: user.name,
          recipientName: _recipientController.text.trim(),
          recipientPhone: '+63 900 000 0000',
          deliveryAddress: 'From $pickupName to $dropoffName',
          packageName: 'AeroDrop $_packageType',
          packageWeight: weight,
          packageType: _packageType,
          priority: _priority,
          paymentMethod: _paymentMethod,
          pickupLocationId: _selectedPickup?.id,
          dropoffLocationId: _selectedDropoff?.id,
          scheduledAt: _priority == 'Scheduled' ? _scheduledAt : null,
          pickupLatitude: _selectedPickup?.latitude,
          pickupLongitude: _selectedPickup?.longitude,
          dropoffLatitude: _selectedDropoff?.latitude,
          dropoffLongitude: _selectedDropoff?.longitude,
        );

    if (!mounted) return;

    setState(() => _loading = false);

    if (error != null) {
      _showMessage(error, false);
      return;
    }

    _showMessage('Delivery request submitted!', true);
    context.go('/user/track');
  }

  @override
  Widget build(BuildContext context) {
    final pickupText = _selectedPickup?.name ?? _pickupController.text.trim();
    final dropoffText = _selectedDropoff?.name ?? _dropoffController.text.trim();
    final paymentAmount = _calculatePaymentAmount();

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
                                gradient:
                                    isActive ? AppColors.accentGradient : null,
                                color: isActive ? null : AppColors.cardDark,
                                border: Border.all(
                                  color: isActive
                                      ? AppColors.accent
                                      : AppColors.borderDark,
                                  width: 1.5,
                                ),
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: AppColors.accent.withValues(
                                            alpha: 0.25,
                                          ),
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
                                  color: isActive
                                      ? AppColors.bgDark
                                      : AppColors.textSecondaryDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _steps[index],
                              style: AppTextStyles.label(
                                fontSize: 9,
                                color: isCurrent
                                    ? Colors.white
                                    : AppColors.textSecondaryDark,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
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
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _PackagePage(
                      typeValue: _packageType,
                      onTypeChanged: (v) {
                        if (v == null) return;
                        setState(() => _packageType = v);
                      },
                      priorityValue: _priority,
                      onPriorityChanged: (v) {
                        setState(() {
                          _priority = v;
                          if (_priority != 'Scheduled') {
                            _scheduledAt = null;
                          }
                        });
                      },
                      scheduledText: _formatSchedule(_scheduledAt),
                      onPickSchedule: _pickSchedule,
                      weightController: _weightController,
                      notesController: _notesController,
                    ),
                    _LocationPage(
                      pickupController: _pickupController,
                      dropoffController: _dropoffController,
                      recipientController: _recipientController,
                      pickupLocations: _pickupLocations,
                      dropoffLocations: _dropoffLocations,
                      selectedPickup: _selectedPickup,
                      selectedDropoff: _selectedDropoff,
                      loadingLocations: _locationsLoading,
                      onPickupChanged: (location) {
                        setState(() => _selectedPickup = location);
                      },
                      onDropoffChanged: (location) {
                        setState(() => _selectedDropoff = location);
                      },
                    ),
                    _PaymentPage(
                      selectedMethod: _paymentMethod,
                      amountText: _formatPeso(paymentAmount),
                      onMethodChanged: (v) {
                        setState(() => _paymentMethod = v);
                      },
                    ),
                    _ConfirmPage(
                      pickup:
                          pickupText.isEmpty ? 'No pickup selected' : pickupText,
                      dropoff: dropoffText.isEmpty
                          ? 'No drop-off selected'
                          : dropoffText,
                      recipient: _recipientController.text.isEmpty
                          ? 'Self'
                          : _recipientController.text,
                      packageType: _packageType,
                      weight: _weightController.text,
                      paymentMethod: _paymentMethod,
                      paymentAmount: _formatPeso(paymentAmount),
                      priority: _priority,
                      scheduledText: _priority == 'Scheduled'
                          ? _formatSchedule(_scheduledAt)
                          : 'Not scheduled',
                    ),
                  ],
                ),
              ),
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
  final String priorityValue;
  final ValueChanged<String> onPriorityChanged;
  final String scheduledText;
  final VoidCallback onPickSchedule;
  final TextEditingController weightController;
  final TextEditingController notesController;

  const _PackagePage({
    required this.typeValue,
    required this.onTypeChanged,
    required this.priorityValue,
    required this.onPriorityChanged,
    required this.scheduledText,
    required this.onPickSchedule,
    required this.weightController,
    required this.notesController,
  });

  @override
  Widget build(BuildContext context) {
    final types = ['Documents', 'Medicine', 'Electronics', 'Food', 'Other'];
    final priorities = ['Standard', 'Express', 'Scheduled'];

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
                  children: types.map((type) {
                    final selected = type == typeValue;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onTypeChanged(type);
                      },
                      child: _ChoiceChip(
                        label: type,
                        selected: selected,
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
                const SizedBox(height: 24),
                Text(
                  'DELIVERY PRIORITY',
                  style: AppTextStyles.label(
                    fontSize: 11,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: priorities.map((priority) {
                    final selected = priority == priorityValue;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onPriorityChanged(priority);
                      },
                      child: _ChoiceChip(
                        label: priority,
                        selected: selected,
                      ),
                    );
                  }).toList(),
                ),
                if (priorityValue == 'Scheduled') ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: onPickSchedule,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_rounded,
                            color: AppColors.accent,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              scheduledText,
                              style: AppTextStyles.body(
                                fontSize: 13.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.edit_calendar_rounded,
                            color: AppColors.textSecondaryDark,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
  final List<CampusLocation> pickupLocations;
  final List<CampusLocation> dropoffLocations;
  final CampusLocation? selectedPickup;
  final CampusLocation? selectedDropoff;
  final bool loadingLocations;
  final ValueChanged<CampusLocation?> onPickupChanged;
  final ValueChanged<CampusLocation?> onDropoffChanged;

  const _LocationPage({
    required this.pickupController,
    required this.dropoffController,
    required this.recipientController,
    required this.pickupLocations,
    required this.dropoffLocations,
    required this.selectedPickup,
    required this.selectedDropoff,
    required this.loadingLocations,
    required this.onPickupChanged,
    required this.onDropoffChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasDbLocations =
        pickupLocations.isNotEmpty && dropoffLocations.isNotEmpty;

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
                if (loadingLocations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Loading campus locations...',
                          style: AppTextStyles.body(
                            fontSize: 13,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (hasDbLocations) ...[
                  _LocationDropdown(
                    label: 'Pickup Launch Pad',
                    hint: 'Select pickup launch pad',
                    icon: Icons.flight_takeoff_rounded,
                    value: selectedPickup,
                    items: pickupLocations,
                    onChanged: onPickupChanged,
                  ),
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
                  _LocationDropdown(
                    label: 'Drop-off Platform',
                    hint: 'Select drop-off platform',
                    icon: Icons.flag_rounded,
                    value: selectedDropoff,
                    items: dropoffLocations,
                    onChanged: onDropoffChanged,
                  ),
                ] else ...[
                  CustomTextField(
                    labelText: 'Pickup Location',
                    hintText: 'e.g. UCLM Main Gate',
                    prefixIcon: Icons.location_on_rounded,
                    controller: pickupController,
                  ),
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
                ],
                const SizedBox(height: 20),
                CustomTextField(
                  labelText: 'Recipient Name',
                  hintText: 'Name of person receiving',
                  prefixIcon: Icons.person_rounded,
                  controller: recipientController,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bgDark.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: AppColors.accent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Route safety, drone capacity, and weather checks will run before dispatch.',
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
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
  final String amountText;
  final ValueChanged<String> onMethodChanged;

  const _PaymentPage({
    required this.selectedMethod,
    required this.amountText,
    required this.onMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final paymentOptions = [
      (
        name: 'GCash',
        icon: Icons.account_balance_wallet_rounded,
        subtitle: 'Simulated e-wallet payment',
        color: AppColors.primaryLight
      ),
      (
        name: 'Cash',
        icon: Icons.payments_rounded,
        subtitle: 'Pending until package arrival',
        color: AppColors.success
      ),
      (
        name: 'Credit / Debit Card',
        icon: Icons.credit_card_rounded,
        subtitle: 'Simulated card payment',
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
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Estimated Delivery Fee',
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ),
                Text(
                  amountText,
                  style: AppTextStyles.title(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          ...paymentOptions.map((option) {
            final isSelected = option.name == selectedMethod;

            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onMethodChanged(option.name);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? option.color.withValues(alpha: 0.1)
                      : AppColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? option.color : AppColors.borderDark,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: option.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        option.icon,
                        color: option.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.name,
                            style: AppTextStyles.title(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            option.subtitle,
                            style: AppTextStyles.body(
                              fontSize: 11.5,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: option.color,
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
  final String paymentAmount;
  final String priority;
  final String scheduledText;

  const _ConfirmPage({
    required this.pickup,
    required this.dropoff,
    required this.recipient,
    required this.packageType,
    required this.weight,
    required this.paymentMethod,
    required this.paymentAmount,
    required this.priority,
    required this.scheduledText,
  });

  @override
  Widget build(BuildContext context) {
    final paymentStatus =
        paymentMethod == 'Cash' ? 'Pending on delivery' : 'Simulated paid';

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
                  value: packageType,
                ),
                _confirmItem(
                  icon: Icons.scale_outlined,
                  label: 'Weight',
                  value: '$weight kg',
                ),
                _confirmItem(
                  icon: Icons.speed_rounded,
                  label: 'Priority',
                  value: priority,
                  color: AppColors.accent,
                ),
                if (priority == 'Scheduled')
                  _confirmItem(
                    icon: Icons.event_rounded,
                    label: 'Schedule',
                    value: scheduledText,
                    color: AppColors.accent,
                  ),
                _confirmItem(
                  icon: Icons.my_location_outlined,
                  label: 'Pickup',
                  value: pickup,
                ),
                _confirmItem(
                  icon: Icons.location_on_outlined,
                  label: 'Drop-off',
                  value: dropoff,
                ),
                _confirmItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Recipient',
                  value: recipient,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: AppColors.borderDark, height: 1),
                ),
                _confirmItem(
                  icon: Icons.payment_outlined,
                  label: 'Payment Method',
                  value: paymentMethod,
                  color: AppColors.accent,
                ),
                _confirmItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Amount',
                  value: paymentAmount,
                  color: AppColors.accent,
                ),
                _confirmItem(
                  icon: Icons.verified_rounded,
                  label: 'Payment Status',
                  value: paymentStatus,
                  color: paymentMethod == 'Cash'
                      ? AppColors.success
                      : AppColors.accent,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: AppColors.borderDark, height: 1),
                ),
                _confirmItem(
                  icon: Icons.verified_user_outlined,
                  label: 'Safety Check',
                  value: 'Runs on submit',
                  color: AppColors.success,
                ),
                _confirmItem(
                  icon: Icons.flight_rounded,
                  label: 'Drone Assignment',
                  value: 'Auto assigned',
                  color: AppColors.success,
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
    required String value,
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
              value,
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

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _ChoiceChip({
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: selected ? AppColors.accentGradient : null,
        color: selected ? null : AppColors.bgDark,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.borderDark,
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.title(
          fontSize: 13,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? AppColors.bgDark : AppColors.textSecondaryDark,
        ),
      ),
    );
  }
}

class _LocationDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final CampusLocation? value;
  final List<CampusLocation> items;
  final ValueChanged<CampusLocation?> onChanged;

  const _LocationDropdown({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<CampusLocation>(
      value: value,
      isExpanded: true,
      dropdownColor: AppColors.cardDark,
      iconEnabledColor: AppColors.textSecondaryDark,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.label(
          fontSize: 12,
          color: AppColors.textSecondaryDark,
        ),
        prefixIcon: Icon(
          icon,
          color: AppColors.textSecondaryDark,
          size: 20,
        ),
        filled: true,
        fillColor: AppColors.bgDark,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      hint: Text(
        hint,
        style: AppTextStyles.body(
          fontSize: 13,
          color: AppColors.textSecondaryDark,
        ),
      ),
      items: items.map((location) {
        return DropdownMenuItem<CampusLocation>(
          value: location,
          child: Text(
            location.building == null || location.building!.isEmpty
                ? location.name
                : '${location.name} • ${location.building}',
            style: AppTextStyles.body(
              fontSize: 13.5,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}