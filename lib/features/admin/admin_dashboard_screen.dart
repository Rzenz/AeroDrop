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
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
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
    final lowBatteryDrone = drones
        .where((d) => d.batteryLevel < 10.0)
        .firstOrNull;
    final showLowBatteryWarning = lowBatteryAlerts && lowBatteryDrone != null;
    final totalCount = deliveries.length;
    final deliveredCount = deliveries
        .where((d) => d.status == DeliveryStatus.delivered)
        .length;
    // Null with no deliveries: there is no rate to show, not a perfect one
    final double? successRate = totalCount > 0
        ? (deliveredCount / totalCount * 100)
        : null;

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
    // A returning drone with trips still owed is shuttling back to the vendor
    final shuttle = deliveries
        .where((d) => d.returnLegHeadsToVendor)
        .firstOrNull;
    final returningLabel = shuttle != null
        ? 'Returning to Vendor • Load ${shuttle.tripsCompleted + 1} of ${shuttle.tripsRequired}'
        : 'Returning to Base';

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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.title(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ).animate().fadeIn().slideY(begin: -0.1),
              Text(
                'Real-time fleet & delivery overview',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                      drones.isEmpty
                          ? 'No Drones Registered'
                          : 'Campus Fleet Active',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.display(
                        fontSize: 26,
                        color: AppColors.bgDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      drones.isEmpty
                          ? 'Add a drone under Fleet before deliveries can be dispatched.'
                          : '$availDrones of ${drones.length} drones ready for immediate dispatch.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                  Expanded(
                    child: Text(
                      'Campus Drone Radar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Opens the flight in progress. With nothing in the air there
                  // is nothing to open; the deliveries list is "See all" below.
                  if (hasActiveDelivery)
                    TextButton.icon(
                      onPressed: () => context.push(
                        '/admin/deliveries/details?id=${activeDelivery.id}',
                      ),
                      icon: const Icon(
                        Icons.fullscreen_rounded,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      label: Text(
                        'Track Delivery',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                          ? 'Campus Drone Radar • ${drones.first.status == DroneStatus.returning ? returningLabel : "${drones.first.status.name[0].toUpperCase()}${drones.first.status.name.substring(1)}"}'
                          : 'Campus Drone Radar • Standby'),
                onTapDetails: hasActiveDelivery
                    ? () => context.push(
                        '/admin/deliveries/details?id=${activeDelivery.id}',
                      )
                    : null,
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 24),

              // KPI grid: four across on a laptop, two on a phone
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 840;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: wide ? 4 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: wide ? 1.6 : 1.25,
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
                        value: successRate == null
                            ? '—'
                            : '${successRate.toStringAsFixed(1)}%',
                        change: successRate == null
                            ? 'No deliveries yet'
                            : 'Delivered: $deliveredCount',
                        isPositive: true,
                        icon: Icons.verified_rounded,
                        iconColor: AppColors.accent,
                        animDelay: 240,
                      ),
                    ],
                  );
                },
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
                        Expanded(
                          child: Text(
                            '7-Day Deliveries',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.title(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
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
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
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

              // Recent deliveries — "See all" is the dashboard's one way
              // into the deliveries list
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Recent Deliveries',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/admin/deliveries'),
                    child: Text(
                      'See all',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

              if (deliveries.isEmpty)
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 20,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        color: AppColors.textSecondaryDark,
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'No deliveries yet. They appear here as soon as '
                          'the first order is dispatched.',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(
                            fontSize: 13,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              ...deliveries.take(3).toList().asMap().entries.map((e) {
                return DeliveryCard(
                      delivery: e.value,
                      onTap: () => context.push(
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
