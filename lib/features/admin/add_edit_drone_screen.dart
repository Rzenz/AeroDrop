import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/models/drone_model.dart';
import '../../core/providers/drone_provider.dart';

class AddEditDroneScreen extends ConsumerStatefulWidget {
  final String droneId;

  const AddEditDroneScreen({super.key, this.droneId = ''});

  @override
  ConsumerState<AddEditDroneScreen> createState() => _AddEditDroneScreenState();
}

class _AddEditDroneScreenState extends ConsumerState<AddEditDroneScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _modelController;
  late TextEditingController _payloadController;
  late TextEditingController _coordsController;
  late TextEditingController _batteryController;
  DroneStatus _status = DroneStatus.available;

  bool get _isEdit => widget.droneId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _modelController = TextEditingController();
    _payloadController = TextEditingController();
    _coordsController = TextEditingController();
    _batteryController = TextEditingController(text: '100');

    if (_isEdit) {
      final drone = ref.read(droneProvider).firstWhere((d) => d.id == widget.droneId);
      _nameController.text = drone.name;
      _modelController.text = drone.modelType;
      _payloadController.text = drone.maxPayload.toString();
      _coordsController.text = drone.currentCoordinates;
      _batteryController.text = drone.batteryLevel.toString();
      _status = drone.status;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _payloadController.dispose();
    _coordsController.dispose();
    _batteryController.dispose();
    super.dispose();
  }

  void _saveDrone() {
    if (_formKey.currentState!.validate()) {
      final payload = double.tryParse(_payloadController.text) ?? 5.0;
      final battery = double.tryParse(_batteryController.text) ?? 100.0;
      
      final drone = DroneModel(
        id: _isEdit ? widget.droneId : 'DRN-${100 + ref.read(droneProvider).length + 1}',
        name: _nameController.text,
        batteryLevel: battery,
        status: _status,
        maxPayload: payload,
        modelType: _modelController.text,
        currentCoordinates: _coordsController.text.isNotEmpty ? _coordsController.text : 'UCLM Control Room Hub',
      );

      if (_isEdit) {
        ref.read(droneProvider.notifier).editDrone(drone);
      } else {
        ref.read(droneProvider.notifier).addDrone(drone);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Drone profile updated!' : 'New drone added to fleet!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back & Title Header Row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
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
                      Text(
                        _isEdit ? 'Configure Drone' : 'Add New Drone',
                        style: AppTextStyles.title(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ).animate().fadeIn().slideX(begin: -0.1),

                  const SizedBox(height: 28),

                  // Header Visual Banner (Gradient with Drone flight theme icon)
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 32),
                          const SizedBox(width: 14),
                          Text(
                            _isEdit ? 'Update Hardware Configuration' : 'Deploy New Aerial Hardware',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate(delay: 100.ms).scale(duration: 400.ms, curve: Curves.easeOutBack),

                  const SizedBox(height: 24),

                  // Fields Form
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CustomTextField(
                          labelText: 'Drone Nickname',
                          hintText: 'e.g. AeroCarrier Falcon',
                          prefixIcon: Icons.airplay_rounded,
                          controller: _nameController,
                          validator: (val) => val == null || val.isEmpty ? 'Enter name' : null,
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          labelText: 'Model Type / Frame',
                          hintText: 'e.g. SkyLifter Titan',
                          prefixIcon: Icons.settings_applications_rounded,
                          controller: _modelController,
                          validator: (val) => val == null || val.isEmpty ? 'Enter model' : null,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                labelText: 'Max Payload (kg)',
                                hintText: '5.0',
                                prefixIcon: Icons.scale_rounded,
                                controller: _payloadController,
                                keyboardType: TextInputType.number,
                                validator: (val) => val == null || val.isEmpty ? 'Enter payload' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                labelText: 'Battery Level (%)',
                                hintText: '100',
                                prefixIcon: Icons.battery_charging_full_rounded,
                                controller: _batteryController,
                                keyboardType: TextInputType.number,
                                validator: (val) => val == null || val.isEmpty ? 'Enter battery' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          labelText: 'Current Coordinates',
                          hintText: 'e.g. 10.3157° N, 123.8854° E',
                          prefixIcon: Icons.location_on_outlined,
                          controller: _coordsController,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Initial System Status',
                          style: AppTextStyles.body(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Premium Styled Status Chips/Choice List
                        Row(
                          children: DroneStatus.values.map((status) {
                            final isSel = _status == status;
                            Color statusColor;
                            if (status == DroneStatus.available) {
                              statusColor = AppColors.success;
                            } else if (status == DroneStatus.busy) {
                              statusColor = AppColors.primary;
                            } else if (status == DroneStatus.maintenance) {
                              statusColor = AppColors.warning;
                            } else {
                              statusColor = AppColors.danger;
                            }

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _status = status),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSel ? statusColor.withValues(alpha: 0.15) : AppColors.cardDark2,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSel ? statusColor : AppColors.borderDark,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        status == DroneStatus.available
                                            ? Icons.check_circle_outline_rounded
                                            : status == DroneStatus.busy
                                                ? Icons.flight_takeoff_rounded
                                                : status == DroneStatus.maintenance
                                                    ? Icons.build_circle_rounded
                                                    : Icons.offline_bolt_rounded,
                                        color: isSel ? statusColor : AppColors.textSecondaryDark,
                                        size: 16,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        status.name.substring(0, 3).toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                          color: isSel ? statusColor : AppColors.textSecondaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 36),
                        CustomButton(
                          text: _isEdit ? 'Save Settings' : 'Deploy Drone',
                          onPressed: _saveDrone,
                          icon: _isEdit ? Icons.save_rounded : Icons.flight_takeoff_rounded,
                        ),
                      ],
                    ),
                  ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
