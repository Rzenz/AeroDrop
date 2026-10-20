import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../../core/providers/order_provider.dart';
import '../../../../core/providers/product_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../../../../core/widgets/wide_shell.dart';
import '../../../dashboard/widgets/dash_kit.dart';
import '../web_kit.dart';
import 'web_vendor_orders_page.dart';

/// The canteen's overview, as an operations dashboard: what earned, what is
/// waiting, what to do next, and what sells. Every figure comes from the
/// canteen's own orders — where there are too few to say something (a
/// busiest hour), it says so instead of inventing one.
class WebVendorDashboardPage extends ConsumerWidget {
  const WebVendorDashboardPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(currentVendorProvider);
    await ref.read(vendorOrdersProvider.notifier).loadOrders();
    await ref.read(vendorProductsProvider.notifier).loadProducts();
    await ref.read(notificationProvider.notifier).loadNotifications();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final vendorRow = ref.watch(currentVendorProvider).valueOrNull;
    final orders = [...ref.watch(vendorOrdersProvider).orders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final products = ref.watch(vendorProductsProvider).products;

    final store =
        (vendorRow?['business_name'] ?? user?.businessName ?? 'Your store')
            .toString();
    final building = ((vendorRow?['campus_locations'] as Map?)?['name'] ?? '')
        .toString();

    int count(List<String> s) =>
        orders.where((o) => s.contains(o.effectiveStatus)).length;
    final pending = count(['pending']);
    final preparing = count(['confirmed', 'preparing']);
    final ready = count(['ready_for_delivery', 'ready', 'ready_for_pickup']);
    final delivered = orders
        .where((o) => o.effectiveStatus == 'delivered')
        .toList();
    final revenue = delivered.fold<double>(0, (s, o) => s + o.totalAmount);

    final now = DateTime.now();
    final today = orders
        .where(
          (o) =>
              o.createdAt.year == now.year &&
              o.createdAt.month == now.month &&
              o.createdAt.day == now.day,
        )
        .toList();
    final average = delivered.isEmpty ? null : revenue / delivered.length;

    // Busiest hour from real order times; needs a handful to mean anything.
    String busiest = 'Not enough orders yet';
    if (orders.length >= 5) {
      final byHour = <int, int>{};
      for (final o in orders) {
        byHour.update(o.createdAt.hour, (n) => n + 1, ifAbsent: () => 1);
      }
      final h = byHour.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      String fmt(int h) =>
          '${h % 12 == 0 ? 12 : h % 12} ${h < 12 ? 'AM' : 'PM'}';
      busiest = '${fmt(h)} – ${fmt((h + 1) % 24)}';
    }

    // Best sellers by units in delivered orders.
    final sold = <String, int>{};
    for (final o in delivered) {
      for (final i in o.items) {
        sold.update(
          i.productName,
          (n) => n + i.quantity,
          ifAbsent: () => i.quantity,
        );
      }
    }
    final top = sold.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final needs = orders
        .where(
          (o) => const [
            'pending',
            'confirmed',
            'preparing',
            'ready_for_delivery',
          ].contains(o.effectiveStatus),
        )
        .take(6)
        .toList();
    final lowStock = products.where((p) => p.stock <= 3).toList();

    final queue = WebPanel(
      title: 'Orders needing you',
      subtitle: needs.isEmpty ? null : 'Oldest at the bottom.',
      action: WebButton(
        label: 'Open the board',
        kind: WebButtonKind.ghost,
        dense: true,
        onPressed: () => context.go('/vendor/orders'),
      ),
      child: needs.isEmpty
          ? const WebEmpty(
              icon: Icons.inbox_outlined,
              title: 'All caught up',
              message: 'New orders appear here the moment they are placed.',
            )
          : WebGrid(
              minTile: 260,
              maxColumns: 2,
              gap: 16,
              children: [
                for (final o in needs)
                  WebVendorOrderCard(key: ValueKey(o.id), order: o),
              ],
            ),
    );

    final storeCard = WebPanel(
      depth: NeuDepth.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              WideAvatar(
                name: store,
                url: user?.businessLogoUrl ?? user?.avatarUrl,
                size: 54,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store, style: WebText.title(size: 17)),
                    if (building.isNotEmpty)
                      Text(building, style: WebText.body(size: 13)),
                  ],
                ),
              ),
            ],
          ),
          const WebGroove(vertical: 14),
          WebKeyValue('On the menu', '${products.length}'),
          WebKeyValue(
            'Running low',
            lowStock.isEmpty ? 'Nothing' : '${lowStock.length}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: WebButton(
                  label: 'Add product',
                  icon: Icons.add_rounded,
                  dense: true,
                  expand: true,
                  onPressed: () => context.push('/vendor/products/add'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: WebButton(
                  label: 'Store page',
                  kind: WebButtonKind.secondary,
                  dense: true,
                  expand: true,
                  onPressed: () => context.go('/vendor/profile'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final todayCard = WebPanel(
      title: 'Today',
      child: Column(
        children: [
          WebKeyValue('Orders placed', '${today.length}'),
          WebKeyValue(
            'Average order',
            average == null ? '—' : WebText.peso(average),
          ),
          WebKeyValue('Busiest hour', busiest),
        ],
      ),
    );

    final best = WebPanel(
      title: 'Best sellers',
      subtitle: 'Units in delivered orders.',
      child: top.isEmpty
          ? Text(
              'Your best sellers show here after the first deliveries.',
              style: WebText.body(size: 13.5),
            )
          : Column(
              children: [
                for (var i = 0; i < top.length && i < 5; i++)
                  _Bar(
                    rank: i + 1,
                    name: top[i].key,
                    units: top[i].value,
                    share: top[i].value / top.first.value,
                  ),
              ],
            ),
    );

    return WebPage(
      title: '${dashGreeting()}, $store',
      subtitle: pending == 0
          ? 'Nothing waiting on you right now.'
          : '$pending new ${pending == 1 ? 'order is' : 'orders are'} waiting '
                'to be accepted.',
      onRefresh: () => _refresh(ref),
      actions: [
        WebButton(
          label: 'Add product',
          icon: Icons.add_rounded,
          onPressed: () => context.push('/vendor/products/add'),
        ),
        WebButton(
          label: 'Orders board',
          icon: Icons.view_kanban_outlined,
          kind: WebButtonKind.secondary,
          onPressed: () => context.go('/vendor/orders'),
        ),
      ],
      children: [
        WebGrid(
          minTile: 210,
          children: [
            WebStat(
              label: 'Revenue',
              value: WebText.peso(revenue),
              icon: Icons.payments_outlined,
              tone: AppColors.success,
              note: 'From ${delivered.length} delivered',
            ),
            WebStat(
              label: 'New',
              value: '$pending',
              icon: Icons.notifications_active_outlined,
              tone: AppColors.warning,
              note: 'Waiting to be accepted',
              onTap: () => context.go('/vendor/orders'),
            ),
            WebStat(
              label: 'Preparing',
              value: '$preparing',
              icon: Icons.soup_kitchen_outlined,
              note: 'Accepted or cooking',
              onTap: () => context.go('/vendor/orders'),
            ),
            WebStat(
              label: 'Ready',
              value: '$ready',
              icon: Icons.inventory_2_outlined,
              tone: AppColors.primary,
              note: 'Waiting for the drone',
              onTap: () => context.go('/vendor/orders'),
            ),
          ],
        ),
        WebSplit(
          sideWidth: 340,
          breakpoint: 1000,
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [queue, const SizedBox(height: 22), best],
          ),
          side: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              storeCard,
              const SizedBox(height: 20),
              todayCard,
              // The sidebar carries campus weather on a wide window; without
              // it (a phone browser) the dashboard does.
              if (!WebLayout.isWide(context)) ...[
                const SizedBox(height: 20),
                const DashWeatherCard(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.rank,
    required this.name,
    required this.units,
    required this.share,
  });

  final int rank;
  final String name;
  final int units;
  final double share;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: WebText.numeric(size: 15, color: AppColors.textTertiary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WebText.label(size: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: NeuSurface(
              style: NeuStyle.inset,
              depth: NeuDepth.flat,
              color: AppColors.surfaceSunken,
              height: 10,
              borderRadius: BorderRadius.circular(5),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: share.clamp(0.04, 1.0),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.accentFill,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
            child: Text(
              '$units',
              textAlign: TextAlign.right,
              style: WebText.label(size: 14),
            ),
          ),
        ],
      ),
    );
  }
}
