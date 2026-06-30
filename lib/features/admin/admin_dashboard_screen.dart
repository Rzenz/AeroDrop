import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/analytics_card.dart';
import '../../core/widgets/delivery_card.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/providers/drone_provider.dart';
import '../../core/models/delivery_model.dart';
import '../../core/models/drone_model.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveries = ref.watch(deliveryProvider);
    final drones = ref.watch(droneProvider);
    final active = deliveries.where((d) => d.status == DeliveryStatus.inTransit).length;
    final pending = deliveries.where((d) => d.status == DeliveryStatus.pending).length;
    final availDrones = drones.where((d) => d.status == DroneStatus.available).length;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.cardDark,
        onRefresh: () async {
          await ref.read(deliveryProvider.notifier).loadAdminDeliveriesFromSupabase();
          await ref.read(droneProvider.notifier).loadDronesFromSupabase();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text('Command Deck',
                style: AppTextStyles.title(
                    fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white))
                .animate().fadeIn().slideY(begin: -0.1),
            Text('Real-time fleet & delivery overview',
                style: AppTextStyles.body(fontSize: 14, color: AppColors.textSecondaryDark))
                .animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 24),

            // Hero Banner Card: Accent Gradient Highlight (Moved from User Dashboard)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF42A5F5), AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.bgDark.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text(
                          'AUTONOMOUS NETWORK',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.bgDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Icon(Icons.wifi_tethering_rounded, color: AppColors.bgDark, size: 20),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Campus Fleet Active',
                    style: AppTextStyles.display(
                      fontSize: 28,
                      color: AppColors.bgDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$availDrones drones ready for immediate dispatch.',
                    style: AppTextStyles.body(
                      fontSize: 13.5,
                      color: AppColors.bgDark.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0),

            // KPI grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                AnalyticsCard(
                  title: 'Active Flights',
                  value: '$active',
                  change: '+12.5%',
                  isPositive: true,
                  icon: Icons.flight_takeoff_rounded,
                  iconColor: AppColors.primary,
                  animDelay: 0,
                ),
                AnalyticsCard(
                  title: 'Pending',
                  value: '$pending',
                  change: '-4.8%',
                  isPositive: false,
                  icon: Icons.schedule_rounded,
                  iconColor: AppColors.warning,
                  animDelay: 80,
                ),
                AnalyticsCard(
                  title: 'Fleet Online',
                  value: '$availDrones/${drones.length}',
                  change: 'Operational',
                  isPositive: true,
                  icon: Icons.electric_bolt_rounded,
                  iconColor: AppColors.success,
                  animDelay: 160,
                ),
                AnalyticsCard(
                  title: 'Success Rate',
                  value: '98.4%',
                  change: '+0.2%',
                  isPositive: true,
                  icon: Icons.verified_rounded,
                  iconColor: AppColors.accent,
                  animDelay: 240,
                ),
              ],
            ),

            const SizedBox(height: 28),

            // 7-Day line chart
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('7-Day Deliveries',
                          style: AppTextStyles.title(
                              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('This week',
                            style: TextStyle(
                                color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 160,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: AppColors.borderDark.withValues(alpha: 0.4),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) {
                                const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                                final index = v.toInt();
                                if (index >= 0 && index < days.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      days[index],
                                      style: const TextStyle(
                                          color: AppColors.textSecondaryDark, fontSize: 11),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                              reservedSize: 28,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: 6,
                        minY: 0,
                        maxY: 90,
                        lineBarsData: [
                          LineChartBarData(
                            spots: const [
                              FlSpot(0, 42), FlSpot(1, 58), FlSpot(2, 35),
                              FlSpot(3, 71), FlSpot(4, 64), FlSpot(5, 80), FlSpot(6, 55),
                            ],
                            isCurved: true,
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.accent],
                            ),
                            barWidth: 3,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (s, x, bar, i) => FlDotCirclePainter(
                                radius: 4,
                                color: AppColors.accent,
                                strokeWidth: 2,
                                strokeColor: AppColors.bgDark,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.3),
                                  AppColors.primary.withValues(alpha: 0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.1),

            const SizedBox(height: 28),

            // Recent deliveries
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Activity',
                    style: AppTextStyles.title(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                TextButton(
                  onPressed: () => context.go('/admin/deliveries'),
                  child: Text('View all',
                      style: AppTextStyles.body(
                          fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accent)),
                ),
              ],
            ).animate(delay: 400.ms).fadeIn(),
            const SizedBox(height: 8),

            ...deliveries.take(3).toList().asMap().entries.map((e) {
              return DeliveryCard(
                delivery: e.value,
                onTap: () => context.go('/admin/deliveries/details?id=${e.value.id}'),
              )
                  .animate(delay: Duration(milliseconds: (460 + e.key * 80).toInt()))
                  .fadeIn()
                  .slideX(begin: 0.04);
            }),
          ],
        ),
      ),
     ),
    );
  }
}
