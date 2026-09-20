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
import '../../core/providers/telemetry_provider.dart';
import '../../core/models/delivery_model.dart';
import '../../core/models/drone_model.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/widgets/shared_drone_radar.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(deliveryProvider.notifier).loadAdminDeliveriesFromSupabase();
      ref.read(droneProvider.notifier).loadDronesFromSupabase();
      ref.read(fleetTelemetryProvider.notifier).loadFleetTelemetry();
    });
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = ref.watch(deliveryProvider);
    final drones = ref.watch(droneProvider);
    final activeDeliveries = deliveries
        .where(
          (d) =>
              d.status == DeliveryStatus.inTransit ||
              d.status == DeliveryStatus.assigning,
        )
        .toList();
    final active = activeDeliveries.length;
    final pending = deliveries
        .where((d) => d.status == DeliveryStatus.pending)
        .length;
    final availDrones = drones
        .where((d) => d.status == DroneStatus.available)
        .length;
    final lowBatteryAlerts = ref.watch(lowBatteryAlertsProvider);
    final lowBatteryDrone =
        drones.where((d) => d.batteryLevel < 10.0).firstOrNull;
    final showLowBatteryWarning =
        lowBatteryAlerts && lowBatteryDrone != null;
    final totalCount = deliveries.length;
    final deliveredCount = deliveries
        .where((d) => d.status == DeliveryStatus.delivered)
        .length;
    final successRate = totalCount > 0
        ? (deliveredCount / totalCount * 100)
        : 100.0;

    final now = DateTime.now();
    final last7Days = List.generate(
      7,
      (i) => now.subtract(Duration(days: 6 - i)),
    );
    final lineSpots = <FlSpot>[];
    double maxLineVal = 5.0;
    for (int i = 0; i < 7; i++) {
      final day = last7Days[i];
      final count = deliveries.where((d) {
        return d.createdAt.year == day.year &&
            d.createdAt.month == day.month &&
            d.createdAt.day == day.day;
      }).length;
      if (count > maxLineVal) maxLineVal = count.toDouble();
      lineSpots.add(FlSpot(i.toDouble(), count.toDouble()));
    }

    final activeDelivery = activeDeliveries.firstOrNull;
    final hasActiveDelivery = activeDelivery != null;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.cardDark,
        onRefresh: () async {
          await ref
              .read(deliveryProvider.notifier)
              .loadAdminDeliveriesFromSupabase();
          await ref.read(droneProvider.notifier).loadDronesFromSupabase();
          await ref.read(fleetTelemetryProvider.notifier).loadFleetTelemetry();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Command Deck',
                style: AppTextStyles.title(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ).animate().fadeIn().slideY(begin: -0.1),
              Text(
                'Real-time fleet & delivery overview',
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.textSecondaryDark,
                ),
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 20),

              if (showLowBatteryWarning) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.battery_alert_rounded,
                        color: AppColors.danger,
                        size: 24,
                      ),
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

              // Hero Banner Card: Accent Gradient Highlight
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF42A5F5), AppColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
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
                        const Icon(
                          Icons.wifi_tethering_rounded,
                          color: AppColors.bgDark,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Campus Fleet Active',
                      style: AppTextStyles.display(
                        fontSize: 26,
                        color: AppColors.bgDark,
                      ),
                    ),
                    const SizedBox(height: 4),
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

              // Prominent Live Drone Radar for Admin Dashboard
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Campus Drone Radar',
                    style: AppTextStyles.title(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (hasActiveDelivery) {
                        context.go(
                          '/admin/deliveries/details?id=${activeDelivery.id}',
                        );
                      } else {
                        context.go('/admin/deliveries');
                      }
                    },
                    icon: const Icon(Icons.fullscreen_rounded, size: 16, color: AppColors.accent),
                    label: Text(
                      hasActiveDelivery ? 'Track Delivery' : 'Deliveries',
                      style: AppTextStyles.body(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SharedDroneRadar(
                delivery: activeDelivery,
                isCompact: false,
                title: hasActiveDelivery
                    ? 'Delivery in Progress • ${activeDelivery.droneId ?? (drones.isNotEmpty ? drones.first.name : "Active Flight")}'
                    : (drones.isNotEmpty
                        ? 'Campus Drone Radar • ${drones.first.status == DroneStatus.returning ? "Returning to Base" : "${drones.first.status.name[0].toUpperCase()}${drones.first.status.name.substring(1)}"}'
                        : 'Campus Drone Radar • Standby'),
                onTapDetails: () {
                  if (hasActiveDelivery) {
                    context.go(
                      '/admin/deliveries/details?id=${activeDelivery.id}',
                    );
                  } else {
                    context.go('/admin/deliveries');
                  }
                },
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 24),

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
                    change: 'In-Flight',
                    isPositive: true,
                    icon: Icons.flight_takeoff_rounded,
                    iconColor: AppColors.primary,
                    animDelay: 0,
                  ),
                  AnalyticsCard(
                    title: 'Pending',
                    value: '$pending',
                    change: 'Awaiting',
                    isPositive: pending == 0,
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
                    value: '${successRate.toStringAsFixed(1)}%',
                    change: 'Delivered: $deliveredCount',
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
                        Text(
                          '7-Day Deliveries',
                          style: AppTextStyles.title(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'This week',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                            getDrawingHorizontalLine: (val) => FlLine(
                              color: AppColors.borderDark,
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (val, _) => Text(
                                  val.toInt().toString(),
                                  style: const TextStyle(
                                    color: AppColors.textSecondaryDark,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, _) {
                                  final i = val.toInt();
                                  if (i < 0 || i >= 7) {
                                    return const SizedBox.shrink();
                                  }
                                  final d = last7Days[i];
                                  final days = [
                                    'M',
                                    'T',
                                    'W',
                                    'T',
                                    'F',
                                    'S',
                                    'S',
                                  ];
                                  return Text(
                                    days[d.weekday - 1],
                                    style: const TextStyle(
                                      color: AppColors.textSecondaryDark,
                                      fontSize: 10,
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: 6,
                          minY: 0,
                          maxY: maxLineVal + 1,
                          lineBarsData: [
                            LineChartBarData(
                              spots: lineSpots,
                              isCurved: true,
                              color: AppColors.accent,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.accent.withValues(alpha: 0.3),
                                    AppColors.accent.withValues(alpha: 0.0),
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
                  Text(
                    'Recent Activity',
                    style: AppTextStyles.title(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/admin/deliveries'),
                    child: Text(
                      'View all',
                      style: AppTextStyles.body(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ).animate(delay: 400.ms).fadeIn(),
              const SizedBox(height: 8),

              ...deliveries.take(3).toList().asMap().entries.map((e) {
                return DeliveryCard(
                      delivery: e.value,
                      onTap: () => context.go(
                        '/admin/deliveries/details?id=${e.value.id}',
                      ),
                    )
                    .animate(
                      delay: Duration(milliseconds: (460 + e.key * 80).toInt()),
                    )
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
