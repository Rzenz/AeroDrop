import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/delivery_model.dart';
import '../../../../core/models/drone_model.dart';
import '../../../../core/providers/delivery_provider.dart';
import '../../../../core/providers/drone_provider.dart';
import '../../../../core/providers/weather_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../../../../core/widgets/shared_drone_radar.dart';
import '../web_kit.dart';
import '../web_status.dart';
import 'web_admin_dashboard_page.dart';

/// One delivery, for dispatch: the flight on the radar, the route and the
/// cargo, and the six readiness checks the app runs before a drone may take
/// it — with approve and reject when it is waiting.
class WebAdminDeliveryPage extends ConsumerStatefulWidget {
  const WebAdminDeliveryPage({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  ConsumerState<WebAdminDeliveryPage> createState() =>
      _WebAdminDeliveryPageState();
}

class _WebAdminDeliveryPageState extends ConsumerState<WebAdminDeliveryPage> {
  bool _busy = false;

  Future<void> _refresh() async {
    await ref.read(deliveryProvider.notifier).loadAdminDeliveriesFromSupabase();
    await ref.read(droneProvider.notifier).loadDronesFromSupabase();
  }

  void _back() =>
      context.canPop() ? context.pop() : context.go('/admin/deliveries');

  Future<void> _act(DeliveryModel d, {required bool accept}) async {
    if (!accept) {
      final ok = await showNeuConfirm(
        context,
        title: 'Reject this delivery?',
        message: 'The customer and the canteen are told it will not fly.',
        confirmLabel: 'Reject',
        destructive: true,
        icon: Icons.block_rounded,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    final n = ref.read(deliveryProvider.notifier);
    final err = accept
        ? await n.acceptDelivery(d.id)
        : await n.rejectDelivery(d.id);
    if (!mounted) return;
    setState(() => _busy = false);
    showNeuSnack(
      context,
      err == null
          ? (accept ? 'Approved — a drone is assigned.' : 'Delivery rejected.')
          : 'Could not ${accept ? 'approve' : 'reject'}: $err',
      tone: err == null ? NeuToneKind.success : NeuToneKind.error,
    );
    if (err == null) _back();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref
        .watch(deliveryProvider)
        .where((x) => x.id == widget.deliveryId)
        .firstOrNull;
    final drones = ref.watch(droneProvider);
    final weather = ref.watch(weatherProvider);

    if (d == null) {
      return WebPage(
        title: 'Delivery',
        back: true,
        onBack: _back,
        onRefresh: _refresh,
        children: const [
          WebEmpty(
            icon: Icons.local_shipping_outlined,
            title: 'Delivery not found',
            message: 'It may still be loading, or it was removed.',
          ),
        ],
      );
    }

    var pickup = d.pickupLocationName ?? d.senderName;
    var dropoff = d.dropoffLocationName ?? d.deliveryAddress;
    final a = d.deliveryAddress;
    if (a.startsWith('From ') && a.contains(' to ')) {
      pickup = a.substring(5, a.indexOf(' to '));
      dropoff = a.substring(a.indexOf(' to ') + 4);
    }
    final drone = d.droneId == null
        ? null
        : drones.where((x) => x.id == d.droneId).firstOrNull;

    final hasItems =
        d.packageName.isNotEmpty &&
        d.packageName != 'No package items available.';
    final weightOk = d.packageWeight > 0 && d.packageWeight <= 0.5;
    final routeOk =
        pickup.isNotEmpty && dropoff.isNotEmpty && dropoff != 'Unknown';
    final weatherOk = !weather.isGrounded;
    final droneOk =
        d.droneId != null ||
        drones.any((x) => x.status == DroneStatus.available);
    final checks = [
      (
        'Order record',
        d.id.isNotEmpty ? 'Order ${orderRef(d.id)}' : 'Missing',
        d.id.isNotEmpty,
      ),
      (
        'Contents listed',
        hasItems ? d.packageName : 'Nothing listed',
        hasItems,
      ),
      (
        'Under the payload limit',
        '${(d.packageWeight * 1000).round()} g of 500 g',
        weightOk,
      ),
      ('Valid route', '$pickup → $dropoff', routeOk),
      (
        'Weather',
        weatherOk
            ? 'Safe to fly (${weather.weatherStatus})'
            : 'Grounded (${weather.weatherStatus})',
        weatherOk,
      ),
      (
        'A drone to carry it',
        d.droneId != null
            ? 'Assigned: ${d.droneId}'
            : (droneOk ? 'One is available' : 'None available'),
        droneOk,
      ),
    ];
    final ready = checks.every((c) => c.$3);
    final waiting = d.status == DeliveryStatus.pending;

    final radar = WebPanel(
      padding: const EdgeInsets.all(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 400,
          child: SharedDroneRadar(delivery: d, title: deliveryLabel(d.status)),
        ),
      ),
    );

    final route = WebPanel(
      title: 'Route and cargo',
      child: Column(
        children: [
          WebKeyValue('From', '${d.senderName} · $pickup'),
          WebKeyValue('To', dropoff),
          WebKeyValue('Recipient', d.recipientName),
          if (d.recipientPhone.isNotEmpty)
            WebKeyValue('Phone', d.recipientPhone),
          const WebGroove(),
          WebKeyValue('Package', d.packageName),
          WebKeyValue('Type', d.packageType),
          WebKeyValue('Weight', '${(d.packageWeight * 1000).round()} g'),
          if (d.estimatedDistanceKm != null)
            WebKeyValue(
              'Distance',
              '${d.estimatedDistanceKm!.toStringAsFixed(2)} km',
            ),
          if (d.paymentAmount != null)
            WebKeyValue('Payment', WebText.peso(d.paymentAmount!)),
        ],
      ),
    );

    final readiness = WebPanel(
      title: 'Ready to dispatch?',
      action: WebPill(
        label: ready ? 'Ready' : 'Blocked',
        tone: ready ? AppColors.success : AppColors.warning,
      ),
      depth: NeuDepth.medium,
      child: Column(
        children: [
          for (final c in checks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    c.$3
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    size: 20,
                    color: AppColors.readable(
                      c.$3 ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.$1, style: WebText.label(size: 14)),
                        Text(c.$2, style: WebText.body(size: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    final status = WebPanel(
      title: 'Status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: deliveryPill(d)),
          const SizedBox(height: 10),
          WebKeyValue('Created', shortDate(d.createdAt)),
          if (d.deliveryStartedAt != null)
            WebKeyValue('Took off', shortDate(d.deliveryStartedAt!)),
          if (d.deliveredAt != null)
            WebKeyValue('Landed', shortDate(d.deliveredAt!)),
          if (d.status == DeliveryStatus.cancelled)
            WebKeyValue('Reason', d.cancellationReasonDisplay),
          if (drone != null) ...[
            const WebGroove(),
            WebKeyValue('Drone', drone.name),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Battery', style: WebText.body(size: 14)),
                  ),
                  WebBattery(level: drone.batteryLevel),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return WebPage(
      title: d.packageName.isEmpty
          ? 'Delivery ${orderRef(d.id)}'
          : d.packageName,
      subtitle: 'Delivery ${orderRef(d.id)} · ${deliveryLabel(d.status)}',
      back: true,
      onBack: _back,
      onRefresh: _refresh,
      actions: [
        if (waiting)
          WebButton(
            label: 'Reject',
            kind: WebButtonKind.secondary,
            onPressed: _busy ? null : () => _act(d, accept: false),
          ),
        if (waiting)
          WebButton(
            label: 'Approve & dispatch',
            icon: Icons.flight_takeoff_rounded,
            loading: _busy,
            onPressed: ready ? () => _act(d, accept: true) : null,
          ),
      ],
      children: [
        WebSplit(
          sideWidth: 380,
          breakpoint: 1040,
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [radar, const SizedBox(height: 22), route],
          ),
          side: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [readiness, const SizedBox(height: 22), status],
          ),
        ),
      ],
    );
  }
}
