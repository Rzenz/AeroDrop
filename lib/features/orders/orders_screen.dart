import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/models/order_model.dart';
import '../../core/providers/order_provider.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  static const _tabs = [
    (label: 'Pending', statusKeys: ['pending']),
    (label: 'Preparing', statusKeys: ['preparing']),
    (
      label: 'Ready',
      statusKeys: ['ready', 'ready_for_pickup', 'ready for pickup'],
    ),
    (
      label: 'Picked Up',
      statusKeys: ['picked_up', 'in_transit', 'picked up', 'in transit'],
    ),
    (label: 'Delivered', statusKeys: ['delivered']),
    (label: 'Cancelled', statusKeys: ['cancelled', 'rejected', 'failed']),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<OrderModel> _filterOrders(
    List<OrderModel> orders,
    List<String> statusKeys,
  ) {
    return orders
        .where((o) => statusKeys.contains(o.orderStatus.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderProvider);
    final allOrders = orderState.orders;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          backgroundColor: AppColors.bgDark,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'My Orders',
            style: AppTextStyles.subHead(fontSize: 18, color: Colors.white),
          ),
          bottom: TabBar(
            controller: _tab,
            isScrollable: true,
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSecondaryDark,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 13,
            ),
            tabs: _tabs.map((t) {
              final count = _filterOrders(allOrders, t.statusKeys).length;
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.label),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(orderProvider.notifier).loadOrders(),
        color: AppColors.accent,
        backgroundColor: AppColors.cardDark,
        child: TabBarView(
          controller: _tab,
          children: _tabs.map((t) {
            final orders = _filterOrders(allOrders, t.statusKeys);

            if (orderState.isLoading && allOrders.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              );
            }
            if (orders.isEmpty) {
              return _EmptyOrders(
                label: t.label,
                onRetry: () => ref.read(orderProvider.notifier).loadOrders(),
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: orders.length,
              itemBuilder: (context, i) => _OrderCard(
                order: orders[i],
                onTap: () => context.push('/user/orders/${orders[i].id}'),
              ).animate().fadeIn(delay: (i * 60).ms).slideY(begin: 0.05),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  final String label;
  final VoidCallback onRetry;
  const _EmptyOrders({required this.label, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _statusIcon(label),
            color: AppColors.textSecondaryDark,
            size: 60,
          ),
          const SizedBox(height: 14),
          Text(
            'You have no $label orders yet.',
            style: AppTextStyles.subHead(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
        ],
      ).animate().fadeIn(),
    );
  }

  IconData _statusIcon(String label) {
    return switch (label) {
      'Pending' => Icons.hourglass_empty_rounded,
      'Preparing' => Icons.restaurant_outlined,
      'Ready' => Icons.check_circle_outline_rounded,
      'Picked Up' => Icons.flight_takeoff_rounded,
      'Delivered' => Icons.check_circle_rounded,
      'Cancelled' => Icons.cancel_outlined,
      _ => Icons.receipt_long_outlined,
    };
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.orderStatus);
    final statusLabel = _statusLabel(order.orderStatus);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AD-${order.id.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.vendorName,
                        style: AppTextStyles.subHead(
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Items preview
            Text(
              order.items.isEmpty
                  ? 'No items'
                  : order.items
                        .map((i) => '${i.quantity}x ${i.productName}')
                        .join(', '),
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.textSecondaryDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            const Divider(color: AppColors.borderDark, height: 1),
            const SizedBox(height: 10),
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Payment status
                _PaymentBadge(
                  status: order.paymentStatus,
                  method: order.paymentMethod,
                ),
                // Total + date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _formatDate(order.createdAt),
                      style: AppTextStyles.body(
                        fontSize: 10,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'pending') {
      return AppColors.warning;
    }
    if (s == 'preparing') {
      return AppColors.info;
    }
    if (s == 'ready' || s == 'ready_for_pickup' || s == 'ready for pickup') {
      return AppColors.primaryLight;
    }
    if (s == 'picked_up' ||
        s == 'picked up' ||
        s == 'in_transit' ||
        s == 'in transit') {
      return AppColors.accent;
    }
    if (s == 'delivered') {
      return AppColors.success;
    }
    return AppColors.danger;
  }

  String _statusLabel(String status) {
    final s = status.toLowerCase();
    if (s == 'pending') {
      return 'Pending';
    }
    if (s == 'preparing') {
      return 'Preparing';
    }
    if (s == 'ready' || s == 'ready_for_pickup' || s == 'ready for pickup') {
      return 'Ready';
    }
    if (s == 'picked_up' ||
        s == 'picked up' ||
        s == 'in_transit' ||
        s == 'in transit') {
      return 'In Transit';
    }
    if (s == 'delivered') {
      return 'Delivered';
    }
    return 'Cancelled';
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  String _pad(int v) => v.toString().padLeft(2, '0');
}

class _PaymentBadge extends StatelessWidget {
  final String status;
  final String method;

  const _PaymentBadge({required this.status, required this.method});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final (label, color) = switch (s) {
      'paid' => ('Paid', AppColors.success),
      'pending' => ('Unpaid', AppColors.warning),
      'failed' => ('Failed', AppColors.danger),
      'refunded' => ('Refunded', AppColors.info),
      _ => ('Unpaid', AppColors.warning),
    };
    final methodLabel = switch (method.toLowerCase()) {
      'gcash' || 'gcash_simulated' => 'GCash',
      'cash' || 'cash_on_delivery' => 'Cash',
      'card' || 'credit_card' => 'Card',
      _ => method,
    };

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          methodLabel,
          style: AppTextStyles.body(
            fontSize: 11,
            color: AppColors.textSecondaryDark,
          ),
        ),
      ],
    );
  }
}
