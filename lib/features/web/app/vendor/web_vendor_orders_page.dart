import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/order_model.dart';
import '../../../../core/providers/order_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../web_kit.dart';
import '../web_status.dart';

/// The board's columns: what the canteen does next, left to right.
const vendorLanes = <(String, String, List<String>)>[
  ('New', 'Accept or reject', ['pending']),
  ('Accepted', 'Start preparing', ['confirmed']),
  ('Preparing', 'Mark ready when packed', ['preparing']),
  (
    'Ready',
    'Waiting for the drone',
    ['ready_for_delivery', 'ready', 'ready_for_pickup'],
  ),
  ('In flight', 'On its way', ['in_transit', 'out_for_delivery', 'picked_up']),
];

const _history = ['delivered', 'cancelled', 'rejected', 'failed'];

/// A canteen's order, with the one action that moves it along — the app's
/// dispatch card, as a board card.
class WebVendorOrderCard extends ConsumerStatefulWidget {
  const WebVendorOrderCard({super.key, required this.order});
  final OrderModel order;

  @override
  ConsumerState<WebVendorOrderCard> createState() => _WebVendorOrderCardState();
}

class _WebVendorOrderCardState extends ConsumerState<WebVendorOrderCard> {
  bool _busy = false;

  Future<void> _set(String next) async {
    if (_busy) return;
    if (next == 'cancelled') {
      final ok = await showNeuConfirm(
        context,
        title: 'Reject this order?',
        message:
            'The customer is told it was rejected and is refunded. This '
            'cannot be undone.',
        confirmLabel: 'Reject order',
        destructive: true,
        icon: Icons.block_rounded,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    final ok = await ref
        .read(vendorOrdersProvider.notifier)
        .updateOrderStatus(widget.order.id, next, cancellationReason: 'vendor');
    if (!mounted) return;
    setState(() => _busy = false);
    showNeuSnack(
      context,
      ok
          ? switch (next) {
              'confirmed' => 'Order accepted.',
              'preparing' => 'Preparing — mark it ready when it is packed.',
              'cancelled' => 'Order rejected.',
              _ => 'Order updated.',
            }
          : 'The order could not be updated. Try again.',
      tone: ok ? NeuToneKind.success : NeuToneKind.error,
    );
  }

  Future<void> _ready() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    final r = await ref
        .read(vendorOrdersProvider.notifier)
        .markOrderReady(widget.order.id);
    if (!mounted) return;
    setState(() => _busy = false);
    showNeuSnack(
      context,
      r.message,
      tone: !r.success
          ? NeuToneKind.error
          : (r.droneDispatched ? NeuToneKind.success : NeuToneKind.info),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final s = o.effectiveStatus;
    final waitingForDrone =
        s == 'ready_for_delivery' &&
        (o.deliveryStatus == null ||
            o.deliveryStatus!.toLowerCase() == 'pending');
    final count = o.items.fold<int>(0, (n, i) => n + i.quantity);

    final List<Widget> actions = switch (s) {
      'pending' => [
        Expanded(
          child: WebButton(
            label: 'Accept',
            icon: Icons.check_rounded,
            dense: true,
            expand: true,
            loading: _busy,
            onPressed: () => _set('confirmed'),
          ),
        ),
        const SizedBox(width: 8),
        WebButton(
          label: 'Reject',
          kind: WebButtonKind.ghost,
          dense: true,
          onPressed: _busy ? null : () => _set('cancelled'),
        ),
      ],
      'confirmed' => [
        Expanded(
          child: WebButton(
            label: 'Start preparing',
            icon: Icons.soup_kitchen_outlined,
            dense: true,
            expand: true,
            loading: _busy,
            onPressed: () => _set('preparing'),
          ),
        ),
      ],
      'preparing' => [
        Expanded(
          child: WebButton(
            label: 'Mark ready',
            icon: Icons.inventory_2_outlined,
            dense: true,
            expand: true,
            loading: _busy,
            onPressed: _ready,
          ),
        ),
      ],
      _ when waitingForDrone => [
        Expanded(
          child: WebButton(
            label: 'Dispatch drone',
            icon: Icons.flight_takeoff_rounded,
            dense: true,
            expand: true,
            loading: _busy,
            onPressed: _ready,
          ),
        ),
      ],
      _ => const [],
    };

    return WebHoverCard(
      onTap: () => context.push('/vendor/orders/${o.id}'),
      radius: 18,
      padding: const EdgeInsets.all(14),
      semanticLabel: 'Order ${orderRef(o.id)}, ${o.statusDisplay}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(orderRef(o.id), style: WebText.label(size: 14)),
              ),
              Text(
                ago(o.createdAt),
                style: WebText.body(size: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final i in o.items.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '${i.quantity} × ${i.productName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WebText.body(size: 13, color: AppColors.textPrimary),
              ),
            ),
          if (o.items.length > 3)
            Text(
              '+${o.items.length - 3} more',
              style: WebText.body(size: 12.5),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  o.dropoffLocationName ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WebText.body(size: 12.5),
                ),
              ),
              Text(
                '$count · ${WebText.peso(o.totalAmount)}',
                style: WebText.label(size: 13),
              ),
            ],
          ),
          if (o.notes != null && o.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            WebWell(
              radius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                '“${o.notes!}”',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: WebText.body(size: 12.5, color: AppColors.textPrimary),
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: actions),
          ],
        ],
      ),
    );
  }
}

class WebVendorOrdersPage extends ConsumerStatefulWidget {
  const WebVendorOrdersPage({super.key});

  @override
  ConsumerState<WebVendorOrdersPage> createState() =>
      _WebVendorOrdersPageState();
}

class _WebVendorOrdersPageState extends ConsumerState<WebVendorOrdersPage> {
  int _view = 0; // 0 board, 1 history
  int _lane = 0; // the lane on a phone

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(vendorOrdersProvider.notifier).loadOrders(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vendorOrdersProvider);
    final all = [...state.orders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    List<OrderModel> lane(List<String> keys) =>
        all.where((o) => keys.contains(o.effectiveStatus)).toList();
    final history = all
        .where((o) => _history.contains(o.effectiveStatus))
        .toList();
    final waiting = lane(['pending']).length;

    Widget board() => LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 760) {
          final l = vendorLanes[_lane];
          final orders = lane(l.$3);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WebTabs(
                labels: [for (final l in vendorLanes) l.$1],
                counts: [for (final l in vendorLanes) lane(l.$3).length],
                selected: _lane,
                onSelected: (i) => setState(() => _lane = i),
              ),
              const SizedBox(height: 16),
              if (orders.isEmpty)
                WebEmpty(
                  icon: Icons.inbox_outlined,
                  title: 'Nothing here',
                  message: l.$2,
                )
              else
                for (final o in orders) ...[
                  WebVendorOrderCard(key: ValueKey(o.id), order: o),
                  const SizedBox(height: 12),
                ],
            ],
          );
        }
        // As many columns per row as fit at 216px or wider; the rest wrap
        // onto the next row rather than running off the page.
        const gap = 16.0;
        final perRow = ((box.maxWidth + gap) / (216 + gap)).floor().clamp(
          2,
          vendorLanes.length,
        );
        final laneWidth = (box.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final l in vendorLanes)
              SizedBox(
                width: laneWidth,
                child: _Lane(title: l.$1, hint: l.$2, orders: lane(l.$3)),
              ),
          ],
        );
      },
    );

    Widget historyTable() => history.isEmpty
        ? const WebEmpty(
            icon: Icons.history_rounded,
            title: 'No finished orders yet',
            message: 'Delivered and cancelled orders are kept here.',
          )
        : WebTable<OrderModel>(
            rows: history,
            onRowTap: (o) => context.push('/vendor/orders/${o.id}'),
            columns: [
              WebColumn(
                'Order',
                (o) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(orderRef(o.id), style: WebText.label(size: 14.5)),
                    Text(
                      shortDate(o.createdAt),
                      style: WebText.body(size: 12.5),
                    ),
                  ],
                ),
                flex: 2,
                primary: true,
              ),
              WebColumn(
                'Customer',
                (o) => Text(
                  o.customerName,
                  style: WebText.label(size: 14, weight: FontWeight.w500),
                ),
                flex: 2,
              ),
              WebColumn(
                'Items',
                (o) => Text(
                  o.items
                      .map((i) => '${i.quantity}× ${i.productName}')
                      .join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: WebText.body(size: 13.5),
                ),
                flex: 4,
              ),
              WebColumn(
                'Total',
                (o) => Text(
                  WebText.peso(o.totalAmount),
                  style: WebText.label(size: 14.5),
                ),
                flex: 2,
                align: Alignment.centerRight,
              ),
              WebColumn('Status', orderPill, flex: 2),
            ],
          );

    return WebPage(
      title: 'Orders',
      subtitle: waiting == 0
          ? 'Nothing waiting on you.'
          : '$waiting new ${waiting == 1 ? 'order' : 'orders'} to accept',
      onRefresh: () => ref.read(vendorOrdersProvider.notifier).loadOrders(),
      actions: [
        WebTabs(
          labels: const ['Board', 'History'],
          counts: [all.length - history.length, history.length],
          selected: _view,
          onSelected: (i) => setState(() => _view = i),
        ),
      ],
      children: [
        if (state.isLoading && all.isEmpty)
          const WebSkeleton(height: 360, radius: 22)
        else if (state.errorMessage != null && all.isEmpty)
          WebEmpty(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load your orders',
            message: state.errorMessage!,
            action: WebButton(
              label: 'Try again',
              kind: WebButtonKind.secondary,
              onPressed: () =>
                  ref.read(vendorOrdersProvider.notifier).loadOrders(),
            ),
          )
        else if (_view == 0)
          board()
        else
          historyTable(),
      ],
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({required this.title, required this.hint, required this.orders});

  final String title;
  final String hint;
  final List<OrderModel> orders;

  @override
  Widget build(BuildContext context) {
    return NeuSurface(
      style: NeuStyle.inset,
      color: AppColors.surfaceSunken,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
            child: Row(
              children: [
                Expanded(child: Text(title, style: WebText.title(size: 15))),
                WebCount(count: orders.length),
              ],
            ),
          ),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 14),
              child: Text(
                hint,
                style: WebText.body(size: 12.5, color: AppColors.textTertiary),
              ),
            )
          else
            for (final o in orders) ...[
              WebVendorOrderCard(key: ValueKey(o.id), order: o),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}
