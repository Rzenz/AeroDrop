import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_card.dart';

class EditNoFlyZonePage extends ConsumerStatefulWidget {
  final String zoneId;
  final String name;
  final String reason;

  const EditNoFlyZonePage({
    super.key,
    required this.zoneId,
    this.name = '',
    this.reason = '',
  });

  @override
  ConsumerState<EditNoFlyZonePage> createState() => _EditNoFlyZonePageState();
}

class _EditNoFlyZonePageState extends ConsumerState<EditNoFlyZonePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _radiusController;
  late final TextEditingController _coordsController;
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name.isNotEmpty ? widget.name : 'Gymnasium Dome');
    _radiusController = TextEditingController(text: '75m');
    _coordsController = TextEditingController(text: '10.3282° N, 123.9515° E');
    _reasonController = TextEditingController(text: widget.reason.isNotEmpty ? widget.reason : 'Indoor activities, structural height risk');
  }

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
          content: Text('Geofence zone ${widget.zoneId} updated successfully!'),
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
                        'Edit Airspace Cap',
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
                              hintText: 'e.g. Gymnasium Dome',
                              prefixIcon: Icons.edit_rounded,
                              controller: _nameController,
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 20),
                            CustomTextField(
                              labelText: 'Airspace Radius (meters)',
                              hintText: 'e.g. 75m',
                              prefixIcon: Icons.radar_rounded,
                              controller: _radiusController,
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 20),
                            CustomTextField(
                              labelText: 'Center GPS coordinates',
                              hintText: 'e.g. 10.3160° N, 123.8860° E',
                              prefixIcon: Icons.location_on_outlined,
                              controller: _coordsController,
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 20),
                            CustomTextField(
                              labelText: 'Restricted Airspace Reason',
                              hintText: 'e.g. Structural height risk',
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
                    text: 'Update Airspace parameters',
                    icon: Icons.check_circle_outline_rounded,
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
