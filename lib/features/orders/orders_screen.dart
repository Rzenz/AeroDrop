import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../mock_data/orders_mock.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  static const _tabs = [
    (label: 'Pending', status: MockOrderStatus.pending),
    (label: 'Preparing', status: MockOrderStatus.preparing),
    (label: 'Ready', status: MockOrderStatus.ready),
    (label: 'Picked Up', status: MockOrderStatus.pickedUp),
    (label: 'Delivered', status: MockOrderStatus.delivered),
    (label: 'Cancelled', status: MockOrderStatus.cancelled),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          backgroundColor: AppColors.bgDark,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text('My Orders', style: AppTextStyles.subHead(fontSize: 18, color: Colors.white)),
          bottom: TabBar(
            controller: _tab,
            isScrollable: true,
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSecondaryDark,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
            tabs: _tabs.map((t) {
              final count = mockOrders.where((o) => o.status == t.status).length;
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.label),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$count', style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: _tabs.map((t) {
          final orders = mockOrders.where((o) => o.status == t.status).toList();
          if (orders.isEmpty) {
            return _EmptyOrders(label: t.label);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: orders.length,
            itemBuilder: (context, i) => _OrderCard(
              order: orders[i],
              onTap: () => context.push('/user/orders/${orders[i].id}'),
            ).animate().fadeIn(delay: (i * 60).ms).slideY(begin: 0.05),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  final String label;
  const _EmptyOrders({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(label), color: AppColors.textSecondaryDark, size: 60),
          const SizedBox(height: 14),
          Text('No $label orders', style: AppTextStyles.subHead(color: Colors.white70)),
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
  final MockOrder order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    final statusLabel = _statusLabel(order.status);

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
                        order.orderNumber,
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
                        style: AppTextStyles.subHead(fontSize: 15, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 0.8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Items preview
            Text(
              order.items.map((i) => '${i.quantity}x ${i.productName}').join(', '),
              style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark),
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
                _PaymentBadge(status: order.paymentStatus, method: order.paymentMethod),
                // Total + date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      _formatDate(order.createdAt),
                      style: AppTextStyles.body(fontSize: 10, color: AppColors.textSecondaryDark),
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

  Color _statusColor(MockOrderStatus status) {
    return switch (status) {
      MockOrderStatus.pending => AppColors.warning,
      MockOrderStatus.preparing => AppColors.info,
      MockOrderStatus.ready => AppColors.primaryLight,
      MockOrderStatus.pickedUp => AppColors.accent,
      MockOrderStatus.delivered => AppColors.success,
      MockOrderStatus.cancelled => AppColors.danger,
    };
  }

  String _statusLabel(MockOrderStatus status) {
    return switch (status) {
      MockOrderStatus.pending => 'Pending',
      MockOrderStatus.preparing => 'Preparing',
      MockOrderStatus.ready => 'Ready',
      MockOrderStatus.pickedUp => 'Picked Up',
      MockOrderStatus.delivered => 'Delivered',
      MockOrderStatus.cancelled => 'Cancelled',
    };
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  String _pad(int v) => v.toString().padLeft(2, '0');
}

class _PaymentBadge extends StatelessWidget {
  final MockPaymentStatus status;
  final MockPaymentMethod method;

  const _PaymentBadge({required this.status, required this.method});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      MockPaymentStatus.paid => ('Paid', AppColors.success),
      MockPaymentStatus.pending => ('Unpaid', AppColors.warning),
      MockPaymentStatus.failed => ('Failed', AppColors.danger),
      MockPaymentStatus.refunded => ('Refunded', AppColors.info),
    };
    final methodLabel = switch (method) {
      MockPaymentMethod.gcash => 'GCash',
      MockPaymentMethod.cash => 'Cash',
      MockPaymentMethod.creditCard => 'Card',
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
          child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 6),
        Text(methodLabel, style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark)),
      ],
    );
  }
}
