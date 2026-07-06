import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../mock_data/orders_mock.dart';

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Mock: vendor v-001's orders
  static final _myOrders = mockOrders.where((o) => o.vendorId == 'v-001').toList();

  static const _statusTabs = [
    (label: 'Pending', status: MockOrderStatus.pending),
    (label: 'Preparing', status: MockOrderStatus.preparing),
    (label: 'Ready', status: MockOrderStatus.ready),
    (label: 'Delivered', status: MockOrderStatus.delivered),
    (label: 'Cancelled', status: MockOrderStatus.cancelled),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _statusTabs.length, vsync: this);
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
      body: SafeArea(
        child: Column(
          children: [
            // Custom Top Bar title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer Requests', style: AppTextStyles.label(fontSize: 10, color: AppColors.textSecondaryDark)),
                      Text('Order Dispatch', style: AppTextStyles.heading(fontSize: 20, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),

            // Tab bar with count headers
            TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textSecondaryDark,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.white.withValues(alpha: 0.05),
              tabs: _statusTabs.map((t) {
                final count = _myOrders.where((o) => o.status == t.status).length;
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.label),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 1),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(color: AppColors.accent, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),

            // Tab contents
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: _statusTabs.map((t) {
                  final orders = _myOrders.where((o) => o.status == t.status).toList();
                  if (orders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.02),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: AppColors.textSecondaryDark, size: 56),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No ${t.label.toLowerCase()} orders at this time',
                            style: AppTextStyles.body(color: AppColors.textSecondaryDark),
                          ),
                        ],
                      ).animate().fadeIn(),
                    );
                  }
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    itemCount: orders.length,
                    itemBuilder: (context, idx) {
                      return _VendorOrderCard(
                        order: orders[idx],
                        onAccept: t.status == MockOrderStatus.pending
                            ? () => _mockAction(context, 'Order accepted. Moved to preparing.', AppColors.success)
                            : null,
                        onReject: t.status == MockOrderStatus.pending
                            ? () => _mockAction(context, 'Order rejected.', AppColors.danger)
                            : null,
                        onPrepare: t.status == MockOrderStatus.preparing
                            ? () => _mockAction(context, 'Order marked as preparing.', AppColors.info)
                            : null,
                        onReady: t.status == MockOrderStatus.preparing || t.status == MockOrderStatus.ready
                            ? () => _mockAction(context, 'Order marked as ready for drone dispatch.', AppColors.primaryLight)
                            : null,
                      ).animate().fadeIn(delay: (idx * 50).ms);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mockAction(BuildContext context, String message, Color color) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _VendorOrderCard extends StatelessWidget {
  final MockOrder order;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onPrepare;
  final VoidCallback? onReady;

  const _VendorOrderCard({
    required this.order,
    this.onAccept,
    this.onReject,
    this.onPrepare,
    this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.status) {
      MockOrderStatus.pending => AppColors.warning,
      MockOrderStatus.preparing => AppColors.info,
      MockOrderStatus.ready => AppColors.primaryLight,
      MockOrderStatus.pickedUp => AppColors.accent,
      MockOrderStatus.delivered => AppColors.success,
      MockOrderStatus.cancelled => AppColors.danger,
    };
    final statusLabel = order.status.name[0].toUpperCase() + order.status.name.substring(1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order details header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            order.orderNumber,
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(order.customerName, style: AppTextStyles.subHead(fontSize: 15, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(order.customerPhone, style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 11.5)),
                    ],
                  ),
                ),
                Text(
                  '₱${order.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 12),

            // Products items checklist
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(color: AppColors.accent, fontSize: 9.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.productName,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '₱${item.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 10),

            // Drop-off location row
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: AppColors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.dropOffLocation,
                    style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11.5),
                  ),
                ),
              ],
            ),

            // Dispatches Action Buttons
            if (onAccept != null || onReject != null || onPrepare != null || onReady != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (onAccept != null) ...[
                    Expanded(
                      child: _ActionBtn(
                        label: 'Accept',
                        color: AppColors.success,
                        icon: Icons.check_rounded,
                        onTap: onAccept!,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onReject != null) ...[
                    Expanded(
                      child: _ActionBtn(
                        label: 'Reject',
                        color: AppColors.danger,
                        icon: Icons.close_rounded,
                        onTap: onReject!,
                      ),
                    ),
                  ],
                  if (onPrepare != null) ...[
                    Expanded(
                      child: _ActionBtn(
                        label: 'Start Preparing',
                        color: AppColors.info,
                        icon: Icons.play_arrow_rounded,
                        onTap: onPrepare!,
                      ),
                    ),
                  ],
                  if (onReady != null && onPrepare == null) ...[
                    Expanded(
                      child: _ActionBtn(
                        label: 'Ready for Drone Cargo',
                        color: AppColors.accent,
                        icon: Icons.flight_takeoff_rounded,
                        onTap: onReady!,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAccent = color == AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isAccent ? AppColors.accent : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isAccent ? AppColors.accent : color.withValues(alpha: 0.3)),
          boxShadow: isAccent
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isAccent ? AppColors.primaryDark : color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isAccent ? AppColors.primaryDark : color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
