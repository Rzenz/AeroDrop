import 'package:flutter/material.dart';
import '../../core/widgets/neu_feedback.dart';
import '../orders/receipt_screen.dart';
import '../../core/widgets/custom_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/providers/order_provider.dart';
import '../../mock_data/cart_mock.dart';
import '../../core/providers/location_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? _selectedLocationId;
  String _paymentMethod = 'gcash';
  bool _placing = false;

  @override
  Widget build(BuildContext context) {
    final cart = cartNotifier.value;
    final total = cartNotifier.totalAmount + 20.0;
    final locationsAsync = ref.watch(campusLocationsProvider);

    return Scaffold(
      backgroundColor: AppColors.base,
      appBar: CustomAppBar(title: 'Checkout'),
      body: cart.isEmpty
          ? Center(
              child: Text(
                'No items to check out.',
                style: AppTextStyles.body(color: AppColors.textPrimary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Confirm Order Details',
                    style: AppTextStyles.heading(fontSize: 22),
                  ).animate().fadeIn().slideX(begin: -0.1),
                  const SizedBox(height: 20),

                  // Delivery Location
                  _SectionCard(
                    title: 'Campus Drop-off Location',
                    icon: Icons.location_on_outlined,
                    child: locationsAsync.when(
                      data: (locations) {
                        if (locations.isEmpty) {
                          return Text(
                            'No campus locations available.',
                            style: AppTextStyles.body(
                              fontSize: 13,
                              color: AppColors.danger,
                            ),
                          );
                        }
                        // Initialize selection if null
                        if (_selectedLocationId == null ||
                            !locations.any(
                              (l) => l.id == _selectedLocationId,
                            )) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() {
                              _selectedLocationId = locations.first.id;
                            });
                          });
                        }

                        return DropdownButtonFormField<String>(
                          initialValue:
                              _selectedLocationId ?? locations.first.id,
                          dropdownColor: AppColors.surfaceRaised,
                          style: AppTextStyles.body(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.bgDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          items: locations
                              .map(
                                (loc) => DropdownMenuItem(
                                  value: loc.id,
                                  child: Text(
                                    loc.name,
                                    style: AppTextStyles.body(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedLocationId = v),
                        );
                      },
                      loading: () => const SizedBox(
                        height: 48,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      error: (err, _) => Text(
                        'Failed to load locations: $err',
                        style: AppTextStyles.body(
                          fontSize: 13,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 100.ms),
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
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 16),

                  // Order summary
                  _SectionCard(
                    title: 'Order Summary',
                    icon: Icons.receipt_long_outlined,
                    child: Column(
                      children: [
                        _SummaryRow(
                          label: 'Subtotal',
                          value:
                              '₱${cartNotifier.totalAmount.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 6),
                        _SummaryRow(
                          label: 'Drone Delivery Fee',
                          value: '₱20.00',
                        ),
                        const SizedBox(height: 10),
                        Divider(color: AppColors.border),
                        const SizedBox(height: 10),
                        _SummaryRow(
                          label: 'Total',
                          value: '₱${total.toStringAsFixed(2)}',
                          valueColor: AppColors.accent,
                          bold: true,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 32),

                  // Confirm button
                  FilledButton(
                    onPressed: _placing ? null : _placeOrder,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.bgDark,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _placing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.bgDark,
                            ),
                          )
                        : Text(
                            'Confirm Order',
                            style: AppTextStyles.subHead(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ).animate().fadeIn(delay: 250.ms),
                ],
              ),
            ),
    );
  }

  Future<void> _placeOrder() async {
    HapticFeedback.mediumImpact();
    setState(() => _placing = true);

    final cart = cartNotifier.value;
    if (cart.isEmpty) {
      setState(() => _placing = false);
      return;
    }

    if (_selectedLocationId == null) {
      setState(() => _placing = false);
      showNeuSnack(
        context,
        'Please select a drop-off location.',
        tone: NeuToneKind.error,
      );
      return;
    }

    final totalAmount = cartNotifier.totalAmount + 20.0;
    final dbPaymentMethod = _paymentMethod == 'gcash'
        ? 'gcash_simulated'
        : 'cash_on_delivery';

    final success = await ref
        .read(orderProvider.notifier)
        .placeOrder(
          vendorId: cart.first.vendorId,
          dropoffLocationId: _selectedLocationId!,
          subtotal: cartNotifier.totalAmount,
          deliveryFee: 20.0,
          totalAmount: totalAmount,
          paymentMethod: dbPaymentMethod,
          items: cart,
        );

    if (!mounted) return;
    setState(() => _placing = false);

    if (success) {
      // Snapshot the receipt before clearing the cart — the lines are read
      // from it, and an empty cart prints an empty receipt.
      final receipt = _receiptFor(cart, totalAmount);
      cartNotifier.clear();
      context.go('/user/receipt', extra: receipt);
    } else {
      final errorMsg =
          ref.read(orderProvider).errorMessage ?? 'Order placement failed.';
      showNeuSnack(context, errorMsg, tone: NeuToneKind.error);
    }
  }

  /// Name of the selected drop-off, read from the same provider that feeds
  /// the picker so the printed location always matches what was chosen.
  ///
  /// Written as a loop rather than `firstOrNull`: that extension arrives here
  /// through a transitive export, not a declared dependency, and would break
  /// the build the day that package stops re-exporting it.
  String? _dropoffName() {
    final locations = ref.read(campusLocationsProvider).value;
    if (locations == null) return null;
    for (final l in locations) {
      if (l.id == _selectedLocationId) return l.name;
    }
    return null;
  }

  /// Builds the printed record from the order just placed.
  ///
  /// The reference comes from the order the provider reloaded, which is sorted
  /// newest first — so the first entry is this one. When Supabase is not
  /// configured there is no row to read, and the receipt falls back to the
  /// payment reference format the server would have used.
  ReceiptData _receiptFor(List<CartItem> cart, double totalAmount) {
    final placed = ref.read(orderProvider).orders;
    final now = DateTime.now();
    final ref0 = placed.isNotEmpty
        ? 'ORD-${placed.first.id.replaceAll('-', '').substring(0, 8).toUpperCase()}'
        : 'ORD-${now.millisecondsSinceEpoch.toString().substring(6)}';

    return ReceiptData(
      orderRef: ref0,
      vendorName: cart.first.vendorName,
      lines: [
        for (final item in cart)
          ReceiptLine(
            name: item.productName,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
          ),
      ],
      subtotal: cartNotifier.totalAmount,
      deliveryFee: 20.0,
      total: totalAmount,
      paymentLabel: _paymentMethod == 'gcash' ? 'GCash' : 'Cash on delivery',
      placedAt: now,
      dropoffName: _dropoffName(),
    );
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
              Icon(icon, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.subHead(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : AppColors.bgDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? color : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? color : AppColors.textSecondary,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: bold ? 14 : 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: bold ? 17 : 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
