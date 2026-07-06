import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/section_header.dart';
import '../../mock_data/orders_mock.dart';
import '../../mock_data/products_mock.dart';
import '../../mock_data/vendors_mock.dart';

class VendorDashboardScreen extends StatelessWidget {
  const VendorDashboardScreen({super.key});

  // Using mock vendor v-001
  static final _vendor = mockVendors.first;
  static final _vendorOrders = mockOrders.where((o) => o.vendorId == _vendor.id).toList();
  static final _vendorProducts = mockProducts.where((p) => p.vendorId == _vendor.id).toList();

  @override
  Widget build(BuildContext context) {
    final pending = _vendorOrders.where((o) => o.status == MockOrderStatus.pending).length;
    final preparing = _vendorOrders.where((o) => o.status == MockOrderStatus.preparing).length;
    final ready = _vendorOrders.where((o) => o.status == MockOrderStatus.ready).length;
    final completed = _vendorOrders.where((o) => o.status == MockOrderStatus.delivered).length;
    final revenue = _vendorOrders
        .where((o) => o.status == MockOrderStatus.delivered)
        .fold<double>(0, (sum, o) => sum + o.totalAmount);

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning ☀️'
        : hour < 17
            ? 'Good Afternoon 🌤'
            : 'Good Evening 🌙';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.cardDark,
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 800));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Uniform Sticky SliverAppBar matching User Dashboard
            SliverAppBar(
              expandedHeight: 110,
              floating: false,
              pinned: true,
              stretch: true,
              backgroundColor: AppColors.bgDark,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1565C0), AppColors.bgDark],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          _vendor.businessName,
                          style: AppTextStyles.title(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.push('/vendor/notifications'),
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 14,
                                    minHeight: 14,
                                  ),
                                  child: const Text(
                                    '2',
                                    style: TextStyle(
                                      color: AppColors.bgDark,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.accent,
                          child: Text(
                            _vendor.logoInitials,
                            style: AppTextStyles.title(
                              fontSize: 11,
                              color: AppColors.bgDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Scrollable Body with uniform 20px padding matching User Dashboard
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Revenue highlight GlassCard
                  GlassCard(
                    borderGradient: const LinearGradient(colors: [AppColors.accent, AppColors.primary]),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Today\'s Gross Revenue',
                                style: AppTextStyles.label(fontSize: 11, color: AppColors.textSecondaryDark),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '₱${revenue.toStringAsFixed(2)}',
                                style: AppTextStyles.display(fontSize: 30, color: AppColors.accent),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'From $completed successful completed orders',
                                style: AppTextStyles.body(fontSize: 11.5, color: Colors.white70),
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
                          child: const Icon(Icons.trending_up_rounded, color: AppColors.accent, size: 32),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
                  const SizedBox(height: 28),

                  // Quick Actions grid section matching User Dashboard layout style
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
                        onTap: () => _showAnalyticsDialog(context, revenue, completed),
                      ),
                    ],
                  ).animate().fadeIn(delay: 80.ms),
                  const SizedBox(height: 28),

                  // Custom weekly performance chart card
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: const WeeklySalesChart(),
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 28),

                  // Store Performance Section
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
                      _StatCard(label: 'Pending', value: '$pending', icon: Icons.hourglass_empty_rounded, color: AppColors.warning),
                      _StatCard(label: 'Preparing', value: '$preparing', icon: Icons.restaurant_outlined, color: AppColors.info),
                      _StatCard(label: 'Ready', value: '$ready', icon: Icons.check_circle_outline_rounded, color: AppColors.primaryLight),
                      _StatCard(label: 'Listed Products', value: '${_vendorProducts.length}', icon: Icons.inventory_2_rounded, color: AppColors.success),
                    ],
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 28),

                  // Recent Orders section matching User Dashboard style
                  SectionHeader(
                    title: 'Recent Orders',
                    actionLabel: 'View All →',
                    onAction: () => context.go('/vendor/orders'),
                  ),
                  const SizedBox(height: 12),
                  if (_vendorOrders.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text('No orders received yet.', style: AppTextStyles.body(color: AppColors.textSecondaryDark)),
                      ),
                    )
                  else
                    ..._vendorOrders.take(3).map((order) => _MiniOrderCard(order: order)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnalyticsDialog(BuildContext context, double totalRevenue, int orderCount) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF132031),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.analytics_rounded, color: AppColors.accent, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Performance Analytics',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AnalyticsRow(label: 'Average Order Value', value: '₱${(totalRevenue / (orderCount == 0 ? 1 : orderCount)).toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            const _AnalyticsRow(label: 'Peak Ordering Hour', value: '11:30 AM - 1:00 PM'),
            const SizedBox(height: 12),
            const _AnalyticsRow(label: 'Most Popular Item', value: 'Classic Beef Shawarma'),
            const SizedBox(height: 12),
            const _AnalyticsRow(label: 'Drone Prep Time Avg', value: '8.5 mins'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Done',
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
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
      child: GlassCard(
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
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
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
        Text(label, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
      ],
    );
  }
}

class WeeklySalesChart extends StatelessWidget {
  const WeeklySalesChart({super.key});

  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final amounts = [1200, 1850, 950, 2400, 3100, 1500, 2200];
    final maxAmount = amounts.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Weekly Performance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '₱${amounts.reduce((a, b) => sum(a, b)).toStringAsFixed(0)} total',
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 13,
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
              final ratio = amounts[i] / maxAmount;
              final height = ratio * 75;
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '₱${(amounts[i] / 1000).toStringAsFixed(1)}k',
                      style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 8.5),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: height,
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
                    Text(days[i], style: const TextStyle(color: Colors.white70, fontSize: 9.5)),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  int sum(int a, int b) => a + b;
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
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(value, style: AppTextStyles.heading(fontSize: 24, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.body(fontSize: 11.5, color: AppColors.textSecondaryDark)),
        ],
      ),
    );
  }
}

class _MiniOrderCard extends StatelessWidget {
  final MockOrder order;
  const _MiniOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final color = switch (order.status) {
      MockOrderStatus.pending => AppColors.warning,
      MockOrderStatus.preparing => AppColors.info,
      MockOrderStatus.ready => AppColors.primaryLight,
      MockOrderStatus.pickedUp => AppColors.accent,
      MockOrderStatus.delivered => AppColors.success,
      MockOrderStatus.cancelled => AppColors.danger,
    };
    final statusLabel = order.status.name[0].toUpperCase() + order.status.name.substring(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.orderNumber, style: const TextStyle(color: AppColors.primaryLight, fontSize: 11)),
                Text(order.customerName, style: AppTextStyles.body(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
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
                child: Text(statusLabel, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 3),
              Text('₱${order.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
