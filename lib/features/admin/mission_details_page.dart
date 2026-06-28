import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/models/delivery_model.dart';

class MissionDetailsPage extends ConsumerStatefulWidget {
  final String missionId;
  const MissionDetailsPage({super.key, required this.missionId});

  @override
  ConsumerState<MissionDetailsPage> createState() => _MissionDetailsPageState();
}

class _MissionDetailsPageState extends ConsumerState<MissionDetailsPage> {
  double _progress = 0.45;
  late Timer _progressTimer;
  String _autopilotState = 'AUTOMATIC CORRIDOR LOCK';
  Color _stateColor = AppColors.success;

  @override
  void initState() {
    super.initState();
    _progressTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      if (_autopilotState == 'AUTOMATIC CORRIDOR LOCK') {
        setState(() {
          _progress += 0.02;
          if (_progress > 1.0) _progress = 1.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _progressTimer.cancel();
    super.dispose();
  }

  void _updateAutopilot(String state, Color color, String message) {
    setState(() {
      _autopilotState = state;
      _stateColor = color;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = ref.watch(deliveryProvider);
    final mission = deliveries.firstWhere(
      (d) => d.id == widget.missionId,
      orElse: () => DeliveryModel(
        id: widget.missionId,
        senderName: 'UCLM Admin',
        recipientName: 'UCLM Clinic',
        recipientPhone: '+63 912 345 6789',
        deliveryAddress: 'Clinic Platform Roof',
        packageName: 'Medical Kit',
        packageWeight: 1.5,
        packageType: 'Medicine',
        status: DeliveryStatus.inTransit,
        eta: '8 mins',
        createdAt: DateTime.now(),
        progress: 0.45,
      ),
    );

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
                      'Mission Control Console',
                      style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 28),

                // Flight Status Overview Card
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Flight Corridor Link',
                                style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _autopilotState,
                                style: AppTextStyles.title(fontSize: 14, fontWeight: FontWeight.bold, color: _stateColor),
                              ),
                            ],
                          ),
                          StatusChip(
                            label: 'GPS LOCK',
                            color: AppColors.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 12,
                          backgroundColor: AppColors.borderDark,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Campus Hub', style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark)),
                          Text('${(_progress * 100).toStringAsFixed(0)}% Completed', style: AppTextStyles.title(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(mission.deliveryAddress, style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark)),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 20),

                // Telemetry Details Card
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Mission Specifications',
                                style: AppTextStyles.title(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 16),
                              _buildMetricRow(Icons.inventory_2_outlined, 'Payload Description', mission.packageName),
                              _buildDivider(),
                              _buildMetricRow(Icons.person_outline_rounded, 'Recipient Contact', mission.recipientName),
                              _buildDivider(),
                              _buildMetricRow(Icons.radar_rounded, 'Collision Avoidance', 'Active (Lidar Scanning)'),
                              _buildDivider(),
                              _buildMetricRow(Icons.satellite_alt_rounded, 'Command Frequency', 'UHF 433 MHz Telemetry Link'),
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Autopilot Override Controls
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Pause Autopilot',
                            icon: Icons.pause_circle_outline_rounded,
                            gradient: const LinearGradient(colors: [AppColors.warning, AppColors.warning]),
                            onPressed: () => _updateAutopilot(
                              'AUTOPILOT HOLD ACTIVE',
                              AppColors.warning,
                              'Autopilot paused. Drone hovering in position.',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomButton(
                            text: 'Resume Lock',
                            icon: Icons.play_circle_outline_rounded,
                            onPressed: () => _updateAutopilot(
                              'AUTOMATIC CORRIDOR LOCK',
                              AppColors.success,
                              'Autopilot corridor lock resumed successfully.',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: 'Trigger Return to Hub',
                      icon: Icons.keyboard_return_rounded,
                      gradient: const LinearGradient(colors: [AppColors.cardDark, AppColors.cardDark]),
                      onPressed: () => _updateAutopilot(
                        'RETURNING TO CAMPUS HUB',
                        AppColors.primary,
                        'RTL protocol initiated. Drone returning to campus base.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: 'Abort Mission & Force Land',
                      icon: Icons.offline_bolt_rounded,
                      gradient: const LinearGradient(colors: [AppColors.danger, AppColors.danger]),
                      onPressed: () => _updateAutopilot(
                        'EMERGENCY LANDING INITIATED',
                        AppColors.danger,
                        'Abort command issued. Drone initiating immediate local landing.',
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.secondary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.body(fontSize: 10, color: AppColors.textSecondaryDark)),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.title(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: AppColors.borderDark.withValues(alpha: 0.5), height: 1),
    );
  }
}
