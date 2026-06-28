import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_card.dart';

class CreateNoFlyZonePage extends ConsumerStatefulWidget {
  const CreateNoFlyZonePage({super.key});

  @override
  ConsumerState<CreateNoFlyZonePage> createState() => _CreateNoFlyZonePageState();
}

class _CreateNoFlyZonePageState extends ConsumerState<CreateNoFlyZonePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _radiusController = TextEditingController(text: '50m');
  final _coordsController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    _coordsController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Restricted geofence corridor broadcasted to drone fleet!'),
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
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
                        'Create Airspace Cap',
                        style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ).animate().fadeIn().slideX(begin: -0.1),
                  const SizedBox(height: 36),

                  // Fields form card
                  Expanded(
                    child: SingleChildScrollView(
                      child: GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            CustomTextField(
                              labelText: 'Geofence Label / Name',
                              hintText: 'e.g. Auditorium Courtyard',
                              prefixIcon: Icons.edit_rounded,
                              controller: _nameController,
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 20),
                            CustomTextField(
                              labelText: 'Airspace Radius (meters)',
                              hintText: 'e.g. 50m',
                              prefixIcon: Icons.radar_rounded,
                              controller: _radiusController,
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 20),
                            CustomTextField(
                              labelText: 'Center GPS coordinates',
                              hintText: 'e.g. 10.3172° N, 123.8850° E',
                              prefixIcon: Icons.location_on_outlined,
                              controller: _coordsController,
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 20),
                            CustomTextField(
                              labelText: 'Restricted Airspace Reason',
                              hintText: 'e.g. High power voltage lines danger zone',
                              prefixIcon: Icons.error_outline_rounded,
                              controller: _reasonController,
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),
                  ),

                  // Submit
                  CustomButton(
                    text: 'Confirm & Broadcast Geofence',
                    icon: Icons.wifi_tethering_rounded,
                    onPressed: _submit,
                  ).animate().fadeIn(delay: 300.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
