import 'package:flutter/material.dart';
import '../../core/widgets/custom_app_bar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/models/order_model.dart';
import '../../core/providers/order_provider.dart';
import '../../core/services/supabase_service.dart';

final orderDetailsProvider = FutureProvider.family<OrderModel?, String>((
  ref,
  id,
) async {
  if (!SupabaseService.isConfigured) return null;

  // Try to find in student orders cache first
  try {
    final studentOrders = ref.read(orderProvider).orders;
    final matchStudent = studentOrders.where((o) => o.id == id).firstOrNull;
    if (matchStudent != null) return matchStudent;
  } catch (_) {}

  // Try to find in vendor orders cache second
  try {
    final vendorOrders = ref.read(vendorOrdersProvider).orders;
    final matchVendor = vendorOrders.where((o) => o.id == id).firstOrNull;
    if (matchVendor != null) return matchVendor;
  } catch (_) {}

  // Otherwise, query Supabase directly
  try {
    final res = await SupabaseService.client
        .from('orders')
        .select('''
          *,
          vendor:users!vendor_id(full_name, business_name),
          customer:users!user_id(full_name, phone_number),
          campus_locations!delivery_location_id(name),
          order_items(product_name, quantity, unit_price)
        ''')
        .eq('id', id)
        .maybeSingle();

    if (res == null) return null;
    return OrderModel.fromMap(Map<String, dynamic>.from(res));
  } catch (e) {
    debugPrint('Error loading order details: $e');
    return null;
  }
});

class OrderDetailsScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailsProvider(orderId));

    return Scaffold(
      backgroundColor: AppColors.base,
      appBar: CustomAppBar(
        title: 'Order Details',
        subtitle: 'ID: ${orderId.substring(0, 8).toUpperCase()}',
      ),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return Center(
              child: Text(
                'Order not found.',
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              // Status timeline
              _SectionCard(
                title: 'Order Status',
                icon: Icons.timeline_rounded,
                child: _StatusTimeline(status: order.orderStatus),
              ).animate().fadeIn(delay: 50.ms),
              const SizedBox(height: 16),

              // Vendor + customer
              _SectionCard(
                title: 'Order Info',
                icon: Icons.info_outline_rounded,
                child: Column(
                  children: [
                    _InfoRow(label: 'Vendor', value: order.vendorName),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Customer', value: order.customerName),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Phone',
                      value: order.customerPhone.isNotEmpty
                          ? order.customerPhone
                          : 'Not provided',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Drop-off',
                      value: order.dropoffLocationName ?? 'UCLM Campus',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Date',
                      value: _formatDate(order.createdAt),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 16),

              // Items
              _SectionCard(
                title: 'Items (${order.items.length})',
                icon: Icons.shopping_bag_outlined,
                child: Column(
                  children: order.items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  '',
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 52,
                                    height: 52,
                                    color: AppColors.surfaceRaised,
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: 20,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: AppTextStyles.body(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${order.vendorName} · x${item.quantity}',
                                      style: AppTextStyles.body(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₱${(item.unitPrice * item.quantity).toStringAsFixed(2)}',
                                style: AppTextStyles.subHead(
                                  fontSize: 14,
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 16),

              // Payment
              _SectionCard(
                title: 'Payment',
                icon: Icons.receipt_long_outlined,
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Method',
                      value: _methodLabel(order.paymentMethod),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Status',
                      value: _paymentStatusLabel(order.paymentStatus),
                      valueColor: _paymentStatusColor(order.paymentStatus),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Reference',
                      value: order.paymentReference ?? 'N/A',
                    ),
                    const SizedBox(height: 10),
                    Divider(color: AppColors.border),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: 'Total',
                      value: '₱${order.totalAmount.toStringAsFixed(2)}',
                      valueColor: AppColors.accent,
                      bold: true,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms),
            ],
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

  String _formatDate(DateTime dt) =>
      '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _methodLabel(String m) {
    switch (m.toLowerCase()) {
      case 'gcash' || 'gcash_simulated':
        return 'GCash';
      case 'cash' || 'cod':
        return 'Cash on Delivery';
      case 'card' || 'creditcard':
        return 'Credit / Debit Card';
      default:
        return m;
    }
  }

  String _paymentStatusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'pending':
        return 'Unpaid';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      default:
        return s;
    }
  }

  Color _paymentStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'paid':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'failed':
        return AppColors.danger;
      case 'refunded':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }
}

// ─── Status Timeline ─────────────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  final String status;
  const _StatusTimeline({required this.status});

  static const _steps = [
    (icon: Icons.receipt_outlined, label: 'Order Placed'),
    (icon: Icons.check_circle_outline_rounded, label: 'Vendor Accepted'),
    (icon: Icons.restaurant_outlined, label: 'Preparing'),
    (icon: Icons.inventory_2_outlined, label: 'Ready for Pickup'),
    (icon: Icons.flight_takeoff_rounded, label: 'Drone Picked Up'),
    (icon: Icons.flight_land_rounded, label: 'In Transit'),
    (icon: Icons.check_circle_rounded, label: 'Delivered'),
  ];

  int get _activeStep {
    return switch (status.toLowerCase()) {
      'pending' => 0,
      'confirmed' => 1,
      'preparing' => 2,
      'ready_for_delivery' || 'ready' => 3,
      'picked_up' => 4,
      'in_transit' => 5,
      'delivered' || 'completed' => 6,
      'cancelled' => -1,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (status.toLowerCase() == 'cancelled') {
      return Row(
        children: [
          const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Text(
            'Order Cancelled',
            style: AppTextStyles.body(fontSize: 13, color: AppColors.danger),
          ),
        ],
      );
    }

    final active = _activeStep;
    return Column(
      children: _steps.asMap().entries.map((entry) {
        final i = entry.key;
        final step = entry.value;
        final done = i <= active;
        final current = i == active;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.border,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: done ? AppColors.accent : AppColors.border,
                      width: current ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    step.icon,
                    size: 16,
                    color: done ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
                if (i < _steps.length - 1)
                  Container(
                    width: 1.5,
                    height: 20,
                    color: done
                        ? AppColors.accent.withValues(alpha: 0.4)
                        : AppColors.border,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 20),
              child: Text(
                step.label,
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: done ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

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
              Icon(icon, color: AppColors.primaryLight, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.subHead(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
  final bool bold;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: AppTextStyles.body(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 15 : 13,
            ),
          ),
        ),
      ],
    );
  }
}
