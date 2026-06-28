import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/models/delivery_model.dart';

class MissionListPage extends ConsumerWidget {
  const MissionListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveries = ref.watch(deliveryProvider);
    // ponytail: mapping deliveries to operational drone missions
    final missions = deliveries.where((d) => d.status == DeliveryStatus.inTransit || d.status == DeliveryStatus.pending).toList();

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
                      'Mission Control Center',
                      style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 32),

                // Missions count banner
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Icon(Icons.hub_rounded, color: AppColors.primary, size: 28),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${missions.length} Active Flights',
                            style: AppTextStyles.title(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'Simultaneous automated missions on campus',
                            style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 24),

                // Missions List
                Expanded(
                  child: missions.isEmpty
                      ? Center(
                          child: Text(
                            'No active flight missions detected.',
                            style: TextStyle(color: AppColors.textSecondaryDark),
                          ),
                        )
                      : ListView.builder(
                          itemCount: missions.length,
                          itemBuilder: (context, index) {
                            final mission = missions[index];
                            final isTransit = mission.status == DeliveryStatus.inTransit;
                            
                            return GestureDetector(
                              onTap: () => context.push('/admin/missions/details?id=${mission.id}'),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.flight_takeoff_rounded, color: AppColors.secondary, size: 18),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Mission: ${mission.id}',
                                                style: AppTextStyles.title(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ],
                                          ),
                                          StatusChip(
                                            label: isTransit ? 'IN-FLIGHT' : 'QUEUED',
                                            color: isTransit ? AppColors.primary : AppColors.warning,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildMissionDetail(Icons.inventory_2_outlined, 'Payload', mission.packageName),
                                      const SizedBox(height: 6),
                                      _buildMissionDetail(Icons.location_on_outlined, 'Target Platform', mission.deliveryAddress),
                                      const SizedBox(height: 6),
                                      _buildMissionDetail(Icons.speed_rounded, 'Autopilot Path', 'Optimum Safe Corridor A-3'),
                                    ],
                                  ),
                                ),
                              ),
                            ).animate(delay: Duration(milliseconds: index * 60))
                             .fadeIn()
                             .slideY(begin: 0.05);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissionDetail(IconData icon, String label, String val) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondaryDark, size: 14),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(
            val,
            style: const TextStyle(fontSize: 11, color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
