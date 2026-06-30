import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/drone_card.dart';
import '../../core/widgets/animated_fab.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/drone_provider.dart';
import '../../core/models/drone_model.dart';

class AdminDronesScreen extends ConsumerWidget {
  const AdminDronesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drones = ref.watch(droneProvider);
    final available = drones.where((d) => d.status == DroneStatus.available).length;
    final active = drones.where((d) => d.status == DroneStatus.busy).length;
    final maintenance = drones.where((d) => d.status == DroneStatus.maintenance).length;

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
                          onTap: () => context.push('/admin/drones/details?id=${drone.id}'),
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
