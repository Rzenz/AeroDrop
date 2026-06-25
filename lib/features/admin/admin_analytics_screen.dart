import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/analytics_card.dart';
import '../../core/widgets/glass_card.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Performance Analytics',
                style: AppTextStyles.title(
                    fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white))
                .animate().fadeIn(),
            Text('Last 7 days • Jun 16 – Jun 22',
                style: AppTextStyles.body(fontSize: 13, color: AppColors.textSecondaryDark))
                .animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 24),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: const [
                AnalyticsCard(
                  title: 'Total Deliveries', value: '405',
                  change: '+18.3%', isPositive: true,
                  icon: Icons.local_shipping_rounded, iconColor: AppColors.primary, animDelay: 0,
                ),
                AnalyticsCard(
                  title: 'Success Rate', value: '98.4%',
                  change: '+0.2%', isPositive: true,
                  icon: Icons.verified_rounded, iconColor: AppColors.success, animDelay: 80,
                ),
                AnalyticsCard(
                  title: 'Avg Flight Time', value: '11.2m',
                  change: '-1.8m', isPositive: true,
                  icon: Icons.timer_rounded, iconColor: AppColors.secondary, animDelay: 160,
                ),
                AnalyticsCard(
                  title: 'Fleet Uptime', value: '94.7%',
                  change: '+2.1%', isPositive: true,
                  icon: Icons.flight_takeoff_rounded, iconColor: AppColors.warning, animDelay: 240,
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Bar Chart — weekly volume
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly Volume',
                      style: AppTextStyles.title(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Packages dispatched per day',
                      style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 160,
                    child: BarChart(
                      BarChartData(
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) {
                                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(days[v.toInt()],
                                      style: const TextStyle(
                                          color: AppColors.textSecondaryDark, fontSize: 10)),
                                );
                              },
                              reservedSize: 28,
                            ),
                          ),
                        ),
                        barGroups: [42.0, 58.0, 35.0, 71.0, 64.0, 80.0, 55.0]
                            .asMap()
                            .entries
                            .map((e) => BarChartGroupData(
                                  x: e.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: e.value,
                                      gradient: AppColors.primaryGradient,
                                      width: 22,
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(6)),
                                    ),
                                  ],
                                ))
                            .toList(),
                        maxY: 90,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => AppColors.cardDark2,
                            tooltipRoundedRadius: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                              '${rod.toY.toInt()} pkgs',
                              const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.1),

            const SizedBox(height: 20),

            // Breakdown
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Package Type Breakdown',
                      style: AppTextStyles.title(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  _breakdown('Documents', 38, AppColors.primary),
                  _breakdown('Medicine', 27, AppColors.success),
                  _breakdown('Electronics', 21, AppColors.secondary),
                  _breakdown('Food & Others', 14, AppColors.warning),
                ],
              ),
            ).animate(delay: 420.ms).fadeIn().slideY(begin: 0.1),

            const SizedBox(height: 20),

            // Drone leaderboard
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top Drones',
                      style: AppTextStyles.title(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  _droneRow('#1', 'AeroCarrier Falcon', '142 trips', '98.6%', AppColors.primary),
                  const Divider(color: AppColors.borderDark, height: 24),
                  _droneRow('#2', 'SkyLifter Titan', '128 trips', '97.2%', AppColors.secondary),
                  const Divider(color: AppColors.borderDark, height: 24),
                  _droneRow('#3', 'Shadow Swift', '97 trips', '95.8%', AppColors.success),
                ],
              ),
            ).animate(delay: 520.ms).fadeIn().slideY(begin: 0.1),
          ],
        ),
      ),
    );
  }

  Widget _breakdown(String label, int pct, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text('$pct%',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _droneRow(String rank, String name, String trips, String rate, Color color) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(rank,
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 11)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: AppTextStyles.title(
                      fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(trips,
                  style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(rate,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
        ),
      ],
    );
  }
}
