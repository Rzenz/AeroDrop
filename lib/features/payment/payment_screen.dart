import 'package:flutter/material.dart';
import '../../core/widgets/neu_feedback.dart';
import '../../core/widgets/custom_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/models/order_model.dart';
import '../../core/providers/order_provider.dart';
import '../../core/services/supabase_service.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String? orderId;
  const PaymentScreen({super.key, this.orderId});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _method = 'gcash';
  bool _paid = false;
  bool _processing = false;
  OrderModel? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    if (widget.orderId == null) {
      setState(() {
        _loading = false;
        _error = 'Invalid order reference.';
      });
      return;
    }

    try {
      // First check in local order list
      final localOrders = ref.read(orderProvider).orders;
      final localMatch = localOrders
          .where((o) => o.id == widget.orderId)
          .firstOrNull;

      if (localMatch != null) {
        setState(() {
          _order = localMatch;
          _paid = localMatch.paymentStatus.toLowerCase() == 'paid';
          _loading = false;
        });
        return;
      }

      // Query database if not in provider list
      if (SupabaseService.isConfigured) {
        final res = await SupabaseService.client
            .from('orders')
            .select(
              '*, users!vendor_id(full_name, business_name), '
              'campus_locations!delivery_location_id(name), '
              'order_items(product_name, quantity, unit_price)',
            )
            .eq('id', widget.orderId!)
            .maybeSingle();

        if (res != null) {
          final mapped = OrderModel.fromMap(res);
          setState(() {
            _order = mapped;
            _paid = mapped.paymentStatus.toLowerCase() == 'paid';
            _loading = false;
          });
          return;
        }
      }

      setState(() {
        _loading = false;
        _error = 'Order not found in database.';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load order: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.base,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    if (_error != null || _order == null) {
      return Scaffold(
        backgroundColor: AppColors.base,
        appBar: CustomAppBar(title: 'Payment Error'),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 60,
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Unable to find order.',
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadOrderDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.base,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final order = _order!;

    return Scaffold(
      backgroundColor: AppColors.base,
      appBar: CustomAppBar(title: 'Payment'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Amount display
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.base,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.flight_rounded,
                  color: AppColors.textSecondary,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  'Total Amount',
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₱${order.totalAmount.toStringAsFixed(2)}',
                  style: AppTextStyles.display(
                    fontSize: 36,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AD-${order.id.substring(0, 8).toUpperCase()}',
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                if (_paid)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'PAID',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Text(
                      'AWAITING PAYMENT',
                      style: AppTextStyles.label(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
          const SizedBox(height: 24),

          // Payment method selection
          if (!_paid) ...[
            Text(
              'Select Payment Method',
              style: AppTextStyles.subHead(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _MethodCard(
              id: 'gcash',
              selected: _method == 'gcash',
              icon: Icons.phone_android_rounded,
              label: 'GCash',
              subtitle: 'Pay via GCash mobile wallet',
              color: const Color(0xFF007DC5),
              onTap: () => setState(() => _method = 'gcash'),
            ).animate().fadeIn(delay: 80.ms),
            const SizedBox(height: 10),
            _MethodCard(
              id: 'cash',
              selected: _method == 'cash',
              icon: Icons.payments_outlined,
              label: 'Cash on Delivery',
              subtitle: 'Pay cash when order arrives',
              color: AppColors.success,
              onTap: () => setState(() => _method = 'cash'),
            ).animate().fadeIn(delay: 120.ms),
            const SizedBox(height: 10),
            _MethodCard(
              id: 'card',
              selected: _method == 'card',
              icon: Icons.credit_card_rounded,
              label: 'Credit / Debit Card',
              subtitle: 'Visa, Mastercard accepted',
              color: const Color(0xFFA855F7),
              onTap: () => setState(() => _method = 'card'),
            ).animate().fadeIn(delay: 160.ms),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _processing ? null : _processPayment,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.bgDark,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _processing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.bgDark,
                      ),
                    )
                  : Text(
                      'Confirm Payment',
                      style: AppTextStyles.subHead(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ).animate().fadeIn(delay: 200.ms),
          ],

          // Receipt after payment
          if (_paid) ...[
            const SizedBox(height: 8),
            _Receipt(
              order: order,
              method: _method,
            ).animate().fadeIn().slideY(begin: 0.1),
          ],
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    HapticFeedback.mediumImpact();
    setState(() => _processing = true);

    try {
      if (SupabaseService.isConfigured && widget.orderId != null) {
        await SupabaseService.client
            .from('orders')
            .update({
              'payment_status': 'paid',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', widget.orderId!);

        // Refresh local orders cache
        await ref.read(orderProvider.notifier).loadOrders();
      }

      if (!mounted) return;
      setState(() {
        _processing = false;
        _paid = true;
      });
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        showNeuSnack(
          context,
          'Payment transaction failed: $e',
          tone: NeuToneKind.error,
        );
      }
    }
  }
}

class _MethodCard extends StatelessWidget {
  final String id;
  final bool selected;
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MethodCard({
    required this.id,
    required this.selected,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : AppColors.base,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.subHead(
                      fontSize: 14,
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.body(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  final OrderModel order;
  final String method;
  const _Receipt({required this.order, required this.method});

  @override
  Widget build(BuildContext context) {
    final methodLabel = switch (method) {
      'gcash' => 'GCash',
      'cash' => 'Cash on Delivery',
      _ => 'Credit / Debit Card',
    };

    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.success,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Payment Receipt',
                style: AppTextStyles.subHead(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _receiptRow(
            'Order Number',
            'AD-${order.id.substring(0, 8).toUpperCase()}',
          ),
          _receiptRow(
            'Reference No.',
            'PAY-${order.id.substring(0, 8).toUpperCase()}',
          ),
          _receiptRow('Payment Method', methodLabel),
          _receiptRow('Vendor', order.vendorName),
          Divider(color: AppColors.border, height: 24),
          _receiptRow(
            'Total Paid',
            '₱${order.totalAmount.toStringAsFixed(2)}',
            bold: true,
            valueColor: AppColors.accent,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.go('/user/orders'),
            icon: const Icon(Icons.list_alt_rounded),
            label: const Text('View Orders'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.caption(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
