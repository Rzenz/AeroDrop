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
import '../../core/providers/drone_provider.dart';

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
  final _weightController = TextEditingController(text: '0.0');
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

      final pickups = locations;
      final dropoffs = locations;

      if (!mounted) return;

      setState(() {
        _pickupLocations = pickups;
        _dropoffLocations = dropoffs;
      });
    } catch (error) {
      debugPrint('Campus locations load failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Campus locations failed to load. Please try again.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _locationsLoading = false);
      }
    }
  }

  double _calculatePaymentAmount() {
    if (_selectedPickup == null || _selectedDropoff == null) return 20.0;

    double distance = 0.0;
    try {
      distance = _getEstimatedDistanceKm(_selectedPickup!.id, _selectedDropoff!.id);
    } catch (_) {
      distance = 0.05;
    }

    final weight = double.tryParse(_weightController.text.trim()) ?? 0.0;

    final baseFee = 20.0;
    final distanceFee = distance * 100.0;
    final weightFee = weight * 20.0;

    double itemFee = 5.0;
    switch (_packageType) {
      case 'Documents':
        itemFee = 0.0;
        break;
      case 'Medicine':
      case 'Food':
      case 'Other':
        itemFee = 5.0;
        break;
      case 'Electronics':
        itemFee = 10.0;
        break;
    }

    double priorityFee = 0.0;
    switch (_priority) {
      case 'Standard':
        priorityFee = 0.0;
        break;
      case 'Express':
        priorityFee = 10.0;
        break;
      case 'Scheduled':
        priorityFee = 5.0;
        break;
    }

    return baseFee + distanceFee + weightFee + itemFee + priorityFee;
  }

  double _getEstimatedDistanceKm(String pickupId, String dropoffId) {
    final pId = pickupId.toUpperCase();
    final dId = dropoffId.toUpperCase();

    if (pId == dId) {
      return 0.0;
    }

    final key = pId.compareTo(dId) < 0 ? '${pId}_$dId' : '${dId}_$pId';

    switch (key) {
      case 'OLD_MAIN_ANNEX_1':
      case 'ANNEX_1_OLD_MAIN':
        return 0.04;
      case 'OLD_MAIN_ANNEX_2':
      case 'ANNEX_2_OLD_MAIN':
        return 0.075;
      case 'OLD_MAIN_BASIC_ED':
      case 'BASIC_ED_OLD_MAIN':
        return 0.10;
      case 'OLD_MAIN_MARITIME':
      case 'MARITIME_OLD_MAIN':
        return 0.125;
      case 'ANNEX_1_ANNEX_2':
      case 'ANNEX_2_ANNEX_1':
        return 0.035;
      case 'ANNEX_1_BASIC_ED':
      case 'BASIC_ED_ANNEX_1':
        return 0.08;
      case 'ANNEX_1_MARITIME':
      case 'MARITIME_ANNEX_1':
        return 0.105;
      case 'ANNEX_2_BASIC_ED':
      case 'BASIC_ED_ANNEX_2':
        return 0.06;
      case 'ANNEX_2_MARITIME':
      case 'MARITIME_ANNEX_2':
        return 0.085;
      case 'BASIC_ED_MARITIME':
      case 'MARITIME_BASIC_ED':
        return 0.07;
      default:
        final pNorm = _normalizeLocId(pId);
        final dNorm = _normalizeLocId(dId);
        if (pNorm == dNorm) {
          return 0.0;
        }
        final normKey = pNorm.compareTo(dNorm) < 0 ? '${pNorm}_$dNorm' : '${dNorm}_$pNorm';
        switch (normKey) {
          case 'OLD_MAIN_ANNEX_1': return 0.04;
          case 'OLD_MAIN_ANNEX_2': return 0.075;
          case 'OLD_MAIN_BASIC_ED': return 0.10;
          case 'OLD_MAIN_MARITIME': return 0.125;
          case 'ANNEX_1_ANNEX_2': return 0.035;
          case 'ANNEX_1_BASIC_ED': return 0.08;
          case 'ANNEX_1_MARITIME': return 0.105;
          case 'ANNEX_2_BASIC_ED': return 0.06;
          case 'ANNEX_2_MARITIME': return 0.085;
          case 'BASIC_ED_MARITIME': return 0.07;
        }
        return 0.05;
    }
  }

  String _normalizeLocId(String id) {
    final raw = id.toUpperCase();
    if (raw.contains('OLD') || raw.contains('MAIN')) return 'OLD_MAIN';
    if (raw.contains('ANNEX_1') || raw.contains('ANNEX1')) return 'ANNEX_1';
    if (raw.contains('ANNEX_2') || raw.contains('ANNEX2')) return 'ANNEX_2';
    if (raw.contains('BASIC') || raw.contains('ED')) return 'BASIC_ED';
    if (raw.contains('MARITIME')) return 'MARITIME';
    return raw;
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

      if (weight > 0.5) {
        _showValidationError('Package is too heavy. Maximum supported drone payload is 0.5 kg.');
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
      if (_selectedPickup == null) {
        _showValidationError('Pickup launch pad is required');
        return false;
      }

      if (_selectedDropoff == null) {
        _showValidationError('Drop-off platform is required');
        return false;
      }

      if (_selectedPickup!.id == _selectedDropoff!.id) {
        _showValidationError('Pickup and drop-off location cannot be the same.');
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

    final weight = double.tryParse(_weightController.text.trim()) ?? 0.0;

    if (weight <= 0) {
      _showMessage('Please enter a valid weight.', false);
      return;
    }

    if (weight > 0.5) {
      _showMessage('Package is too heavy. Maximum supported drone payload is 0.5 kg.', false);
      return;
    }

    if (_selectedPickup == null || _selectedDropoff == null) {
      _showMessage('Pickup and drop-off locations are required.', false);
      return;
    }

    if (_selectedPickup!.id == _selectedDropoff!.id) {
      _showMessage('Pickup and drop-off location cannot be the same.', false);
      return;
    }

    final pickupName = _selectedPickup!.name;
    final dropoffName = _selectedDropoff!.name;
    double distance = 0.0;
    try {
      distance = _getEstimatedDistanceKm(_selectedPickup!.id, _selectedDropoff!.id);
    } catch (_) {
      distance = 0.05;
    }

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
          estimatedDistanceKm: distance,
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

    final drones = ref.watch(droneProvider);
    double maxFleetPayload = 0.0;
    if (drones.isNotEmpty) {
      maxFleetPayload = drones.map((d) => d.maxPayload).reduce((a, b) => a > b ? a : b);
    } else {
      maxFleetPayload = 15.0;
    }

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
                      maxFleetPayload: maxFleetPayload,
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
                      estimatedDistance: _selectedPickup != null && _selectedDropoff != null
                          ? '${_getEstimatedDistanceKm(_selectedPickup!.id, _selectedDropoff!.id)} km'
                          : 'TBD',
                      onEditPackage: () {
                        _pageController.animateToPage(
                          0,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOutCubic,
                        );
                        setState(() => _currentPage = 0);
                      },
                      onEditLocation: () {
                        _pageController.animateToPage(
                          1,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOutCubic,
                        );
                        setState(() => _currentPage = 1);
                      },
                      onEditPayment: () {
                        _pageController.animateToPage(
                          2,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOutCubic,
                        );
                        setState(() => _currentPage = 2);
                      },
                      onEditPrioritySchedule: () {
                        _pageController.animateToPage(
                          0,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOutCubic,
                        );
                        setState(() => _currentPage = 0);
                      },
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
  final double maxFleetPayload;

  const _PackagePage({
    required this.typeValue,
    required this.onTypeChanged,
    required this.priorityValue,
    required this.onPriorityChanged,
    required this.scheduledText,
    required this.onPickSchedule,
    required this.weightController,
    required this.notesController,
    required this.maxFleetPayload,
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
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Maximum supported fleet capacity: ${maxFleetPayload.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      color: AppColors.accent.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
                  const SizedBox(height: 20),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Campus locations failed to load. Please try again.',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
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
  final String estimatedDistance;
  final VoidCallback onEditPackage;
  final VoidCallback onEditLocation;
  final VoidCallback onEditPayment;
  final VoidCallback onEditPrioritySchedule;

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
    required this.estimatedDistance,
    required this.onEditPackage,
    required this.onEditLocation,
    required this.onEditPayment,
    required this.onEditPrioritySchedule,
  });

  Widget _sectionHeader(String title, VoidCallback onEdit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTextStyles.label(
            fontSize: 11,
            color: AppColors.accent,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.accent),
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
          onPressed: onEdit,
        ),
      ],
    );
  }

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
                _sectionHeader('Package Details', onEditPackage),
                const SizedBox(height: 8),
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
                const Divider(color: AppColors.borderDark, height: 24),
                _sectionHeader('Priority & Schedule', onEditPrioritySchedule),
                const SizedBox(height: 8),
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
                const Divider(color: AppColors.borderDark, height: 24),
                _sectionHeader('Location Details', onEditLocation),
                const SizedBox(height: 8),
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
                  icon: Icons.map_outlined,
                  label: 'Estimated Distance',
                  value: estimatedDistance,
                  color: AppColors.accent,
                ),
                _confirmItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Recipient',
                  value: recipient,
                ),
                const Divider(color: AppColors.borderDark, height: 24),
                _sectionHeader('Payment Details', onEditPayment),
                const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.textSecondaryDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: AppTextStyles.body(
                fontSize: 13.5,
                color: AppColors.textSecondaryDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: AppTextStyles.title(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
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
      initialValue: value,
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