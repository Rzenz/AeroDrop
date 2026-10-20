import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/delivery_model.dart';
import '../../../../core/models/drone_model.dart';
import '../../../../core/providers/delivery_provider.dart';
import '../../../../core/providers/drone_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/providers/telemetry_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../../../../core/widgets/shared_drone_radar.dart';
import '../web_kit.dart';
import '../web_status.dart';

String droneLabel(DroneStatus s) => switch (s) {
  DroneStatus.available => 'Ready',
  DroneStatus.assigned => 'Assigned',
  DroneStatus.busy => 'Flying',
  DroneStatus.charging => 'Charging',
  DroneStatus.maintenance => 'Maintenance',
  DroneStatus.offline => 'Offline',
  DroneStatus.returning => 'Returning',
};

Color droneTone(DroneStatus s) => switch (s) {
  DroneStatus.available => AppColors.success,
  DroneStatus.assigned || DroneStatus.busy => AppColors.accent,
  DroneStatus.returning => AppColors.primary,
  DroneStatus.charging => AppColors.warning,
  DroneStatus.maintenance || DroneStatus.offline => AppColors.danger,
};

/// A battery level as a groove that fills — red under 20%, amber under 50%.
class WebBattery extends StatelessWidget {
  const WebBattery({super.key, required this.level, this.width = 90});

  final double level;
  final double width;

  @override
  Widget build(BuildContext context) {
    final v = (level / 100).clamp(0.0, 1.0);
    final tone = level < 20
        ? AppColors.danger
        : (level < 50 ? AppColors.warning : AppColors.success);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          child: NeuSurface(
            style: NeuStyle.inset,
            depth: NeuDepth.flat,
            color: AppColors.surfaceSunken,
            height: 8,
            borderRadius: BorderRadius.circular(4),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${level.round()}%',
          style: WebText.label(
            size: 12.5,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

/// Deliveries per day for the last seven days, as a soft area chart.
class WebWeekChart extends StatelessWidget {
  const WebWeekChart({super.key, required this.deliveries, this.height = 180});

  final List<DeliveryModel> deliveries;
  final double height;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final spots = <FlSpot>[];
    var top = 4.0;
    for (var i = 0; i < 7; i++) {
      final d = days[i];
      final n = deliveries
          .where(
            (x) =>
                x.createdAt.year == d.year &&
                x.createdAt.month == d.month &&
                x.createdAt.day == d.day,
          )
          .length;
      if (n > top) top = n.toDouble();
      spots.add(FlSpot(i.toDouble(), n.toDouble()));
    }
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final axis = WebText.body(size: 11.5, color: AppColors.textTertiary);
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 6,
          minY: 0,
          maxY: top + 1,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => v % 1 == 0
                    ? Text('${v.toInt()}', style: axis)
                    : const SizedBox.shrink(),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i > 6) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(names[days[i].weekday - 1], style: axis),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.accentFill,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 3.5,
                  color: AppColors.base,
                  strokeWidth: 2,
                  strokeColor: AppColors.accentFill,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.accentFill.withValues(alpha: 0.28),
                    AppColors.accentFill.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The administrator's command deck: what is flying, what is waiting, the
/// fleet's readiness, the week's trend, and the latest deliveries — the
/// app's dashboard as an operations console.
class WebAdminDashboardPage extends ConsumerStatefulWidget {
  const WebAdminDashboardPage({super.key});

  @override
  ConsumerState<WebAdminDashboardPage> createState() =>
      _WebAdminDashboardPageState();
}

class _WebAdminDashboardPageState extends ConsumerState<WebAdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    await ref.read(deliveryProvider.notifier).loadAdminDeliveriesFromSupabase();
    await ref.read(droneProvider.notifier).loadDronesFromSupabase();
    await ref.read(fleetTelemetryProvider.notifier).loadFleetTelemetry();
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = [...ref.watch(deliveryProvider)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final drones = ref.watch(droneProvider);
    final flying = deliveries
        .where(
          (d) =>
              d.status == DeliveryStatus.inTransit ||
              d.status == DeliveryStatus.assigning,
        )
        .toList();
    final waiting = deliveries
        .where((d) => d.status == DeliveryStatus.pending)
        .length;
    final ready = drones.where((d) => d.status == DroneStatus.available).length;
    final delivered = deliveries
        .where((d) => d.status == DeliveryStatus.delivered)
        .length;
    final rate = deliveries.isEmpty
        ? '—'
        : '${(delivered / deliveries.length * 100).toStringAsFixed(1)}%';
    final lowAlerts = ref.watch(lowBatteryAlertsProvider);
    final low = drones.where((d) => d.batteryLevel < 10.0).toList();
    final current = flying.firstOrNull;

    final radar = WebPanel(
      title: 'Campus airspace',
      subtitle: current == null
          ? 'No drone in the air.'
          : 'Following ${current.droneId ?? 'the active flight'}',
      action: current == null
          ? null
          : WebButton(
              label: 'Open flight',
              kind: WebButtonKind.ghost,
              dense: true,
              onPressed: () =>
                  context.push('/admin/deliveries/details?id=${current.id}'),
            ),
      padding: const EdgeInsets.all(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 420,
          child: SharedDroneRadar(
            delivery: current,
            title: current == null
                ? 'Standing by'
                : deliveryLabel(current.status),
            onTapDetails: () => current == null
                ? context.go('/admin/deliveries')
                : context.push('/admin/deliveries/details?id=${current.id}'),
          ),
        ),
      ),
    );

    final fleet = WebPanel(
      title: 'Fleet',
      subtitle: '$ready of ${drones.length} ready to fly',
      action: WebButton(
        label: 'Manage',
        kind: WebButtonKind.ghost,
        dense: true,
        onPressed: () => context.go('/admin/drones'),
      ),
      child: drones.isEmpty
          ? Text('No drones registered yet.', style: WebText.body(size: 13.5))
          : Column(
              children: [
                for (final d in drones.take(6))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flight_rounded,
                          size: 18,
                          color: AppColors.readable(droneTone(d.status)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: WebText.label(size: 14),
                          ),
                        ),
                        WebPill(
                          label: droneLabel(d.status),
                          tone: droneTone(d.status),
                        ),
                        const SizedBox(width: 12),
                        WebBattery(level: d.batteryLevel, width: 56),
                      ],
                    ),
                  ),
              ],
            ),
    );

    final week = WebPanel(
      title: 'Deliveries this week',
      child: WebWeekChart(deliveries: deliveries),
    );

    final recent = WebPanel(
      title: 'Latest deliveries',
      action: WebButton(
        label: 'All deliveries',
        kind: WebButtonKind.ghost,
        dense: true,
        onPressed: () => context.go('/admin/deliveries'),
      ),
      child: deliveries.isEmpty
          ? const WebEmpty(
              icon: Icons.local_shipping_outlined,
              title: 'No deliveries yet',
              message: 'Deliveries appear here as soon as orders are placed.',
            )
          : WebTable<DeliveryModel>(
              rows: deliveries.take(6).toList(),
              onRowTap: (d) =>
                  context.push('/admin/deliveries/details?id=${d.id}'),
              columns: [
                WebColumn(
                  'Package',
                  (d) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.packageName.isEmpty ? 'Delivery' : d.packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WebText.label(size: 14),
                      ),
                      Text(ago(d.createdAt), style: WebText.body(size: 12)),
                    ],
                  ),
                  flex: 4,
                  primary: true,
                ),
                WebColumn(
                  'Route',
                  (d) => Text(
                    '${d.senderName} → ${d.dropoffLocationName ?? d.deliveryAddress}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: WebText.body(size: 13),
                  ),
                  flex: 4,
                ),
                WebColumn('Status', deliveryPill, flex: 2),
              ],
            ),
    );

    return WebPage(
      title: 'Command deck',
      subtitle: 'Fleet and deliveries across campus, live.',
      onRefresh: _refresh,
      actions: [
        WebButton(
          label: waiting == 0 ? 'Deliveries' : 'Review $waiting waiting',
          icon: Icons.local_shipping_outlined,
          onPressed: () => context.go('/admin/deliveries'),
        ),
        WebButton(
          label: 'Weather',
          icon: Icons.wb_sunny_outlined,
          kind: WebButtonKind.secondary,
          onPressed: () => context.go('/admin/weather'),
        ),
      ],
      children: [
        if (lowAlerts && low.isNotEmpty)
          WebWell(
            radius: 18,
            child: Row(
              children: [
                Icon(
                  Icons.battery_alert_rounded,
                  color: AppColors.readable(AppColors.danger),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${low.map((d) => d.name).join(', ')} '
                    '${low.length == 1 ? 'is' : 'are'} under 10% battery. '
                    'Recharge before accepting deliveries.',
                    style: WebText.label(size: 14),
                  ),
                ),
                WebButton(
                  label: 'Fleet',
                  kind: WebButtonKind.secondary,
                  dense: true,
                  onPressed: () => context.go('/admin/drones'),
                ),
              ],
            ),
          ),
        WebGrid(
          minTile: 210,
          children: [
            WebStat(
              label: 'In the air',
              value: '${flying.length}',
              icon: Icons.flight_takeoff_rounded,
              tone: AppColors.accent,
            ),
            WebStat(
              label: 'Waiting for approval',
              value: '$waiting',
              icon: Icons.pending_actions_rounded,
              tone: AppColors.warning,
              onTap: () => context.go('/admin/deliveries'),
            ),
            WebStat(
              label: 'Drones ready',
              value: '$ready / ${drones.length}',
              icon: Icons.battery_charging_full_rounded,
              tone: AppColors.success,
              onTap: () => context.go('/admin/drones'),
            ),
            WebStat(
              label: 'Delivered',
              value: rate,
              icon: Icons.verified_outlined,
              note: '$delivered of ${deliveries.length} deliveries',
            ),
          ],
        ),
        WebSplit(
          sideWidth: 380,
          breakpoint: 1060,
          main: radar,
          side: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [fleet, const SizedBox(height: 22), week],
          ),
        ),
        recent,
      ],
    );
  }
}
