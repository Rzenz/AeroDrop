import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/providers/drone_provider.dart';
import '../../core/models/drone_model.dart';

class DroneDetailsPage extends ConsumerWidget {
  final String droneId;
  const DroneDetailsPage({super.key, required this.droneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drones = ref.watch(droneProvider);
    final drone = drones.firstWhere(
      (d) => d.id == droneId,
      orElse: () => DroneModel(
        id: droneId,
        name: 'AeroCarrier Falcon',
        batteryLevel: 92.5,
        status: DroneStatus.available,
        maxPayload: 5.0,
        modelType: 'AeroCarrier-X',
        currentCoordinates: '10.3276° N, 123.9507° E',
      ),
    );

    Color statusColor;
    if (drone.status == DroneStatus.available) {
      statusColor = AppColors.success;
    } else if (drone.status == DroneStatus.busy) {
      statusColor = AppColors.primary;
    } else if (drone.status == DroneStatus.maintenance) {
      statusColor = AppColors.warning;
    } else {
      statusColor = AppColors.danger;
    }

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
                      'Drone Operational Details',
                      style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 32),

                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Quick overview card
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (rect) => AppColors.primaryGradient.createShader(rect),
                                child: const Icon(
                                  Icons.flight_takeoff_rounded,
                                  size: 64,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                drone.name,
                                style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${drone.modelType} • ${drone.id}',
                                style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark),
                              ),
                              const SizedBox(height: 16),
                              StatusChip(
                                label: drone.status.name.toUpperCase(),
                                color: statusColor,
                              ),
                              const SizedBox(height: 12),
                              // Battery delivery readiness label
                              Text(
                                drone.batteryLevel < 10.0
                                    ? 'Battery too low for delivery'
                                    : drone.status == DroneStatus.available
                                        ? 'Ready for delivery'
                                        : 'Drone not available',
                                style: AppTextStyles.body(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: drone.batteryLevel < 10.0
                                      ? AppColors.danger
                                      : drone.status == DroneStatus.available
                                          ? AppColors.success
                                          : AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),
                        const SizedBox(height: 20),

                        // System Telemetry Metrics
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Hardware Specifications & Status',
                                style: AppTextStyles.title(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 16),
                              _buildMetricRow(Icons.battery_charging_full_rounded, 'Battery level', '${drone.batteryLevel}%'),
                              _buildDivider(),
                              _buildMetricRow(Icons.scale_rounded, 'Max Payload Capacity', '${drone.maxPayload} kg'),
                              _buildDivider(),
                              _buildMetricRow(Icons.location_on_outlined, 'GPS Coordinates', drone.currentCoordinates),
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
                        const SizedBox(height: 20),

                        // Maintenance Logs
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Last Flight & Maintenance',
                                style: AppTextStyles.title(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 16),
                              _buildMetricRow(Icons.history_toggle_off_rounded, 'Last Mission Date', 'June 25, 2026 at 2:30 PM'),
                              _buildDivider(),
                              _buildMetricRow(Icons.build_circle_outlined, 'Service Interval Status', 'Operational (Next due in 45 hrs)'),
                            ],
                          ),
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomButton(
                      text: 'Launch Live Telemetry Deck',
                      icon: Icons.monitor_heart_rounded,
                      onPressed: () => context.push('/admin/drones/monitor?id=${drone.id}'),
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: 'Recharge Drone',
                      icon: Icons.battery_charging_full_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A6B3C), Color(0xFF27AE60)],
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppColors.cardDark,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('Recharge Drone?', style: TextStyle(color: Colors.white)),
                            content: const Text(
                              'This will set AeroCarrier Alpha battery to 100% and mark it as available.',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Recharge', style: TextStyle(color: AppColors.success)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          final error = await ref.read(droneProvider.notifier).rechargeDrone(drone.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error ?? 'Drone recharged successfully.'),
                              backgroundColor: error == null ? AppColors.success : AppColors.danger,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: 'Edit Hardware Profile',
                      icon: Icons.edit_rounded,
                      gradient: const LinearGradient(colors: [AppColors.cardDark, AppColors.cardDark]),
                      onPressed: () => context.push('/admin/drones/edit?id=${drone.id}'),
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: 'Decommission Drone',
                      icon: Icons.delete_forever_rounded,
                      gradient: AppColors.dangerGradient,
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppColors.cardDark,
                            title: const Text('Decommission Drone', style: TextStyle(color: Colors.white)),
                            content: Text('Are you sure you want to decommission and delete ${drone.name} (${drone.id}) from the fleet registry?', style: const TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Decommission', style: TextStyle(color: AppColors.danger)),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          final error = await ref.read(droneProvider.notifier).deleteDroneFromSupabase(drone.id);
                          if (!context.mounted) return;
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Decommission failed: $error'),
                                backgroundColor: AppColors.danger,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Drone decommissioned successfully!'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            context.pop();
                          }
                        }
                      },
                    ),
                  ],
                ).animate().fadeIn(delay: 400.ms),
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
        Icon(icon, color: AppColors.secondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark)),
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
