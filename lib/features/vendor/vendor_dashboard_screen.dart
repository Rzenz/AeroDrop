import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/models/order_model.dart';
import '../../core/providers/order_provider.dart';
import '../../core/providers/product_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/providers/delivery_provider.dart';
import '../dashboard/user_dashboard_screen.dart';
import '../../core/widgets/neu_surface.dart';

/// Orders needed before a peak hour means anything; below this, one busy
/// lunchtime decides it.
const peakHourMinimumOrders = 10;

/// The busiest one-hour window by when orders were placed, in local time,
/// e.g. "11:00 AM – 12:00 PM". Null when there are fewer than
/// [peakHourMinimumOrders] orders. A tie goes to the earlier hour.
String? peakOrderingWindow(List<OrderModel> orders) {
  if (orders.length < peakHourMinimumOrders) return null;

  final perHour = List.filled(24, 0);
  for (final o in orders) {
    perHour[o.createdAt.toLocal().hour]++;
  }
  var peak = 0;
  for (var h = 1; h < 24; h++) {
    if (perHour[h] > perHour[peak]) peak = h;
  }

  String clock(int hour) {
    final h = hour % 24;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:00 ${h < 12 ? 'AM' : 'PM'}';
  }

  return '${clock(peak)} – ${clock(peak + 1)}';
}

class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentVendorAsync = ref.watch(currentVendorProvider);
    final vendorOrdersState = ref.watch(vendorOrdersProvider);
    final vendorProductsState = ref.watch(vendorProductsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning ☀️'
        : hour < 17
        ? 'Good Afternoon 🌤'
        : 'Good Evening 🌙';

    return Scaffold(
      backgroundColor: AppColors.base,
      body: currentVendorAsync.when(
        data: (vendor) {
          if (vendor == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    color: AppColors.danger,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No vendor profile is registered for this account.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subHead(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(authProvider.notifier).logout();
                      context.go('/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    child: Text(
                      'Log Out',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            );
          }

          final vendorOrders = vendorOrdersState.orders;
          final vendorProducts = vendorProductsState.products;

          final pending = vendorOrders
              .where((o) => o.effectiveStatus == 'pending')
              .length;
          final preparing = vendorOrders
              .where(
                (o) =>
                    o.effectiveStatus == 'preparing' ||
                    o.effectiveStatus == 'confirmed',
              )
              .length;
          final ready = vendorOrders
              .where(
                (o) => [
                  'ready',
                  'ready_for_delivery',
                  'ready_for_pickup',
                ].contains(o.effectiveStatus),
              )
              .length;
          final completed = vendorOrders
              .where((o) => o.effectiveStatus == 'delivered')
              .length;

          final revenue = vendorOrders
              .where((o) => o.effectiveStatus == 'delivered')
              .fold<double>(0, (sum, o) => sum + o.totalAmount);

          final initials =
              vendor['business_name']
                  ?.toString()
                  .substring(
                    0,
                    (vendor['business_name']?.toString().length ?? 0) >= 2
                        ? 2
                        : 1,
                  )
                  .toUpperCase() ??
              'V';

          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.base,
            onRefresh: () async {
              ref.invalidate(currentVendorProvider);
              await ref.read(vendorOrdersProvider.notifier).loadOrders();
              await ref.read(vendorProductsProvider.notifier).loadProducts();
              await ref.read(notificationProvider.notifier).loadNotifications();
              await ref
                  .read(deliveryProvider.notifier)
                  .loadDeliveriesFromSupabase();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  toolbarHeight: 72,
                  backgroundColor: AppColors.base,
                  surfaceTintColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  titleSpacing: 0,
                  title: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                greeting,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.label(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                vendor['business_name']?.toString() ?? 'Vendor',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.title(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        NeuIconButton(
                          icon: Icons.notifications_none_rounded,
                          tooltip: 'Alerts',
                          badgeCount: unreadCount,
                          onPressed: () =>
                              context.push('/vendor/notifications'),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => context.go('/vendor/profile'),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.accent,
                            backgroundImage:
                                vendor['business_logo_url'] != null &&
                                    vendor['business_logo_url']
                                        .toString()
                                        .isNotEmpty
                                ? NetworkImage(
                                    vendor['business_logo_url'].toString(),
                                  )
                                : null,
                            child:
                                vendor['business_logo_url'] != null &&
                                    vendor['business_logo_url']
                                        .toString()
                                        .isNotEmpty
                                ? null
                                : Text(
                                    initials,
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: AppTextStyles.title(
                                      fontSize: 12,
                                      color: AppColors.bgDark,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // The two shortcuts with no other way in. Orders and
                      // Products are already tabs, so they are not repeated.
                      Row(
                        children: [
                          Expanded(
                            child: _HeaderAction(
                              icon: Icons.add_photo_alternate_rounded,
                              label: 'Add Product',
                              color: AppColors.primaryLight,
                              onTap: () => context.push('/vendor/products/add'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HeaderAction(
                              icon: Icons.analytics_rounded,
                              label: 'Analytics',
                              color: AppColors.warning,
                              onTap: () => _showAnalyticsDialog(
                                context,
                                revenue,
                                completed,
                                vendorOrders,
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 300.ms),
                      const SizedBox(height: 16),

                      // Campus Live Weather
                      const AeroDropWeatherWidget(),
                      const SizedBox(height: 16),

                      // Revenue NeuCard
                      NeuCard(
                        accent: AppColors.accent,
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Gross Revenue',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.label(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '₱${revenue.toStringAsFixed(2)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.display(
                                      fontSize: 30,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'From $completed successful completed orders',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.body(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.trending_up_rounded,
                                color: AppColors.accent,
                                size: 32,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
                      const SizedBox(height: 28),

                      // Weekly Sales Chart
                      NeuCard(
                        padding: const EdgeInsets.all(20),
                        child: WeeklySalesChart(orders: vendorOrders),
                      ).animate().fadeIn(delay: 150.ms),
                      const SizedBox(height: 28),

                      // Performance Grid
                      const SectionHeader(
                        title: 'Store Performance',
                        actionLabel: null,
                        onAction: null,
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _StatCard(
                            label: 'Pending',
                            value: '$pending',
                            icon: Icons.hourglass_empty_rounded,
                            color: AppColors.warning,
                            onTap: () =>
                                context.go('/vendor/orders?status=pending'),
                          ),
                          _StatCard(
                            label: 'Preparing',
                            value: '$preparing',
                            icon: Icons.restaurant_outlined,
                            color: AppColors.info,
                            onTap: () =>
                                context.go('/vendor/orders?status=preparing'),
                          ),
                          _StatCard(
                            label: 'Ready',
                            value: '$ready',
                            icon: Icons.check_circle_outline_rounded,
                            color: AppColors.primaryLight,
                            onTap: () =>
                                context.go('/vendor/orders?status=ready'),
                          ),
                          _StatCard(
                            label: 'Listed Products',
                            value: '${vendorProducts.length}',
                            icon: Icons.inventory_2_rounded,
                            color: AppColors.success,
                            onTap: () => context.go('/vendor/products'),
                          ),
                        ],
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 28),

                      // Recent Orders
                      SectionHeader(
                        title: 'Recent Orders',
                        actionLabel: 'See all',
                        onAction: () => context.go('/vendor/orders'),
                      ),
                      const SizedBox(height: 12),
                      if (vendorOrders.isEmpty)
                        NeuCard(
                          padding: const EdgeInsets.symmetric(
                            vertical: 24,
                            horizontal: 20,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                color: AppColors.textSecondary,
                                size: 32,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'No orders received yet. New orders appear '
                                  'here and in the Orders tab.',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.body(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...vendorOrders
                            .take(3)
                            .map((order) => _MiniOrderCard(order: order)),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error: $err',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(color: AppColors.danger),
          ),
        ),
      ),
    );
  }

  void _showAnalyticsDialog(
    BuildContext context,
    double totalRevenue,
    int orderCount,
    List<OrderModel> orders,
  ) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF132031),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(
              Icons.analytics_rounded,
              color: AppColors.accent,
              size: 28,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Performance Analytics',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.subHead(
                  fontSize: 18,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AnalyticsRow(
              label: 'Average Order Value',
              value: orderCount > 0
                  ? '₱${(totalRevenue / orderCount).toStringAsFixed(2)}'
                  : '—',
            ),
            const SizedBox(height: 12),
            _AnalyticsRow(
              label: 'Peak Ordering Hour',
              value: peakOrderingWindow(orders) ?? 'Not enough orders yet',
            ),
            // No preparation time: no record holds both the moment an order
            // was confirmed and the moment it became ready, and an estimate
            // shown as a metric would be invented.
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Done',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.subHead(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled shortcut in the header area: icon well beside its name.
class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      onTap: onTap,
      semanticLabel: label,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsRow extends StatelessWidget {
  final String label;
  final String value;
  const _AnalyticsRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.subHead(
            fontSize: 13.5,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Delivered-order sales for each of the last seven local days, oldest first
/// and today last. Orders older than that are left out, so this is the past
/// week rather than every week ever folded onto the same weekday.
List<double> lastSevenDaysSales(List<OrderModel> orders, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final amounts = List.filled(7, 0.0);
  for (final o in orders) {
    if (o.effectiveStatus != 'delivered') continue;
    final local = o.createdAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    // Calendar days, not 24-hour spans, so a DST change cannot shift a bucket
    final daysAgo = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
    if (daysAgo < 0 || daysAgo > 6) continue;
    amounts[6 - daysAgo] += o.totalAmount;
  }
  return amounts;
}

class WeeklySalesChart extends StatelessWidget {
  final List<OrderModel> orders;
  const WeeklySalesChart({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    // Oldest first, today last
    final days = [
      for (var i = 6; i >= 0; i--)
        names[DateTime(now.year, now.month, now.day - i).weekday - 1],
    ];
    final amounts = lastSevenDaysSales(orders, now);

    final maxAmount = amounts.reduce((a, b) => a > b ? a : b);
    final totalAmount = amounts.fold<double>(0, (sum, val) => sum + val);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Sales, Last 7 Days',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.subHead(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₱${totalAmount.toStringAsFixed(2)} total',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.subHead(
                fontSize: 13,
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 120,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(days.length, (i) {
              final ratio = maxAmount > 0 ? (amounts[i] / maxAmount) : 0.0;
              final height = ratio * 75;
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '₱${(amounts[i] / 1000).toStringAsFixed(1)}k',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: AppTextStyles.caption(
                        fontSize: 8.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: height < 4 ? 4.0 : height,
                      width: 14,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.primaryLight],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ).animate().scaleY(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.bottomCenter,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      days[i],
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: AppTextStyles.caption(
                        fontSize: 9.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      onTap: onTap,
      semanticLabel: '$label: $value',
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.heading(
              fontSize: 24,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniOrderCard extends StatelessWidget {
  final OrderModel order;
  const _MiniOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order.effectiveStatus;
    final color = switch (status) {
      'pending' => AppColors.warning,
      'preparing' || 'confirmed' => AppColors.info,
      'ready_for_delivery' ||
      'ready' ||
      'ready_for_pickup' => AppColors.primaryLight,
      'picked_up' || 'in_transit' => AppColors.accent,
      'delivered' => AppColors.success,
      _ => AppColors.danger,
    };
    final statusLabel = order.statusDisplay;

    final customerTitle =
        order.customerName.isNotEmpty && order.customerName != 'Me'
        ? order.customerName
        : 'Customer (${order.userId.substring(0, 8)})';

    return GestureDetector(
      onTap: () => context.push('/vendor/orders/${order.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.base,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AD-${order.id.substring(0, 8).toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(
                      fontSize: 11,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  Text(
                    customerTitle,
                    style: AppTextStyles.body(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '₱${order.totalAmount.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subHead(
                    fontSize: 13,
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
