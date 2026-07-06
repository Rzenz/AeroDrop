import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/auth_provider.dart';
import '../../mock_data/cart_mock.dart';
import '../../mock_data/orders_mock.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _selectedLocation = campusDropOffLocations.first;
  String _paymentMethod = 'gcash';
  bool _placing = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final cart = cartNotifier.value;
    final total = cartNotifier.totalAmount + 20.0;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text('Checkout', style: AppTextStyles.subHead(fontSize: 18, color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Customer info
          _SectionCard(
            title: 'Customer Information',
            icon: Icons.person_outline_rounded,
            child: Column(
              children: [
                _InfoRow(label: 'Name', value: user?.name ?? 'Juan Dela Cruz'),
                const SizedBox(height: 8),
                _InfoRow(label: 'Email', value: user?.email ?? 'juan@gmail.com'),
                const SizedBox(height: 8),
                _InfoRow(label: 'Phone', value: user?.phoneNumber ?? '+63 917 123 4567'),
              ],
            ),
          ).animate().fadeIn(delay: 50.ms),
          const SizedBox(height: 16),

          // Items
          _SectionCard(
            title: 'Items Ordered',
            icon: Icons.shopping_bag_outlined,
            child: Column(
              children: cart.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.imageUrl,
                        width: 48, height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 48, height: 48,
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
                          Text(item.productName, style: AppTextStyles.body(fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(item.vendorName, style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('x${item.quantity}', style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark)),
                        Text('₱${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              )).toList(),
            ),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 16),

          // Drop-off location
          _SectionCard(
            title: 'Campus Drop-off Location',
            icon: Icons.location_on_outlined,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedLocation,
              dropdownColor: AppColors.cardDark2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bgDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderDark),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              items: campusDropOffLocations.map((loc) => DropdownMenuItem(
                value: loc,
                child: Text(loc, style: const TextStyle(fontSize: 13)),
              )).toList(),
              onChanged: (v) => setState(() => _selectedLocation = v!),
            ),
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 16),

          // Payment method
          _SectionCard(
            title: 'Payment Method',
            icon: Icons.payment_rounded,
            child: Column(
              children: [
                _PaymentOption(
                  value: 'gcash',
                  groupValue: _paymentMethod,
                  icon: Icons.phone_android_rounded,
                  label: 'GCash',
                  color: const Color(0xFF007DC5),
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                ),
                _PaymentOption(
                  value: 'cash',
                  groupValue: _paymentMethod,
                  icon: Icons.payments_outlined,
                  label: 'Cash on Delivery',
                  color: AppColors.success,
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                ),
                _PaymentOption(
                  value: 'card',
                  groupValue: _paymentMethod,
                  icon: Icons.credit_card_rounded,
                  label: 'Credit / Debit Card',
                  color: const Color(0xFFA855F7),
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 16),

          // Order summary
          _SectionCard(
            title: 'Order Summary',
            icon: Icons.receipt_long_outlined,
            child: Column(
              children: [
                _SummaryRow(label: 'Subtotal', value: '₱${cartNotifier.totalAmount.toStringAsFixed(2)}'),
                const SizedBox(height: 6),
                _SummaryRow(label: 'Drone Delivery Fee', value: '₱20.00'),
                const SizedBox(height: 10),
                const Divider(color: AppColors.borderDark),
                const SizedBox(height: 10),
                _SummaryRow(
                  label: 'Total',
                  value: '₱${total.toStringAsFixed(2)}',
                  valueColor: AppColors.accent,
                  bold: true,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 32),

          // Confirm button
          FilledButton(
            onPressed: _placing ? null : _placeOrder,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.bgDark,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _placing
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgDark),
                  )
                : const Text('Confirm Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    HapticFeedback.mediumImpact();
    setState(() => _placing = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    cartNotifier.clear();
    if (!mounted) return;
    setState(() => _placing = false);
    context.go('/user/orders');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Order placed successfully! 🎉'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ─── Shared widgets ────────────────────────────────────────────────────────

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
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 55,
          child: Text(label, style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: AppTextStyles.body(fontSize: 13, color: Colors.white))),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String value;
  final String groupValue;
  final IconData icon;
  final String label;
  final Color color;
  final ValueChanged<String?> onChanged;

  const _PaymentOption({
    required this.value,
    required this.groupValue,
    required this.icon,
    required this.label,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppColors.bgDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : AppColors.borderDark, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? color : AppColors.textSecondaryDark, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textSecondaryDark, fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _SummaryRow({required this.label, required this.value, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.body(fontSize: 13, color: bold ? Colors.white : AppColors.textSecondaryDark)),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: bold ? 16 : 13,
          ),
        ),
      ],
    );
  }
}
