import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/delivery_card.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/providers/drone_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/delivery_model.dart';
import '../../core/models/drone_model.dart';

class UserDashboardScreen extends ConsumerWidget {
  const UserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final deliveries = ref.watch(deliveryProvider);
    final drones = ref.watch(droneProvider);

    final active = deliveries.where((d) => d.status == DeliveryStatus.inTransit).toList();
    final completed = deliveries.where((d) => d.status == DeliveryStatus.delivered).toList();
    final availDrones = drones.where((d) => d.status == DroneStatus.available).length;

    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final firstName = user?.name.split(' ').first ?? 'User';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverToBoxAdapter(
            child: _HeroHeader(
              greeting: greeting,
              name: firstName,
              active: active.length,
              availDrones: availDrones,
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),

                // Stats row
                Row(
                  children: [
                    _StatPill(label: 'Active', value: '${active.length}', color: AppColors.primary),
                    const SizedBox(width: 10),
                    _StatPill(label: 'Completed', value: '${completed.length}', color: AppColors.success),
                    const SizedBox(width: 10),
                    _StatPill(label: 'Fleet', value: '$availDrones Online', color: AppColors.secondary),
                  ],
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 24),

                // Delivery trend sparkline
                _DeliverySparkline(deliveries: deliveries).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 24),

                // Active delivery
                if (active.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active Delivery',
                          style: AppTextStyles.title(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      GestureDetector(
                        onTap: () => context.go('/user/track'),
                        child: Text('Track →',
                            style: AppTextStyles.body(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DeliveryCard(
                    delivery: active.first,
                    onTap: () => context.go('/user/track'),
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.05),
                  const SizedBox(height: 24),
                ],

                // Recent deliveries
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Deliveries',
                        style: AppTextStyles.title(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    GestureDetector(
                      onTap: () => context.go('/user/history'),
                      child: Text('View all →',
                          style: AppTextStyles.body(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary)),
                    ),
                  ],
                ).animate().fadeIn(delay: 450.ms),
                const SizedBox(height: 12),

                if (deliveries.isEmpty)
                  GlassCard(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        const Icon(Icons.local_shipping_outlined,
                            color: AppColors.textSecondaryDark, size: 40),
                        const SizedBox(height: 12),
                        Text('No deliveries yet',
                            style: AppTextStyles.body(
                                fontSize: 14,
                                color: AppColors.textSecondaryDark)),
                      ],
                    ),
                  )
                else
                  ...deliveries.take(3).toList().asMap().entries.map((e) {
                    return DeliveryCard(
                      delivery: e.value,
                      onTap: () {},
                    ).animate(delay: Duration(milliseconds: 500 + e.key * 80))
                        .fadeIn()
                        .slideX(begin: 0.04);
                  }),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String greeting;
  final String name;
  final int active;
  final int availDrones;

  const _HeroHeader({
    required this.greeting,
    required this.name,
    required this.active,
    required this.availDrones,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.8),
            AppColors.bgDark,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting,
                      style: AppTextStyles.body(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7))),
                  Text(name,
                      style: AppTextStyles.title(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.3),
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
              ),
            ],
          ).animate().fadeIn().slideY(begin: -0.1),
          const SizedBox(height: 16),
          // Live status pill
          if (active > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text('$active delivery in flight',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.05),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: AppTextStyles.title(
                    fontSize: 16, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                style: AppTextStyles.body(
                    fontSize: 11, color: AppColors.textSecondaryDark)),
          ],
        ),
      ),
    );
  }
}

class _DeliverySparkline extends StatelessWidget {
  final List deliveries;
  const _DeliverySparkline({required this.deliveries});

  @override
  Widget build(BuildContext context) {
    // ponytail: static sparkline data — wire to real timeseries if backend added
    final spots = [
      const FlSpot(0, 3),
      const FlSpot(1, 5),
      const FlSpot(2, 4),
      const FlSpot(3, 7),
      const FlSpot(4, 6),
      const FlSpot(5, 8),
      FlSpot(6, deliveries.length.toDouble().clamp(1, 12)),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Weekly Trend',
                  style: AppTextStyles.title(
                      fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('↑ 23%',
                    style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 12,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.25),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: const LineTouchData(enabled: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
