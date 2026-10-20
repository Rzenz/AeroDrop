import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/delivery_model.dart';
import '../../../../core/providers/delivery_provider.dart';
import '../../../../core/providers/telemetry_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../../../../core/widgets/shared_drone_radar.dart';
import '../admin/web_admin_dashboard_page.dart' show WebBattery;
import '../web_kit.dart';
import '../web_status.dart';

/// A delivery not in the loaded list — opened from a notification — read
/// from the deliveries table as the app's flight screen does.
final webDeliveryByIdProvider = FutureProvider.autoDispose
    .family<DeliveryModel?, String>((ref, id) async {
      final cached = ref
          .watch(deliveryProvider)
          .where((d) => d.id == id)
          .firstOrNull;
      if (cached != null) return cached;
      if (!SupabaseService.isConfigured) return null;
      final r = await SupabaseService.client
          .from('deliveries')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (r == null) return null;
      final raw = r['status']?.toString().toLowerCase();
      final status = switch (raw) {
        'delivered' => DeliveryStatus.delivered,
        'intransit' || 'in_transit' => DeliveryStatus.inTransit,
        'assigning' => DeliveryStatus.assigning,
        'cancelled' => DeliveryStatus.cancelled,
        _ => DeliveryStatus.pending,
      };
      DateTime? at(String k) =>
          r[k] == null ? null : DateTime.tryParse(r[k].toString());
      return DeliveryModel(
        id: r['id'].toString(),
        senderName: r['sender_name']?.toString() ?? 'Unknown sender',
        recipientName: r['recipient_name']?.toString() ?? 'Unknown recipient',
        recipientPhone: r['recipient_phone']?.toString() ?? '',
        deliveryAddress: r['delivery_address']?.toString() ?? '',
        packageName: r['package_name']?.toString() ?? 'AeroDrop package',
        packageWeight: (r['package_weight'] as num?)?.toDouble() ?? 0,
        packageType: r['package_type']?.toString() ?? 'Other',
        status: status,
        droneId: r['drone_id']?.toString(),
        eta: r['eta']?.toString() ?? '',
        createdAt: at('created_at') ?? DateTime.now(),
        progress: status == DeliveryStatus.delivered
            ? 1
            : ((r['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
        estimatedDistanceKm: (r['estimated_distance_km'] as num?)?.toDouble(),
        paymentAmount: (r['payment_amount'] as num?)?.toDouble(),
        deliveryStartedAt: at('delivery_started_at'),
        estimatedDeliverySeconds:
            (r['estimated_delivery_seconds'] as num?)?.toInt() ?? 60,
        deliveredAt: at('delivered_at'),
      );
    });

/// One flight, followed live: the radar, how far along it is, the drone's
/// own telemetry, and the route — for the customer who ordered it or the
/// canteen that sent it.
class WebFlightPage extends ConsumerStatefulWidget {
  const WebFlightPage({
    super.key,
    required this.deliveryId,
    this.vendor = false,
  });

  final String deliveryId;
  final bool vendor;

  @override
  ConsumerState<WebFlightPage> createState() => _WebFlightPageState();
}

class _WebFlightPageState extends ConsumerState<WebFlightPage> {
  bool _cancelling = false;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(widget.vendor ? '/vendor/orders' : '/user/track');
    }
  }

  Future<void> _cancel() async {
    final ok = await showNeuConfirm(
      context,
      title: 'Cancel this delivery?',
      message: 'It is marked cancelled and kept in your history.',
      confirmLabel: 'Cancel delivery',
      cancelLabel: 'Keep it',
      destructive: true,
      icon: Icons.cancel_outlined,
    );
    if (!ok || !mounted) return;
    setState(() => _cancelling = true);
    final err = await ref
        .read(deliveryProvider.notifier)
        .cancelDeliveryRequest(widget.deliveryId);
    if (!mounted) return;
    setState(() => _cancelling = false);
    showNeuSnack(
      context,
      err ?? 'Delivery cancelled.',
      tone: err == null ? NeuToneKind.success : NeuToneKind.error,
    );
    if (err == null) ref.invalidate(webDeliveryByIdProvider(widget.deliveryId));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(webDeliveryByIdProvider(widget.deliveryId));
    return async.when(
      loading: () => WebPage(
        title: 'Flight',
        back: true,
        onBack: _back,
        children: const [WebSkeleton(height: 420, radius: 24)],
      ),
      error: (e, _) => WebPage(
        title: 'Flight',
        back: true,
        onBack: _back,
        children: [
          WebEmpty(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load this flight',
            message: '$e',
          ),
        ],
      ),
      data: (d) => d == null
          ? WebPage(
              title: 'Flight',
              back: true,
              onBack: _back,
              children: const [
                WebEmpty(
                  icon: Icons.flight_outlined,
                  title: 'Flight not found',
                  message: 'It may belong to another account.',
                ),
              ],
            )
          : _page(d),
    );
  }

  Widget _page(DeliveryModel d) {
    final t = ref.watch(deliveryTelemetryProvider(d.id));
    final delivered = d.status == DeliveryStatus.delivered;
    final progress = delivered ? 1.0 : d.progress.clamp(0.0, 1.0);
    String v(double? x, String unit, [int digits = 0]) =>
        x == null ? '—' : '${x.toStringAsFixed(digits)} $unit';

    final radar = WebPanel(
      padding: const EdgeInsets.all(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 460,
          child: SharedDroneRadar(delivery: d, title: deliveryLabel(d.status)),
        ),
      ),
    );

    final eta = WebPanel(
      depth: NeuDepth.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivered
                          ? 'Landed'
                          : (d.eta.isEmpty ? deliveryLabel(d.status) : d.eta),
                      style: WebText.display(28),
                    ),
                    Text(
                      delivered
                          ? (d.deliveredAt == null
                                ? 'Delivered'
                                : 'At ${shortDate(d.deliveredAt!)}')
                          : 'Estimated arrival',
                      style: WebText.body(size: 13.5),
                    ),
                  ],
                ),
              ),
              deliveryPill(d),
            ],
          ),
          const SizedBox(height: 16),
          NeuSurface(
            style: NeuStyle.inset,
            depth: NeuDepth.flat,
            color: AppColors.surfaceSunken,
            height: 12,
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 600),
              builder: (context, x, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: x,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: delivered ? AppColors.success : AppColors.accentFill,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).round()}% of the way',
            style: WebText.body(size: 12.5),
          ),
          if (!widget.vendor && d.status == DeliveryStatus.pending) ...[
            const SizedBox(height: 16),
            WebButton(
              label: 'Cancel delivery',
              icon: Icons.cancel_outlined,
              kind: WebButtonKind.danger,
              expand: true,
              loading: _cancelling,
              onPressed: _cancel,
            ),
          ],
        ],
      ),
    );

    final telemetry = WebPanel(
      title: 'Drone',
      subtitle: d.droneId ?? 'Not assigned yet',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: Text('Battery', style: WebText.body(size: 14))),
                if (t?.batteryLevel != null)
                  WebBattery(level: t!.batteryLevel!)
                else
                  Text('—', style: WebText.label(size: 14)),
              ],
            ),
          ),
          WebKeyValue('Speed', v(t?.speed, 'km/h', 1)),
          WebKeyValue('Altitude', v(t?.altitude, 'm')),
          WebKeyValue('Signal', v(t?.signalStrength, '%')),
          WebKeyValue('Heading', v(t?.heading, '°')),
          if (t != null) WebKeyValue('Last report', ago(t.recordedAt)),
        ],
      ),
    );

    final route = WebPanel(
      title: 'Route',
      child: Column(
        children: [
          WebKeyValue('From', d.senderName),
          WebKeyValue('To', d.dropoffLocationName ?? d.deliveryAddress),
          WebKeyValue('For', d.recipientName),
          WebKeyValue('Package', d.packageName),
          WebKeyValue('Weight', '${(d.packageWeight * 1000).round()} g'),
          if (d.estimatedDistanceKm != null)
            WebKeyValue(
              'Distance',
              '${d.estimatedDistanceKm!.toStringAsFixed(2)} km',
            ),
        ],
      ),
    );

    return WebPage(
      title: delivered ? 'Delivery complete' : 'Live flight',
      subtitle: '${d.packageName} · ${orderRef(d.id)}',
      back: true,
      onBack: _back,
      onRefresh: () async {
        await ref.read(deliveryProvider.notifier).loadDeliveriesFromSupabase();
        ref.invalidate(webDeliveryByIdProvider(widget.deliveryId));
      },
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
            children: [eta, const SizedBox(height: 22), telemetry],
          ),
        ),
      ],
    );
  }
}
