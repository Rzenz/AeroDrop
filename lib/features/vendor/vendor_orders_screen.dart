import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/models/order_model.dart';
import '../../core/providers/order_provider.dart';

class VendorOrdersScreen extends ConsumerStatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  ConsumerState<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends ConsumerState<VendorOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  static const _statusTabs = [
    (label: 'Pending', statusKeys: ['pending']),
    (label: 'Preparing', statusKeys: ['preparing']),
    (
      label: 'Ready',
      statusKeys: ['ready', 'ready_for_pickup', 'ready for pickup'],
    ),
    (label: 'Delivered', statusKeys: ['delivered']),
    (label: 'Cancelled', statusKeys: ['cancelled', 'rejected', 'failed']),
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
    final ordersState = ref.watch(vendorOrdersProvider);
    final allOrders = ordersState.orders;

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
                      Text(
                        'Customer Requests',
                        style: AppTextStyles.label(
                          fontSize: 10,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                      Text(
                        'Order Dispatch',
                        style: AppTextStyles.heading(
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
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
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.white.withValues(alpha: 0.05),
              tabs: _statusTabs.map((t) {
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
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 9.5,
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

            // Tab view
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(vendorOrdersProvider.notifier).loadOrders(),
                color: AppColors.accent,
                child: TabBarView(
                  controller: _tab,
                  children: _statusTabs.map((t) {
                    final filtered = _filterOrders(allOrders, t.statusKeys);

                    if (ordersState.isLoading && allOrders.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      );
                    }

                    if (filtered.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.25,
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.assignment_outlined,
                                  color: AppColors.textSecondaryDark,
                                  size: 56,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No ${t.label} orders received.',
                                  style: AppTextStyles.subHead(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final order = filtered[idx];

                        // Decide which callbacks are available based on current status
                        VoidCallback? acceptCb;
                        VoidCallback? rejectCb;
                        VoidCallback? prepareCb;
                        VoidCallback? readyCb;

                        final status = order.orderStatus.toLowerCase();
                        if (status == 'pending') {
                          acceptCb = () => _handleUpdate(order.id, 'preparing');
                          rejectCb = () => _handleUpdate(order.id, 'cancelled');
                        } else if (status == 'preparing') {
                          readyCb = () => _handleUpdate(order.id, 'ready');
                        }

                        return _DispatchCard(
                              order: order,
                              onAccept: acceptCb,
                              onReject: rejectCb,
                              onPrepare: prepareCb,
                              onReady: readyCb,
                            )
                            .animate()
                            .fadeIn(delay: (idx * 50).ms)
                            .slideY(begin: 0.05);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpdate(String orderId, String nextStatus) async {
    HapticFeedback.mediumImpact();
    final success = await ref
        .read(vendorOrdersProvider.notifier)
        .updateOrderStatus(orderId, nextStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Order updated to $nextStatus.'
                : 'Failed to update order status.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

class _DispatchCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onPrepare;
  final VoidCallback? onReady;

  const _DispatchCard({
    required this.order,
    this.onAccept,
    this.onReject,
    this.onPrepare,
    this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AD-${order.id.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.userId.substring(0, 8),
                      style: AppTextStyles.subHead(
                        fontSize: 14.5,
                        color: Colors.white,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '₱${order.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Products list
            ...order.items.map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${i.quantity}x',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        i.productName,
                        style: AppTextStyles.body(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Divider(color: AppColors.borderDark, height: 1),
            const SizedBox(height: 12),

            // Drop-off Location info
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.textSecondaryDark,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.dropoffLocationName ?? 'Unknown Location',
                    style: const TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),

            // Dispatches Action Buttons
            if (onAccept != null ||
                onReject != null ||
                onPrepare != null ||
                onReady != null) ...[
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
          border: Border.all(
            color: isAccent ? AppColors.accent : color.withValues(alpha: 0.3),
          ),
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
            Icon(
              icon,
              color: isAccent ? AppColors.primaryDark : color,
              size: 14,
            ),
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
