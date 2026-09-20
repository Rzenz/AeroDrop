import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/models/order_model.dart';
import '../../core/models/delivery_model.dart';
import '../../core/providers/order_provider.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/neu_feedback.dart';
import 'receipt_screen.dart';
import 'widgets/order_review_dialog.dart';

final orderDetailsProvider = FutureProvider.family<OrderModel?, String>((
  ref,
  id,
) async {
  if (!SupabaseService.isConfigured) return null;

  // Always query Supabase directly first to get authoritative live order & delivery data
  try {
    final res = await SupabaseService.client
        .from('orders')
        .select('''
          *,
          vendor:users!vendor_id(full_name, business_name),
          customer:users!user_id(full_name, phone_number),
          campus_locations!delivery_location_id(name),
          order_items(product_id, product_name, quantity, unit_price),
          deliveries(id, status, progress, drone_id, estimated_delivery_seconds, delivery_started_at, delivery_completed_at, created_at)
        ''')
        .eq('id', id)
        .maybeSingle();

    if (res != null) {
      return OrderModel.fromMap(Map<String, dynamic>.from(res));
    }
  } catch (e) {
    debugPrint('Direct query order details error: $e');
  }

  // Fallback to student orders cache
  try {
    final studentOrders = ref.read(orderProvider).orders;
    final matchStudent = studentOrders.where((o) => o.id == id).firstOrNull;
    if (matchStudent != null) return matchStudent;
  } catch (_) {}

  // Fallback to vendor orders cache
  try {
    final vendorOrders = ref.read(vendorOrdersProvider).orders;
    final matchVendor = vendorOrders.where((o) => o.id == id).firstOrNull;
    if (matchVendor != null) return matchVendor;
  } catch (_) {}

  return null;
});

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _deliveriesChannel;

  @override
  void initState() {
    super.initState();
    _setupRealtime();
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    _deliveriesChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    if (!SupabaseService.isConfigured || widget.orderId.isEmpty) return;

    try {
      _ordersChannel = SupabaseService.client
          .channel('order_details_orders:${widget.orderId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: widget.orderId,
            ),
            callback: (_) {
              if (mounted) {
                ref.invalidate(orderDetailsProvider(widget.orderId));
                ref.read(orderProvider.notifier).loadOrders();
                ref.read(vendorOrdersProvider.notifier).loadOrders();
              }
            },
          )
          .subscribe();

      _deliveriesChannel = SupabaseService.client
          .channel('order_details_deliveries:${widget.orderId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'deliveries',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'order_id',
              value: widget.orderId,
            ),
            callback: (_) {
              if (mounted) {
                ref.invalidate(orderDetailsProvider(widget.orderId));
                ref.read(deliveryProvider.notifier).loadDeliveriesFromSupabase();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('OrderDetails realtime error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailsProvider(widget.orderId));
    final deliveries = ref.watch(deliveryProvider);

    return Scaffold(
      backgroundColor: AppColors.base,
      appBar: CustomAppBar(
        title: 'Order Details',
        subtitle: 'ID: ${widget.orderId.length > 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId}',
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.base,
        onRefresh: () async {
          ref.invalidate(orderDetailsProvider(widget.orderId));
          await ref.read(orderProvider.notifier).loadOrders();
          await ref.read(vendorOrdersProvider.notifier).loadOrders();
          await ref.read(deliveryProvider.notifier).loadDeliveriesFromSupabase();
        },
        child: orderAsync.when(
          data: (baseOrder) {
            if (baseOrder == null) {
              return Center(
                child: Text(
                  'Order not found.',
                  style: AppTextStyles.body(color: AppColors.textSecondary),
                ),
              );
            }

            // Merge live delivery data if available in deliveryProvider
            final liveDelivery = deliveries.where((d) {
              return d.id == baseOrder.deliveryId || d.id == widget.orderId;
            }).firstOrNull;

            final isDelivered = baseOrder.effectiveStatus == 'delivered' ||
                baseOrder.deliveryStatus?.toLowerCase() == 'delivered' ||
                liveDelivery?.status == DeliveryStatus.delivered;

            final double effectiveProgress = isDelivered
                ? 1.0
                : (liveDelivery?.progress ?? baseOrder.deliveryProgress ?? 0.0)
                    .clamp(0.0, 1.0);

            final order = baseOrder;

            final isVendor = GoRouterState.of(context)
                .uri
                .path
                .startsWith('/vendor');

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                // Status timeline
                _SectionCard(
                  title: 'Order Status',
                  icon: Icons.timeline_rounded,
                  child: _StatusTimeline(status: isDelivered ? 'delivered' : order.effectiveStatus),
                ).animate().fadeIn(delay: 50.ms),
                const SizedBox(height: 16),

                // Drone Delivery info if assigned/active
                if (order.deliveryStatus != null || order.droneId != null || liveDelivery != null) ...[
                  _SectionCard(
                    title: 'Drone Delivery',
                    icon: Icons.flight_takeoff_rounded,
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Assigned Drone',
                          value: (order.droneId != null || liveDelivery?.droneId != null)
                              ? (liveDelivery?.droneId ?? order.droneId ?? 'DRN-001')
                              : 'Assigning drone...',
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          label: 'Delivery Status',
                          value: isDelivered
                              ? 'Delivered'
                              : switch ((liveDelivery?.status.name ?? order.deliveryStatus)?.toLowerCase()) {
                                  'assigning' => 'Heading to Pickup',
                                  'intransit' || 'in_transit' => 'In Flight / In Transit',
                                  'delivered' => 'Delivered',
                                  'cancelled' => 'Cancelled',
                                  _ => order.deliveryStatus ?? 'Pending Dispatch',
                                },
                          valueColor: isDelivered
                              ? AppColors.success
                              : switch ((liveDelivery?.status.name ?? order.deliveryStatus)?.toLowerCase()) {
                                  'delivered' => AppColors.success,
                                  'intransit' || 'in_transit' => AppColors.accent,
                                  'assigning' => AppColors.primaryLight,
                                  _ => AppColors.warning,
                                },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Flight Progress',
                              style: AppTextStyles.caption(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${(effectiveProgress * 100).round()}%',
                              style: AppTextStyles.caption(
                                fontSize: 11,
                                color: isDelivered ? AppColors.success : AppColors.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: effectiveProgress,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation(
                              isDelivered ? AppColors.success : AppColors.accent,
                            ),
                            minHeight: 6,
                          ),
                        ),
                        if (order.deliveryStartedAt != null) ...[
                          const SizedBox(height: 8),
                          _InfoRow(
                            label: 'Dispatched At',
                            value: _formatDate(order.deliveryStartedAt!),
                          ),
                        ],
                        if (isDelivered && (order.deliveryCompletedAt != null || liveDelivery?.deliveredAt != null)) ...[
                          const SizedBox(height: 8),
                          _InfoRow(
                            label: 'Delivered At',
                            value: _formatDate(order.deliveryCompletedAt ?? liveDelivery!.deliveredAt!),
                            valueColor: AppColors.success,
                          ),
                        ],
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 16),
                ],

                // Delivery Location
                _SectionCard(
                  title: 'Delivery Location',
                  icon: Icons.location_on_rounded,
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Campus Dropoff Pad',
                        value: order.dropoffLocationName ?? 'Drop-off Pad',
                      ),
                      if (order.customerPhone.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          label: 'Recipient Phone',
                          value: order.customerPhone,
                        ),
                      ],
                      if (order.notes != null && order.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          label: 'Delivery Notes',
                          value: order.notes!,
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 16),

                // Order Items
                _SectionCard(
                  title: 'Items (${order.items.length})',
                  icon: Icons.fastfood_rounded,
                  child: Column(
                    children: [
                      for (int i = 0; i < order.items.length; i++) ...[
                        if (i > 0) const Divider(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '${order.items[i].quantity}x',
                                  style: AppTextStyles.caption(
                                    fontSize: 11,
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                order.items[i].productName,
                                style: AppTextStyles.body(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '₱${(order.items[i].unitPrice * order.items[i].quantity).toStringAsFixed(2)}',
                              style: AppTextStyles.body(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 180.ms),
                const SizedBox(height: 16),

                // Order Summary / Payment
                _SectionCard(
                  title: 'Payment Summary',
                  icon: Icons.receipt_rounded,
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Subtotal',
                        value: '₱${order.subtotal > 0 ? order.subtotal.toStringAsFixed(2) : (order.totalAmount - order.deliveryFee).toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        label: 'Drone Delivery Fee',
                        value: '₱${order.deliveryFee.toStringAsFixed(2)}',
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Amount',
                            style: AppTextStyles.title(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '₱${order.totalAmount.toStringAsFixed(2)}',
                            style: AppTextStyles.title(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        label: 'Payment Method',
                        value: _methodLabel(order.paymentMethod),
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        label: 'Payment Status',
                        value: isDelivered ? 'Paid' : order.paymentStatus.toUpperCase(),
                        valueColor: (isDelivered || order.paymentStatus.toLowerCase() == 'paid')
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      if (order.paymentReference != null &&
                          order.paymentReference!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          label: 'Ref No.',
                          value: order.paymentReference!,
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 24),

                // Action Buttons Hierarchy:
                // 1. View Official Receipt
                // 2. Contact Support (with associated orderId & deliveryId)
                // 3. Track My Order / Track Delivery

                // Rate Order / Write Review Button (Customer Delivered orders only)
                if (isDelivered && !isVendor) ...[
                  NeuButton(
                    text: 'Rate Order / Review',
                    icon: Icons.star_rounded,
                    variant: NeuButtonVariant.accent,
                    onPressed: () {
                      OrderReviewDialog.show(context, order: order);
                    },
                  ).animate().fadeIn(delay: 225.ms),
                  const SizedBox(height: 12),
                ],

                // View Official Receipt Button
                NeuButton(
                  text: 'View Official Receipt',
                  icon: Icons.receipt_long_rounded,
                  variant: NeuButtonVariant.neutral,
                  onPressed: () {
                    final lines = order.items
                        .map(
                          (item) => ReceiptLine(
                            name: item.productName,
                            quantity: item.quantity,
                            unitPrice: item.unitPrice,
                          ),
                        )
                        .toList();

                    final receiptData = ReceiptData(
                      orderRef: order.id,
                      vendorName: order.vendorName,
                      customerName: isVendor
                          ? order.customerName
                          : null,
                      customerPhone: order.customerPhone,
                      lines: lines,
                      subtotal: order.subtotal > 0
                          ? order.subtotal
                          : (order.totalAmount - order.deliveryFee),
                      deliveryFee: order.deliveryFee,
                      total: order.totalAmount,
                      paymentLabel: _methodLabel(order.paymentMethod),
                      placedAt: order.createdAt,
                      dropoffName: order.dropoffLocationName,
                      customerNote: order.notes,
                      orderStatus: order.statusDisplay,
                      deliveryId: order.deliveryId ?? liveDelivery?.id,
                    );
                    final receiptPath =
                        isVendor ? '/vendor/receipt' : '/user/receipt';
                    context.push(receiptPath, extra: receiptData);
                  },
                ).animate().fadeIn(delay: 250.ms),
                const SizedBox(height: 12),

                // Customer Order Cancellation Action
                if (!isVendor) ...[
                  if (order.effectiveStatus.toLowerCase() == 'pending' ||
                      order.effectiveStatus.toLowerCase() == 'confirmed' ||
                      order.effectiveStatus.toLowerCase() == 'preparing') ...[
                    NeuButton(
                      text: 'Cancel Order',
                      icon: Icons.cancel_outlined,
                      variant: NeuButtonVariant.neutral,
                      onPressed: () => _showCancelOrderDialog(context, order),
                    ).animate().fadeIn(delay: 260.ms),
                    const SizedBox(height: 12),
                  ] else if (order.effectiveStatus.toLowerCase() == 'ready_for_delivery' ||
                      order.effectiveStatus.toLowerCase() == 'in_transit') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Order is packed or in flight and cannot be cancelled.',
                              style: AppTextStyles.caption(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 260.ms),
                    const SizedBox(height: 12),
                  ],
                ],

                // Contact Support Button
                NeuButton(
                  text: 'Contact Support',
                  icon: Icons.support_agent_rounded,
                  variant: NeuButtonVariant.neutral,
                  onPressed: () {
                    final targetDeliveryId = order.deliveryId ?? liveDelivery?.id;
                    final delQuery = targetDeliveryId != null && targetDeliveryId.isNotEmpty
                        ? '&deliveryId=$targetDeliveryId'
                        : '';
                    context.push('/shared/help?orderId=${order.id}$delQuery');
                  },
                ).animate().fadeIn(delay: 275.ms),

                // Track My Order (Customer) / Track Delivery (Vendor)
                if ((order.deliveryId != null && order.deliveryId!.isNotEmpty) ||
                    liveDelivery != null) ...[
                  const SizedBox(height: 12),
                  NeuButton(
                    text: isVendor ? 'Track Delivery' : 'Track My Order',
                    icon: Icons.navigation_rounded,
                    variant: NeuButtonVariant.accent,
                    onPressed: () {
                      final targetDeliveryId = order.deliveryId ?? liveDelivery?.id ?? '';
                      final trackPath = isVendor
                          ? '/vendor/track/details?id=$targetDeliveryId'
                          : '/user/track/details?id=$targetDeliveryId';
                      context.push(trackPath);
                    },
                  ).animate().fadeIn(delay: 300.ms),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (err, _) => Center(
            child: Text(
              'Error: $err',
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  void _showCancelOrderDialog(BuildContext context, OrderModel order) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Cancel Order?',
              style: AppTextStyles.title(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel this order?\n\n'
          'Since payment was simulated digitally, a full simulated refund of ₱${order.totalAmount.toStringAsFixed(2)} will be credited back immediately.',
          style: AppTextStyles.body(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Keep Order',
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Yes, Cancel',
              style: AppTextStyles.body(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true && mounted) {
        final success = await ref
            .read(orderProvider.notifier)
            .cancelOrder(
              order.id,
              cancellationReason: 'Customer cancelled from order details',
            );
        if (mounted) {
          if (success) {
            ref.invalidate(orderDetailsProvider(order.id));
            if (context.mounted) {
              showNeuSnack(
                context,
                'Order cancelled successfully. Refund processed.',
                tone: NeuToneKind.success,
              );
            }
          } else {
            if (context.mounted) {
              showNeuSnack(
                context,
                'Unable to cancel order. It may have already been dispatched.',
                tone: NeuToneKind.error,
              );
            }
          }
        }
      }
    });
  }

  static String _methodLabel(String method) {
    return switch (method.toLowerCase()) {
      'cash' || 'cash_on_delivery' => 'Cash on Delivery',
      'gcash_simulated' => 'GCash (Digital Payment)',
      'card' || 'card_simulated' => 'Credit / Debit Card',
      _ => method,
    };
  }

  static String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.subHead(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.caption(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTextStyles.body(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final String status;
  const _StatusTimeline({required this.status});

  static const _steps = [
    ('pending', 'Pending'),
    ('confirmed', 'Confirmed'),
    ('preparing', 'Preparing'),
    ('ready_for_delivery', 'Ready for Delivery'),
    ('in_transit', 'In Transit'),
    ('delivered', 'Delivered'),
  ];

  int _currentIndex() {
    final s = status.toLowerCase();
    if (s == 'cancelled' || s == 'rejected' || s == 'failed') return -1;
    final idx = _steps.indexWhere((step) => step.$1 == s);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final cur = _currentIndex();
    final isCancelled = cur == -1;

    if (isCancelled) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 20),
            const SizedBox(width: 8),
            Text(
              'Order Cancelled',
              style: AppTextStyles.body(
                color: AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < _steps.length; i++) ...[
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= cur
                      ? (i == _steps.length - 1 ? AppColors.success : AppColors.accent)
                      : AppColors.border,
                ),
                child: Center(
                  child: Icon(
                    i <= cur ? Icons.check_rounded : Icons.circle,
                    size: i <= cur ? 14 : 6,
                    color: i <= cur ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _steps[i].$2,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    fontWeight: i == cur ? FontWeight.bold : FontWeight.normal,
                    color: i <= cur
                        ? (i == _steps.length - 1 ? AppColors.success : AppColors.textPrimary)
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              if (i == cur)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (i == _steps.length - 1 ? AppColors.success : AppColors.accent).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'CURRENT',
                    style: AppTextStyles.caption(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: i == _steps.length - 1 ? AppColors.success : AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
          if (i < _steps.length - 1)
            Container(
              margin: const EdgeInsets.only(left: 10),
              width: 2,
              height: 16,
              color: i < cur ? AppColors.accent : AppColors.border,
            ),
        ],
      ],
    );
  }
}
