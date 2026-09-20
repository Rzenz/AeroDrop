import 'package:flutter/material.dart';
import '../../core/widgets/neu_feedback.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_card.dart';
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
    (label: 'Preparing', statusKeys: ['preparing', 'confirmed']),
    (
      label: 'Ready',
      statusKeys: ['ready', 'ready_for_delivery', 'ready_for_pickup'],
    ),
    (
      label: 'In Transit',
      statusKeys: ['in_transit', 'out_for_delivery', 'picked_up'],
    ),
    (label: 'Delivered', statusKeys: ['delivered']),
    (label: 'Cancelled', statusKeys: ['cancelled', 'rejected', 'failed']),
  ];

  final Set<String> _updatingOrderIds = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _statusTabs.length, vsync: this);
    Future.microtask(() {
      if (mounted) {
        ref.read(vendorOrdersProvider.notifier).loadOrders();
      }
    });
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
    return orders.where((o) => statusKeys.contains(o.effectiveStatus)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(vendorOrdersProvider);
    final allOrders = ordersState.orders;

    return Scaffold(
      backgroundColor: AppColors.base,
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
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Order Dispatch',
                        style: AppTextStyles.heading(
                          fontSize: 20,
                          color: AppColors.textPrimary,
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
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: AppTextStyles.subHead(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: AppColors.border.withValues(alpha: 0.05),
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
                            style: AppTextStyles.label(
                              fontSize: 9.5,
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0,
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
                                Icon(
                                  Icons.assignment_outlined,
                                  color: AppColors.textSecondary,
                                  size: 56,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No ${t.label} orders received.',
                                  style: AppTextStyles.subHead(
                                    color: AppColors.textSecondary,
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

                        final status = order.effectiveStatus;
                        final isUpdating = _updatingOrderIds.contains(order.id);
                        if (status == 'pending') {
                          acceptCb = isUpdating
                              ? null
                              : () => _handleUpdate(order.id, 'confirmed');
                          rejectCb = isUpdating
                              ? null
                              : () => _handleUpdate(order.id, 'cancelled');
                        } else if (status == 'confirmed') {
                          prepareCb = isUpdating
                              ? null
                              : () => _handleUpdate(order.id, 'preparing');
                        } else if (status == 'preparing') {
                          readyCb = isUpdating
                              ? null
                              : () => _handleMarkReady(order.id);
                        } else if (status == 'ready_for_delivery' &&
                            (order.deliveryStatus == null ||
                                order.deliveryStatus?.toLowerCase() ==
                                    'pending')) {
                          readyCb = isUpdating
                              ? null
                              : () => _handleMarkReady(order.id);
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

  Future<void> _handleUpdate(
    String orderId,
    String nextStatus, {
    String? cancellationReason,
  }) async {
    if (_updatingOrderIds.contains(orderId)) return;
    setState(() => _updatingOrderIds.add(orderId));
    HapticFeedback.mediumImpact();
    final success = await ref
        .read(vendorOrdersProvider.notifier)
        .updateOrderStatus(
          orderId,
          nextStatus,
          cancellationReason: cancellationReason ?? 'vendor',
        );
    if (mounted) {
      setState(() => _updatingOrderIds.remove(orderId));
      showNeuSnack(
        context,
        success
            ? 'Order updated to $nextStatus.'
            : 'Failed to update order status.',
        tone: NeuToneKind.success,
      );
    }
  }

  Future<void> _handleMarkReady(String orderId) async {
    if (_updatingOrderIds.contains(orderId)) return;
    setState(() => _updatingOrderIds.add(orderId));
    HapticFeedback.mediumImpact();

    final result = await ref
        .read(vendorOrdersProvider.notifier)
        .markOrderReady(orderId);

    if (mounted) {
      setState(() => _updatingOrderIds.remove(orderId));
      if (result.success) {
        showNeuSnack(
          context,
          result.message,
          tone: result.droneDispatched ? NeuToneKind.success : NeuToneKind.info,
        );
      } else {
        showNeuSnack(context, result.message, tone: NeuToneKind.error);
      }
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
    final status = order.effectiveStatus;
    final statusColor = switch (status) {
      'pending' => AppColors.warning,
      'confirmed' || 'preparing' => AppColors.info,
      'ready_for_delivery' => AppColors.primaryLight,
      'in_transit' => AppColors.accent,
      'delivered' => AppColors.success,
      _ => AppColors.danger,
    };

    final customerTitle =
        order.customerName.isNotEmpty && order.customerName != 'Me'
        ? order.customerName
        : 'Customer (${order.userId.substring(0, 8)})';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuCard(
        onTap: () => context.push('/vendor/orders/${order.id}'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 2),
                      Text(
                        customerTitle,
                        style: AppTextStyles.subHead(
                          fontSize: 14.5,
                          color: AppColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱${order.totalAmount.toStringAsFixed(2)}',
                      style: AppTextStyles.subHead(
                        fontSize: 16,
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        order.statusDisplay,
                        style: AppTextStyles.label(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
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
                        color: AppColors.surfaceSunken,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${i.quantity}x',
                        style: AppTextStyles.label(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        i.productName,
                        style: AppTextStyles.body(
                          fontSize: 12.5,
                          color: AppColors.textPrimary.withValues(alpha: 0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.note_alt_outlined,
                      size: 15,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Note: ${order.notes!}',
                        style: AppTextStyles.caption(
                          fontSize: 12,
                          color: AppColors.accent,
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),

            // Drop-off Location & Details hint info
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: AppColors.textSecondary,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.dropoffLocationName ?? 'Unknown Location',
                    style: AppTextStyles.caption(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Details →',
                  style: AppTextStyles.caption(
                    fontSize: 11.5,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),

            // Drone Status info for Ready for Delivery
            if (status == 'ready_for_delivery') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      (order.deliveryStatus?.toLowerCase() == 'assigning'
                              ? AppColors.info
                              : AppColors.warning)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        (order.deliveryStatus?.toLowerCase() == 'assigning'
                                ? AppColors.info
                                : AppColors.warning)
                            .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      order.deliveryStatus?.toLowerCase() == 'assigning'
                          ? Icons.flight_takeoff_rounded
                          : Icons.hourglass_top_rounded,
                      size: 16,
                      color: order.deliveryStatus?.toLowerCase() == 'assigning'
                          ? AppColors.info
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.deliveryStatus?.toLowerCase() == 'assigning'
                            ? 'Drone DRN-001 en route to store for pickup.'
                            : 'Waiting for available drone. Auto-dispatches when drone is free.',
                        style: AppTextStyles.caption(
                          fontSize: 11.5,
                          color: AppColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

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
                        label: 'Accept Order',
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
                  if (onReady != null) ...[
                    Expanded(
                      child: _ActionBtn(
                        label: status == 'ready_for_delivery'
                            ? 'Dispatch Drone'
                            : 'Mark as Ready',
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
              style: AppTextStyles.label(
                fontSize: 12,
                color: isAccent ? AppColors.primaryDark : color,
                fontWeight: FontWeight.bold,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
