import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/order_model.dart';
import '../../../../core/providers/order_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../web_kit.dart';
import '../web_status.dart';

/// The same status groups as the app's order tabs.
const webOrderTabs = <(String, List<String>)>[
  ('All', []),
  ('Pending', ['pending']),
  ('Preparing', ['preparing', 'confirmed']),
  ('Ready', ['ready_for_delivery', 'ready', 'ready_for_pickup']),
  ('In flight', ['in_transit', 'out_for_delivery', 'picked_up']),
  ('Delivered', ['delivered']),
  ('Cancelled', ['cancelled', 'rejected', 'failed']),
];

List<OrderModel> ordersIn(List<OrderModel> all, List<String> keys) =>
    keys.isEmpty
    ? all
    : all.where((o) => keys.contains(o.effectiveStatus)).toList();

/// Every order the customer has placed, in a table filtered by status.
class WebOrdersPage extends ConsumerStatefulWidget {
  const WebOrdersPage({super.key});

  @override
  ConsumerState<WebOrdersPage> createState() => _WebOrdersPageState();
}

class _WebOrdersPageState extends ConsumerState<WebOrdersPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderProvider);
    final all = [...state.orders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final rows = ordersIn(all, webOrderTabs[_tab].$2);

    Widget body;
    if (state.isLoading && all.isEmpty) {
      body = Column(
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            const WebSkeleton(height: 64, radius: 16),
          ],
        ],
      );
    } else if (state.errorMessage != null && all.isEmpty) {
      body = WebEmpty(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load your orders',
        message: state.errorMessage!,
        action: WebButton(
          label: 'Try again',
          kind: WebButtonKind.secondary,
          onPressed: () => ref.read(orderProvider.notifier).loadOrders(),
        ),
      );
    } else if (rows.isEmpty) {
      body = WebEmpty(
        icon: Icons.receipt_long_outlined,
        title: all.isEmpty
            ? 'No orders yet'
            : 'No ${webOrderTabs[_tab].$1.toLowerCase()} orders',
        message: all.isEmpty
            ? 'Your orders appear here from the moment you place them.'
            : 'Orders move between these tabs as the canteen and the drone '
                  'work through them.',
        action: all.isEmpty
            ? WebButton(
                label: 'Browse the shop',
                onPressed: () => context.go('/user/shop'),
              )
            : null,
      );
    } else {
      body = WebTable<OrderModel>(
        rows: rows,
        onRowTap: (o) => context.push('/user/orders/${o.id}'),
        columns: [
          WebColumn(
            'Order',
            (o) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(orderRef(o.id), style: WebText.label(size: 14.5)),
                Text(shortDate(o.createdAt), style: WebText.body(size: 12.5)),
              ],
            ),
            flex: 2,
            primary: true,
          ),
          WebColumn(
            'Canteen',
            (o) => Text(
              o.vendorName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: WebText.label(size: 14, weight: FontWeight.w500),
            ),
            flex: 3,
          ),
          WebColumn('Items', (o) {
            final n = o.items.fold<int>(0, (s, i) => s + i.quantity);
            return Text(
              o.items.isEmpty
                  ? '—'
                  : '$n · ${o.items.first.productName}'
                        '${o.items.length > 1 ? ' +${o.items.length - 1}' : ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: WebText.body(size: 13.5),
            );
          }, flex: 3),
          WebColumn(
            'Drop-off',
            (o) => Text(
              o.dropoffLocationName ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WebText.body(size: 13.5),
            ),
            flex: 2,
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
    }

    final active = all
        .where(
          (o) => const [
            'pending',
            'confirmed',
            'preparing',
            'ready_for_delivery',
            'in_transit',
          ].contains(o.effectiveStatus),
        )
        .length;
    final delivered = ordersIn(all, ['delivered']);
    final spent = delivered.fold<double>(0, (s, o) => s + o.totalAmount);

    return WebPage(
      title: 'Orders',
      subtitle: 'Everything you have ordered, newest first.',
      onRefresh: () => ref.read(orderProvider.notifier).loadOrders(),
      actions: [
        WebButton(
          label: 'Order something',
          icon: Icons.storefront_outlined,
          onPressed: () => context.go('/user/shop'),
        ),
      ],
      children: [
        WebGrid(
          minTile: 220,
          maxColumns: 3,
          children: [
            WebStat(
              label: 'In progress',
              value: '$active',
              icon: Icons.timelapse_rounded,
              tone: AppColors.accent,
            ),
            WebStat(
              label: 'Delivered',
              value: '${delivered.length}',
              icon: Icons.where_to_vote_outlined,
              tone: AppColors.success,
            ),
            WebStat(
              label: 'Spent on delivered orders',
              value: WebText.peso(spent),
              icon: Icons.payments_outlined,
            ),
          ],
        ),
        WebTabs(
          labels: [for (final t in webOrderTabs) t.$1],
          counts: [for (final t in webOrderTabs) ordersIn(all, t.$2).length],
          selected: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
        body,
      ],
    );
  }
}
