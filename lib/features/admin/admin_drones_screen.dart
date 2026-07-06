import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/drone_card.dart';
import '../../core/widgets/animated_fab.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/models/drone_model.dart';
import '../../core/providers/drone_provider.dart';
import '../../core/providers/settings_provider.dart';

class AdminDronesScreen extends ConsumerWidget {
  const AdminDronesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drones = ref.watch(droneProvider);
    final available = drones.where((d) => d.status == DroneStatus.available).length;
    final active = drones.where((d) => d.status == DroneStatus.busy).length;
    final maintenance = drones.where((d) => d.status == DroneStatus.maintenance).length;
    
    final lowBatteryAlerts = ref.watch(lowBatteryAlertsProvider);
    final drone001 = drones.firstWhere(
      (d) => d.id == 'DRN-001',
      orElse: () => DroneModel(
        id: 'DRN-001',
        name: 'AeroCarrier Alpha',
        batteryLevel: 100.0,
        status: DroneStatus.available,
        maxPayload: 0.5,
        modelType: '001',
        currentCoordinates: '10.3456,123.9478',
      ),
    );
    final showLowBatteryWarning = lowBatteryAlerts && drone001.batteryLevel < 10.0;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      floatingActionButton: AnimatedFAB(
        icon: Icons.add_rounded,
        tooltip: 'Add Drone',
        onPressed: () => context.push('/admin/drones/add'),
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.cardDark,
        onRefresh: () async {
          await ref.read(droneProvider.notifier).loadDronesFromSupabase();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          // Fleet Status Summary Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fleet Management',
                    style: AppTextStyles.title(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Control and monitor the AeroDrop drone network',
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Dashboard cards row
                  Row(
                    children: [
                      _StatusSummaryTile(
                        count: '${drones.length}',
                        label: 'Total',
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      _StatusSummaryTile(
                        count: '$available',
                        label: 'Available',
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      _StatusSummaryTile(
                        count: '$active',
                        label: 'Active',
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 8),
                      _StatusSummaryTile(
                        count: '$maintenance',
                        label: 'Service',
                        color: AppColors.warning,
                      ),
                    ],
                  ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
                  if (showLowBatteryWarning) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.battery_alert_rounded, color: AppColors.danger, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Drone battery is low. Recharge required before accepting deliveries.',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().shake(hz: 4, curve: Curves.easeInOut),
                  ],
                ],
              ),
            ),
          ),

          // Drone List
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
            sliver: drones.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No drones registered in the fleet.',
                        style: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final drone = drones[index];
                        return DroneCard(
                          drone: drone,
                          onTap: () => _showDroneOptions(context, drone, ref),
                        ).animate(delay: Duration(milliseconds: 100 + index * 60))
                         .fadeIn()
                         .slideY(begin: 0.08, end: 0);
                      },
                      childCount: drones.length,
                    ),
                  ),
          ),
        ],
      ),
     ),
    );
  }

  void _showDroneOptions(BuildContext context, DroneModel drone, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: javaScriptBlurFilter(),
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(ctx).viewInsets.bottom + 28),
              decoration: BoxDecoration(
                color: AppColors.bgDark.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.flight_takeoff_rounded, color: AppColors.accent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(drone.name, style: AppTextStyles.title(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('ID: ${drone.id} • Max Cargo: ${drone.maxPayload} kg', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('DRONE STATUS', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: DroneStatus.values.map((status) {
                      final isSelected = drone.status == status;
                      Color btnColor = AppColors.primary;
                      if (status == DroneStatus.available) btnColor = AppColors.success;
                      if (status == DroneStatus.maintenance) btnColor = AppColors.warning;
                      if (status == DroneStatus.offline) btnColor = AppColors.danger;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () {
                              ref.read(droneProvider.notifier).updateStatus(drone.id, status);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Drone status updated to ${status.name.toUpperCase()}'),
                                backgroundColor: AppColors.success,
                              ));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? btnColor.withValues(alpha: 0.2) : AppColors.cardDark,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isSelected ? btnColor : AppColors.borderDark),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                status.name.substring(0, 1).toUpperCase() + status.name.substring(1),
                                style: TextStyle(
                                  color: isSelected ? btnColor : Colors.white60,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.primary),
                          ),
                          onPressed: () {
                            ref.read(droneProvider.notifier).rechargeDrone(drone.id);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Drone battery recharged to 100%!'),
                              backgroundColor: AppColors.success,
                            ));
                          },
                          icon: const Icon(Icons.battery_charging_full_rounded),
                          label: const Text('Recharge Fleet'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                            foregroundColor: AppColors.danger,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.danger),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            if (drone.status == DroneStatus.busy) {
                              showDialog(
                                context: context,
                                builder: (c) => AlertDialog(
                                  backgroundColor: AppColors.cardDark,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: const Text('Cannot Decommission', style: TextStyle(color: Colors.white)),
                                  content: const Text('This drone is currently on an active flight delivery mission and cannot be decommissioned.', style: TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c),
                                      child: const Text('OK', style: TextStyle(color: AppColors.accent)),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Drone "${drone.name}" sent to decommission queue.'),
                                backgroundColor: AppColors.success,
                              ));
                            }
                          },
                          icon: const Icon(Icons.delete_forever_rounded),
                          label: const Text('Decommission'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method for ImageFilter blur construction
  ImageFilter javaScriptBlurFilter() => ImageFilter.blur(sigmaX: 20, sigmaY: 20);
}

class _StatusSummaryTile extends StatelessWidget {
  final String count;
  final String label;
  final Color color;

  const _StatusSummaryTile({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondaryDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
