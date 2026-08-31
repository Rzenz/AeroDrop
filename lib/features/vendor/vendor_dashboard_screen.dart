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

class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentVendorAsync = ref.watch(currentVendorProvider);
    final vendorOrdersState = ref.watch(vendorOrdersProvider);
    final vendorProductsState = ref.watch(vendorProductsProvider);

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
              .where((o) => o.orderStatus.toLowerCase() == 'pending')
              .length;
          final preparing = vendorOrders
              .where((o) => o.orderStatus.toLowerCase() == 'preparing')
              .length;
          final ready = vendorOrders
              .where(
                (o) => [
                  'ready',
                  'ready_for_pickup',
                  'ready for pickup',
                ].contains(o.orderStatus.toLowerCase()),
              )
              .length;
          final completed = vendorOrders
              .where((o) => o.orderStatus.toLowerCase() == 'delivered')
              .length;

          final revenue = vendorOrders
              .where((o) => o.orderStatus.toLowerCase() == 'delivered')
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
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 110,
                  floating: false,
                  pinned: true,
                  stretch: true,
                  backgroundColor: AppColors.base,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: Container(
                      decoration: BoxDecoration(color: AppColors.base),
                    ),
                    titlePadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              greeting,
                              style: AppTextStyles.label(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              vendor['business_name']?.toString() ?? 'Vendor',
                              style: AppTextStyles.title(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.accent,
                          child: Text(
                            initials,
                            style: AppTextStyles.title(
                              fontSize: 11,
                              color: AppColors.bgDark,
                              fontWeight: FontWeight.bold,
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
                                    style: AppTextStyles.label(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '₱${revenue.toStringAsFixed(2)}',
                                    style: AppTextStyles.display(
                                      fontSize: 30,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'From $completed successful completed orders',
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

                      // Quick Actions
                      const SectionHeader(
                        title: 'Quick Actions',
                        actionLabel: null,
                        onAction: null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _QuickActionBtn(
                            icon: Icons.add_photo_alternate_rounded,
                            label: 'Add Product',
                            color: AppColors.primaryLight,
                            onTap: () => context.push('/vendor/products/add'),
                          ),
                          _QuickActionBtn(
                            icon: Icons.assignment_rounded,
                            label: 'Orders',
                            color: AppColors.accent,
                            onTap: () => context.go('/vendor/orders'),
                          ),
                          _QuickActionBtn(
                            icon: Icons.inventory_rounded,
                            label: 'Inventory',
                            color: AppColors.info,
                            onTap: () => context.go('/vendor/products'),
                          ),
                          _QuickActionBtn(
                            icon: Icons.analytics_rounded,
                            label: 'Analytics',
                            color: AppColors.warning,
                            onTap: () => _showAnalyticsDialog(
                              context,
                              revenue,
                              completed,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 80.ms),
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
                          ),
                          _StatCard(
                            label: 'Preparing',
                            value: '$preparing',
                            icon: Icons.restaurant_outlined,
                            color: AppColors.info,
                          ),
                          _StatCard(
                            label: 'Ready',
                            value: '$ready',
                            icon: Icons.check_circle_outline_rounded,
                            color: AppColors.primaryLight,
                          ),
                          _StatCard(
                            label: 'Listed Products',
                            value: '${vendorProducts.length}',
                            icon: Icons.inventory_2_rounded,
                            color: AppColors.success,
                          ),
                        ],
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 28),

                      // Recent Orders
                      SectionHeader(
                        title: 'Recent Orders',
                        actionLabel: 'View All →',
                        onAction: () => context.go('/vendor/orders'),
                      ),
                      const SizedBox(height: 12),
                      if (vendorOrders.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'No orders received yet.',
                              style: AppTextStyles.body(
                                color: AppColors.textSecondary,
                              ),
                            ),
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
            Text(
              'Performance Analytics',
              style: AppTextStyles.subHead(
                fontSize: 18,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
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
              value:
                  '₱${(totalRevenue / (orderCount == 0 ? 1 : orderCount)).toStringAsFixed(2)}',
            ),
            const SizedBox(height: 12),
            const _AnalyticsRow(
              label: 'Peak Ordering Hour',
              value: '11:30 AM - 1:00 PM',
            ),
            const SizedBox(height: 12),
            const _AnalyticsRow(
              label: 'Avg Preparation Time',
              value: '8.5 mins',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Done',
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

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: NeuCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: SizedBox(
          width: 70,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTextStyles.label(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  letterSpacing: 0,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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
        Text(
          label,
          style: AppTextStyles.body(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
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

class WeeklySalesChart extends StatelessWidget {
  final List<OrderModel> orders;
  const WeeklySalesChart({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final amounts = List.filled(7, 0.0);

    // Group completed orders by weekday
    for (final o in orders) {
      if (o.orderStatus.toLowerCase() == 'delivered') {
        final weekday = o.createdAt.weekday; // 1 = Monday, 7 = Sunday
        amounts[weekday - 1] += o.totalAmount;
      }
    }

    final maxAmount = amounts.reduce((a, b) => a > b ? a : b);
    final totalAmount = amounts.fold<double>(0, (sum, val) => sum + val);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Weekly Performance',
              style: AppTextStyles.subHead(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '₱${totalAmount.toStringAsFixed(2)} total',
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

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.heading(
              fontSize: 24,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
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
    final status = order.orderStatus.toLowerCase();
    final color = switch (status) {
      'pending' => AppColors.warning,
      'preparing' => AppColors.info,
      'ready' ||
      'ready_for_pickup' ||
      'ready for pickup' => AppColors.primaryLight,
      'picked_up' ||
      'picked up' ||
      'in_transit' ||
      'in transit' => AppColors.accent,
      'delivered' => AppColors.success,
      _ => AppColors.danger,
    };
    final statusLabel = status[0].toUpperCase() + status.substring(1);

    return Container(
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
                  style: AppTextStyles.caption(
                    fontSize: 11,
                    color: AppColors.primaryLight,
                  ),
                ),
                Text(
                  order.userId.substring(0, 8),
                  style: AppTextStyles.body(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
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
    );
  }
}
