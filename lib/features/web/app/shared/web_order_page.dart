import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/models/delivery_model.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/delivery_provider.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/providers/order_provider.dart';
import '../../../../core/providers/vendor_provider.dart';
import '../../../../core/services/delivery_fee_calculator.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../../../orders/order_details_screen.dart' show orderDetailsProvider;
import '../../../orders/receipt_screen.dart';
import '../../../orders/widgets/order_review_dialog.dart';
import '../web_kit.dart';
import '../web_status.dart';

/// One order, for the customer who placed it or the canteen fulfilling it —
/// the app's order screen, laid out as a record: the status track across the
/// top, the items and the drone beside the money and the delivery details,
/// and the actions in the page header. It follows the order live.
class WebOrderPage extends ConsumerStatefulWidget {
  const WebOrderPage({super.key, required this.orderId, this.vendor = false});

  final String orderId;

  /// Opened from the vendor area.
  final bool vendor;

  @override
  ConsumerState<WebOrderPage> createState() => _WebOrderPageState();
}

class _WebOrderPageState extends ConsumerState<WebOrderPage> {
  RealtimeChannel? _orders;
  RealtimeChannel? _deliveries;

  @override
  void initState() {
    super.initState();
    _listen();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(vendorProvider).vendors.isEmpty) {
        ref.read(vendorProvider.notifier).loadVendors();
      }
    });
  }

  @override
  void dispose() {
    _orders?.unsubscribe();
    _deliveries?.unsubscribe();
    super.dispose();
  }

  void _listen() {
    if (!SupabaseService.isConfigured || widget.orderId.isEmpty) return;
    try {
      final client = SupabaseService.client;
      _orders = client
          .channel('web_order_orders:${widget.orderId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: widget.orderId,
            ),
            callback: (_) {
              if (!mounted) return;
              ref.invalidate(orderDetailsProvider(widget.orderId));
              ref.read(orderProvider.notifier).loadOrders();
              ref.read(vendorOrdersProvider.notifier).loadOrders();
            },
          )
          .subscribe();
      _deliveries = client
          .channel('web_order_deliveries:${widget.orderId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'deliveries',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'order_id',
              value: widget.orderId,
            ),
            callback: (_) {
              if (!mounted) return;
              ref.invalidate(orderDetailsProvider(widget.orderId));
              ref.read(deliveryProvider.notifier).loadDeliveriesFromSupabase();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Web order realtime: $e');
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(orderDetailsProvider(widget.orderId));
    await ref.read(orderProvider.notifier).loadOrders();
    await ref.read(vendorOrdersProvider.notifier).loadOrders();
    await ref.read(deliveryProvider.notifier).loadDeliveriesFromSupabase();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(widget.vendor ? '/vendor/orders' : '/user/orders');
    }
  }

  Future<void> _cancel(OrderModel o) async {
    final ok = await showNeuConfirm(
      context,
      title: 'Cancel this order?',
      message:
          'The canteen stops preparing it. A full simulated refund of '
          '${WebText.peso(o.totalAmount)} is credited back straight away.',
      confirmLabel: 'Cancel order',
      cancelLabel: 'Keep order',
      destructive: true,
      icon: Icons.cancel_outlined,
    );
    if (!ok || !mounted) return;
    final done = await ref
        .read(orderProvider.notifier)
        .cancelOrder(
          o.id,
          cancellationReason: 'Customer cancelled from order details',
        );
    if (!mounted) return;
    if (done) ref.invalidate(orderDetailsProvider(o.id));
    showNeuSnack(
      context,
      done
          ? 'Order cancelled. The refund is on its way.'
          : 'This order could not be cancelled — it may already be packed '
                'or in flight.',
      tone: done ? NeuToneKind.success : NeuToneKind.error,
    );
  }

  static String _method(String method, {String? channel}) {
    if (method.toLowerCase() == 'xendit_online') {
      if (channel != null && channel.isNotEmpty) {
        final ch = channel.toUpperCase();
        if (ch.contains('GCASH')) return 'Online Payment (GCash)';
        if (ch.contains('CARD')) return 'Online Payment (Card)';
        return 'Online Payment ($channel)';
      }
      return 'Online Payment';
    }
    return switch (method.toLowerCase()) {
      'cash' || 'cash_on_delivery' => 'Cash on Delivery',
      'gcash_simulated' => 'GCash (Digital Payment)',
      'card' || 'card_simulated' => 'Credit / Debit Card',
      _ => method,
    };
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderDetailsProvider(widget.orderId));
    return async.when(
      loading: () => WebPage(
        title: 'Order ${orderRef(widget.orderId)}',
        back: true,
        onBack: _back,
        children: const [
          WebSkeleton(height: 110, radius: 22),
          WebSkeleton(height: 320, radius: 22),
        ],
      ),
      error: (e, _) => WebPage(
        title: 'Order ${orderRef(widget.orderId)}',
        back: true,
        onBack: _back,
        children: [
          WebEmpty(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load this order',
            message: '$e',
            action: WebButton(
              label: 'Try again',
              kind: WebButtonKind.secondary,
              onPressed: _refresh,
            ),
          ),
        ],
      ),
      data: (o) => o == null
          ? WebPage(
              title: 'Order ${orderRef(widget.orderId)}',
              back: true,
              onBack: _back,
              children: const [
                WebEmpty(
                  icon: Icons.receipt_long_outlined,
                  title: 'Order not found',
                  message:
                      'It may belong to another account, or it was removed.',
                ),
              ],
            )
          : _page(o),
    );
  }

  Widget _page(OrderModel o) {
    final deliveries = ref.watch(deliveryProvider);
    final live = deliveries
        .where((d) => d.id == o.deliveryId || d.id == widget.orderId)
        .firstOrNull;
    final delivered =
        o.effectiveStatus == 'delivered' ||
        o.deliveryStatus?.toLowerCase() == 'delivered' ||
        live?.status == DeliveryStatus.delivered;
    final status = delivered ? 'delivered' : o.effectiveStatus;
    final progress = delivered
        ? 1.0
        : (live?.progress ?? o.deliveryProgress ?? 0.0).clamp(0.0, 1.0);
    final deliveryId = o.deliveryId ?? live?.id;
    final hasDelivery = deliveryId != null && deliveryId.isNotEmpty;

    // The stored fee, explained from the canteen's and the pad's positions.
    final locations = ref.watch(campusLocationsProvider).value ?? [];
    final vendor = ref
        .watch(vendorProvider)
        .vendors
        .where((v) => v.id == o.vendorId)
        .firstOrNull;
    CampusLocation? from;
    if (vendor != null) {
      final id = vendor.campusLocationId;
      if (id != null && id.isNotEmpty) {
        from = locations.where((l) => l.id == id).firstOrNull;
      }
      if (from == null && vendor.building.isNotEmpty) {
        final b = vendor.building.toLowerCase();
        from = locations.where((l) {
          final n = l.name.toLowerCase();
          return n.contains(b) ||
              b.contains(n) ||
              l.locationCode.toLowerCase() == b;
        }).firstOrNull;
      }
    }
    final to = locations.where((l) => l.id == o.dropoffLocationId).firstOrNull;
    final fee = DeliveryFeeCalculator.recomputeStoredOrderFee(
      storedDeliveryFee: o.deliveryFee,
      distanceKm: DeliveryFeeCalculator.calculateDistanceKm(
        startLat: from?.latitude,
        startLng: from?.longitude,
        endLat: to?.latitude,
        endLng: to?.longitude,
      ),
      weightKg: o.totalWeightKg,
    );

    final cancellable = const [
      'pending',
      'confirmed',
      'preparing',
    ].contains(o.effectiveStatus.toLowerCase());
    final locked = const [
      'ready_for_delivery',
      'in_transit',
    ].contains(o.effectiveStatus.toLowerCase());
    final paid = delivered || o.paymentStatus.toLowerCase() == 'paid';

    void openReceipt() {
      context.push(
        widget.vendor ? '/vendor/receipt' : '/user/receipt',
        extra: ReceiptData(
          orderRef: o.id,
          vendorName: o.vendorName,
          customerName: widget.vendor ? o.customerName : null,
          customerPhone: o.customerPhone,
          lines: [
            for (final i in o.items)
              ReceiptLine(
                name: i.productName,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
              ),
          ],
          subtotal: o.subtotal > 0 ? o.subtotal : o.totalAmount - o.deliveryFee,
          deliveryFee: o.deliveryFee,
          feeBreakdown: fee,
          total: o.totalAmount,
          paymentLabel: _method(o.paymentMethod, channel: o.paymentChannel),
          placedAt: o.createdAt,
          dropoffName: o.dropoffLocationName,
          totalWeightGrams: o.totalWeightGrams,
          customerNote: o.notes,
          orderStatus: o.statusDisplay,
          deliveryId: deliveryId,
        ),
      );
    }

    final track = WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Status', style: WebText.title(size: 17))),
              orderPill(o),
            ],
          ),
          const SizedBox(height: 18),
          WebOrderTimeline(status: status),
        ],
      ),
    );

    final items = WebPanel(
      title: 'Items',
      subtitle: o.vendorName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final i in o.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  WebThumb(url: null, name: i.productName, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.productName, style: WebText.label(size: 14.5)),
                        Text(
                          '${i.quantity} × ${WebText.peso(i.unitPrice)}'
                          '${i.weightGrams > 0 ? ' · ${i.weightGrams * i.quantity} g' : ''}',
                          style: WebText.body(size: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    WebText.peso(i.unitPrice * i.quantity),
                    style: WebText.label(size: 14.5),
                  ),
                ],
              ),
            ),
          if (o.notes != null && o.notes!.isNotEmpty) ...[
            const WebGroove(),
            Text('Note for the canteen', style: WebText.body(size: 12.5)),
            const SizedBox(height: 4),
            Text(
              o.notes!,
              style: WebText.label(size: 14, weight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );

    final drone = !hasDelivery && o.droneId == null
        ? null
        : WebPanel(
            title: 'Drone delivery',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        delivered
                            ? 'Landed at ${o.dropoffLocationName ?? 'the pad'}'
                            : (status == 'in_transit'
                                  ? 'On its way to ${o.dropoffLocationName ?? 'the pad'}'
                                  : 'Waiting to take off'),
                        style: WebText.label(size: 14.5),
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: WebText.numeric(size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                NeuSurface(
                  style: NeuStyle.inset,
                  depth: NeuDepth.flat,
                  color: AppColors.surfaceSunken,
                  height: 10,
                  borderRadius: BorderRadius.circular(5),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress),
                    duration: const Duration(milliseconds: 600),
                    curve: const Cubic(0.2, 0, 0, 1),
                    builder: (context, v, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: v,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: delivered
                              ? AppColors.success
                              : AppColors.accentFill,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ),
                if (o.droneId != null) ...[
                  const SizedBox(height: 10),
                  WebKeyValue('Drone', o.droneId!),
                ],
              ],
            ),
          );

    final money = WebPanel(
      title: 'Payment',
      depth: NeuDepth.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WebKeyValue(
            'Subtotal',
            WebText.peso(
              o.subtotal > 0 ? o.subtotal : o.totalAmount - o.deliveryFee,
            ),
          ),
          WebKeyValue('Drone delivery', WebText.peso(o.deliveryFee)),
          if (fee?.breakdownText.isNotEmpty ?? false)
            Text(
              fee!.breakdownText,
              style: WebText.body(size: 12, color: AppColors.textTertiary),
            ),
          const WebGroove(),
          WebKeyValue('Total', WebText.peso(o.totalAmount), emphasis: true),
          const SizedBox(height: 8),
          WebKeyValue(
            'Method',
            _method(o.paymentMethod, channel: o.paymentChannel),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: Text('Status', style: WebText.body(size: 14))),
                WebPill(
                  label: delivered ? 'Paid' : o.formattedPaymentStatus,
                  tone: paid
                      ? AppColors.success
                      : (const [
                              'expired',
                              'failed',
                            ].contains(o.paymentStatus.toLowerCase())
                            ? AppColors.danger
                            : AppColors.warning),
                ),
              ],
            ),
          ),
          if (o.paymentReference?.isNotEmpty ?? false)
            WebKeyValue('Reference', o.paymentReference!),
          if (o.isPendingOnlinePayment && !widget.vendor) ...[
            const SizedBox(height: 12),
            WebButton(
              label: 'Complete online payment',
              icon: Icons.open_in_new_rounded,
              expand: true,
              onPressed: () => context.push(
                '/user/payment-waiting?orderId=${o.id}'
                '${o.paymentInvoiceUrl != null ? '&invoiceUrl=${Uri.encodeComponent(o.paymentInvoiceUrl!)}' : ''}',
              ),
            ),
          ],
        ],
      ),
    );

    final details = WebPanel(
      title: 'Delivery',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WebKeyValue('Placed', shortDate(o.createdAt)),
          WebKeyValue('From', o.vendorName),
          WebKeyValue('Lands at', o.dropoffLocationName ?? '—'),
          WebKeyValue('Cargo', '${o.totalWeightGrams} g of 500 g'),
          if (widget.vendor) ...[
            WebKeyValue('Customer', o.customerName),
            if (o.customerPhone.isNotEmpty)
              WebKeyValue('Phone', o.customerPhone),
          ],
        ],
      ),
    );

    final actions = <Widget>[
      if (hasDelivery)
        WebButton(
          label: widget.vendor ? 'Track delivery' : 'Track my order',
          icon: Icons.navigation_rounded,
          onPressed: () => context.push(
            widget.vendor
                ? '/vendor/track/details?id=$deliveryId'
                : '/user/track/details?id=$deliveryId',
          ),
        ),
      if (delivered && !widget.vendor)
        WebButton(
          label: 'Rate & review',
          icon: Icons.star_outline_rounded,
          onPressed: () => OrderReviewDialog.show(context, order: o),
        ),
      WebButton(
        label: 'Receipt',
        icon: Icons.receipt_long_outlined,
        kind: WebButtonKind.secondary,
        onPressed: openReceipt,
      ),
      WebButton(
        label: 'Get help',
        icon: Icons.support_agent_rounded,
        kind: WebButtonKind.secondary,
        onPressed: () => context.push(
          '/shared/help?orderId=${o.id}'
          '${hasDelivery ? '&deliveryId=$deliveryId' : ''}',
        ),
      ),
    ];

    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        money,
        const SizedBox(height: 20),
        details,
        if (!widget.vendor && (cancellable || locked)) ...[
          const SizedBox(height: 20),
          if (cancellable)
            WebButton(
              label: 'Cancel order',
              icon: Icons.cancel_outlined,
              kind: WebButtonKind.danger,
              expand: true,
              onPressed: () => _cancel(o),
            )
          else
            WebWell(
              radius: 16,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Packed or in flight — it can no longer be cancelled.',
                      style: WebText.body(size: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );

    return WebPage(
      title: 'Order ${orderRef(o.id)}',
      subtitle: '${o.vendorName} · ${shortDate(o.createdAt)}',
      back: true,
      onBack: _back,
      onRefresh: _refresh,
      actions: actions,
      children: [
        track,
        WebSplit(
          sideWidth: 380,
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              items,
              if (drone != null) ...[const SizedBox(height: 22), drone],
            ],
          ),
          side: side,
        ),
      ],
    );
  }
}
