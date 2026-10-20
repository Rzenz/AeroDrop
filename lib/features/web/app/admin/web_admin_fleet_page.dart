import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/drone_model.dart';
import '../../../../core/providers/drone_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../web_kit.dart';
import 'web_admin_dashboard_page.dart';

/// The fleet as cards: each drone's state, battery, payload and position,
/// and the one action that writes to the fleet — recharging.
///
/// The app's fleet sheet also offers status buttons and "Decommission"; the
/// first only changes what that screen shows and the second reports a
/// success without doing anything, so neither is offered here.
class WebAdminFleetPage extends ConsumerStatefulWidget {
  const WebAdminFleetPage({super.key});

  @override
  ConsumerState<WebAdminFleetPage> createState() => _WebAdminFleetPageState();
}

class _WebAdminFleetPageState extends ConsumerState<WebAdminFleetPage> {
  final _charging = <String>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(droneProvider.notifier).loadDronesFromSupabase(),
    );
  }

  Future<void> _recharge(DroneModel d) async {
    setState(() => _charging.add(d.id));
    final err = await ref.read(droneProvider.notifier).rechargeDrone(d.id);
    if (!mounted) return;
    setState(() => _charging.remove(d.id));
    showNeuSnack(
      context,
      err == null ? '${d.name} recharged to 100%.' : 'Could not recharge: $err',
      tone: err == null ? NeuToneKind.success : NeuToneKind.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final drones = ref.watch(droneProvider);
    int count(bool Function(DroneModel) f) => drones.where(f).length;
    final ready = count((d) => d.status == DroneStatus.available);
    final flying = count(
      (d) =>
          d.status == DroneStatus.busy ||
          d.status == DroneStatus.assigned ||
          d.status == DroneStatus.returning,
    );
    final down = count(
      (d) =>
          d.status == DroneStatus.maintenance ||
          d.status == DroneStatus.offline ||
          d.status == DroneStatus.charging,
    );
    final lowAlerts = ref.watch(lowBatteryAlertsProvider);

    return WebPage(
      title: 'Fleet',
      subtitle:
          '${drones.length} ${drones.length == 1 ? 'drone' : 'drones'} registered',
      onRefresh: () =>
          ref.read(droneProvider.notifier).loadDronesFromSupabase(),
      children: [
        WebGrid(
          minTile: 210,
          maxColumns: 3,
          children: [
            WebStat(
              label: 'Ready to fly',
              value: '$ready',
              icon: Icons.check_circle_outline_rounded,
              tone: AppColors.success,
            ),
            WebStat(
              label: 'Flying or returning',
              value: '$flying',
              icon: Icons.flight_takeoff_rounded,
              tone: AppColors.accent,
            ),
            WebStat(
              label: 'Charging or grounded',
              value: '$down',
              icon: Icons.build_circle_outlined,
              tone: AppColors.warning,
            ),
          ],
        ),
        if (drones.isEmpty)
          const WebEmpty(
            icon: Icons.flight_outlined,
            title: 'No drones registered',
            message: 'Drones appear here once they are added to the fleet.',
          )
        else
          WebGrid(
            minTile: 300,
            maxColumns: 3,
            children: [
              for (final d in drones)
                _DroneCard(
                  drone: d,
                  warn: lowAlerts && d.batteryLevel < 10,
                  charging: _charging.contains(d.id),
                  onRecharge: () => _recharge(d),
                ),
            ],
          ),
      ],
    );
  }
}

class _DroneCard extends StatelessWidget {
  const _DroneCard({
    required this.drone,
    required this.warn,
    required this.charging,
    required this.onRecharge,
  });

  final DroneModel drone;
  final bool warn;
  final bool charging;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) {
    final d = drone;
    final flying = d.status == DroneStatus.busy;
    return WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              NeuSurface(
                style: NeuStyle.inset,
                color: AppColors.surfaceSunken,
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(15),
                alignment: Alignment.center,
                child: Icon(
                  Icons.flight_rounded,
                  size: 24,
                  color: AppColors.readable(droneTone(d.status)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, style: WebText.title(size: 16.5)),
                    Text(d.modelType, style: WebText.body(size: 12.5)),
                  ],
                ),
              ),
              WebPill(label: droneLabel(d.status), tone: droneTone(d.status)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Text('Battery', style: WebText.body(size: 13.5))),
              WebBattery(level: d.batteryLevel, width: 120),
            ],
          ),
          const SizedBox(height: 6),
          WebKeyValue('Max payload', '${(d.maxPayload * 1000).round()} g'),
          WebKeyValue(
            'Position',
            d.currentCoordinates.isEmpty ? '—' : d.currentCoordinates,
          ),
          if (warn) ...[
            const SizedBox(height: 8),
            Text(
              'Under 10% — recharge before it takes another delivery.',
              style: WebText.body(
                size: 12.5,
                color: AppColors.readable(AppColors.danger),
              ),
            ),
          ],
          const SizedBox(height: 14),
          WebButton(
            label: flying
                ? 'In flight'
                : (d.batteryLevel >= 100 ? 'Fully charged' : 'Recharge'),
            icon: Icons.battery_charging_full_rounded,
            kind: WebButtonKind.secondary,
            expand: true,
            loading: charging,
            onPressed: flying || d.batteryLevel >= 100 ? null : onRecharge,
          ),
        ],
      ),
    );
  }
}
