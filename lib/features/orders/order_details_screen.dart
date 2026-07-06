import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../mock_data/orders_mock.dart';

class OrderDetailsScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final order = mockOrders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => mockOrders.first,
    );

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Details', style: AppTextStyles.subHead(fontSize: 16, color: Colors.white)),
            Text(order.orderNumber, style: const TextStyle(color: AppColors.primaryLight, fontSize: 11)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          // Status timeline
          _SectionCard(
            title: 'Order Status',
            icon: Icons.timeline_rounded,
            child: _StatusTimeline(status: order.status),
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
                _InfoRow(label: 'Phone', value: order.customerPhone),
                const SizedBox(height: 8),
                _InfoRow(label: 'Drop-off', value: order.dropOffLocation),
                const SizedBox(height: 8),
                _InfoRow(label: 'Date', value: _formatDate(order.createdAt)),
                if (order.cancelReason != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Cancel Reason', value: order.cancelReason!, valueColor: AppColors.danger),
                ],
              ],
            ),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 16),

          // Items
          _SectionCard(
            title: 'Items (${order.items.length})',
            icon: Icons.shopping_bag_outlined,
            child: Column(
              children: order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.imageUrl,
                        width: 52, height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 52, height: 52,
                          color: AppColors.cardDark2,
                          child: const Icon(Icons.image_outlined, size: 20, color: AppColors.textSecondaryDark),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName, style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text('${item.vendorName} · x${item.quantity}', style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark)),
                        ],
                      ),
                    ),
                    Text('₱${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              )).toList(),
            ),
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 16),

          // Payment
          _SectionCard(
            title: 'Payment',
            icon: Icons.receipt_long_outlined,
            child: Column(
              children: [
                _InfoRow(label: 'Method', value: _methodLabel(order.paymentMethod)),
                const SizedBox(height: 8),
                _InfoRow(label: 'Status', value: _paymentStatusLabel(order.paymentStatus),
                    valueColor: _paymentStatusColor(order.paymentStatus)),
                const SizedBox(height: 8),
                _InfoRow(label: 'Reference', value: order.referenceNumber),
                const SizedBox(height: 10),
                const Divider(color: AppColors.borderDark),
                const SizedBox(height: 10),
                _InfoRow(label: 'Total', value: '₱${order.totalAmount.toStringAsFixed(2)}', valueColor: AppColors.accent, bold: true),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  String _methodLabel(MockPaymentMethod m) => switch (m) {
    MockPaymentMethod.gcash => 'GCash',
    MockPaymentMethod.cash => 'Cash on Delivery',
    MockPaymentMethod.creditCard => 'Credit / Debit Card',
  };
  String _paymentStatusLabel(MockPaymentStatus s) => switch (s) {
    MockPaymentStatus.paid => 'Paid',
    MockPaymentStatus.pending => 'Unpaid',
    MockPaymentStatus.failed => 'Failed',
    MockPaymentStatus.refunded => 'Refunded',
  };
  Color _paymentStatusColor(MockPaymentStatus s) => switch (s) {
    MockPaymentStatus.paid => AppColors.success,
    MockPaymentStatus.pending => AppColors.warning,
    MockPaymentStatus.failed => AppColors.danger,
    MockPaymentStatus.refunded => AppColors.info,
  };
}

// ─── Status Timeline ─────────────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  final MockOrderStatus status;
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
    return switch (status) {
      MockOrderStatus.pending => 0,
      MockOrderStatus.preparing => 2,
      MockOrderStatus.ready => 3,
      MockOrderStatus.pickedUp => 4,
      MockOrderStatus.delivered => 6,
      MockOrderStatus.cancelled => -1,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (status == MockOrderStatus.cancelled) {
      return Row(
        children: [
          const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Text('Order Cancelled', style: AppTextStyles.body(fontSize: 13, color: AppColors.danger)),
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
                    color: done ? AppColors.accent.withValues(alpha: 0.15) : AppColors.borderDark,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: done ? AppColors.accent : AppColors.borderDark,
                      width: current ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    step.icon,
                    size: 16,
                    color: done ? AppColors.accent : AppColors.textSecondaryDark,
                  ),
                ),
                if (i < _steps.length - 1)
                  Container(width: 1.5, height: 20, color: done ? AppColors.accent.withValues(alpha: 0.4) : AppColors.borderDark),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 20),
              child: Text(
                step.label,
                style: TextStyle(
                  color: done ? Colors.white : AppColors.textSecondaryDark,
                  fontWeight: current ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
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

  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryLight, size: 18),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.subHead(fontSize: 14, color: Colors.white)),
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

  const _InfoRow({required this.label, required this.value, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
          child: Text(label, style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark)),
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
