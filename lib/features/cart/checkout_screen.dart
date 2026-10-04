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
import '../../core/models/cart_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/location_provider.dart';
import '../../core/providers/vendor_provider.dart';
import '../../core/providers/weather_provider.dart';
import '../../core/services/delivery_fee_calculator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/supabase_service.dart';
import '../payment/widgets/simulated_card_dialog.dart';
import 'widgets/order_confirmation_dialog.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? _selectedLocationId;
  String _paymentMethod = 'gcash';
  bool _placing = false;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = cartNotifier.value;
    final feeBreakdown = _getFeeBreakdown(cart, isWatch: true);
    final deliveryFee = feeBreakdown.totalFee;
    final total = cartNotifier.totalAmount + deliveryFee;
    final totalWeightGrams = cart.fold<int>(
      0,
      (sum, item) => sum + ((item.weightKg * 1000).round() * item.quantity),
    );
    final isOverweight = totalWeightGrams > 500;
    final totalWeightKg = (totalWeightGrams / 1000.0).toStringAsFixed(2);
    final locationsAsync = ref.watch(dropoffLocationsProvider);
    final weather = ref.watch(weatherProvider);
    final isGrounded = weather.isGrounded;

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
                          value: 'xendit',
                          groupValue: _paymentMethod,
                          icon: Icons.language_rounded,
                          label: 'Pay online (GCash or Card)',
                          color: AppColors.accent,
                          onChanged: (v) => setState(() => _paymentMethod = v!),
                        ),
                        _PaymentOption(
                          value: 'gcash',
                          groupValue: _paymentMethod,
                          icon: Icons.phone_android_rounded,
                          label: 'Simulated GCash',
                          color: const Color(0xFF007DC5),
                          onChanged: (v) => setState(() => _paymentMethod = v!),
                        ),
                        _PaymentOption(
                          value: 'card',
                          groupValue: _paymentMethod,
                          icon: Icons.credit_card_rounded,
                          label: 'Simulated Card',
                          color: const Color(0xFFA855F7),
                          onChanged: (v) => setState(() => _paymentMethod = v!),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 16),

                  // Order Note / Instructions for Vendor
                  _SectionCard(
                    title: 'Note for Vendor (Optional)',
                    icon: Icons.note_alt_outlined,
                    child: TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      maxLength: 200,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.bgDark,
                        hintText:
                            'e.g. Please pack extra utensils, call upon arrival...',
                        hintStyle: AppTextStyles.caption(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        counterStyle: AppTextStyles.caption(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.accent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 175.ms),
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
                          value: '₱${deliveryFee.toStringAsFixed(2)}',
                        ),
                        if (feeBreakdown.breakdownText.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              feeBreakdown.breakdownText,
                              style: AppTextStyles.caption(
                                fontSize: 10,
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        _SummaryRow(
                          label: 'Total Cargo Weight',
                          value: '$totalWeightGrams g ($totalWeightKg kg)',
                          valueColor: isOverweight
                              ? AppColors.danger
                              : Colors.white,
                          bold: isOverweight,
                        ),

                        const SizedBox(height: 6),
                        _SummaryRow(
                          label: 'Maximum Drone Payload',
                          value: '500 g (0.50 kg)',
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

                  // Grounded weather warning banner
                  if (isGrounded) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.thunderstorm_rounded,
                            color: AppColors.danger,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              weather.message != null &&
                                      weather.message!.isNotEmpty
                                  ? weather.message!
                                  : 'Weather is currently unsafe for drone delivery. Please try again later.',
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Overweight warning banner
                  if (isOverweight) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.danger,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "This order exceeds the drone's maximum payload of 0.5 kg. Your order weighs $totalWeightKg kg.",
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Confirm button
                  FilledButton(
                    onPressed: (_placing || isOverweight || isGrounded)
                        ? null
                        : _placeOrder,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.bgDark,
                      disabledBackgroundColor: (isOverweight || isGrounded)
                          ? AppColors.cardDark
                          : null,
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
                            isOverweight
                                ? 'Payload Exceeded'
                                : (isGrounded
                                    ? 'Flight Grounded'
                                    : 'Confirm Order'),
                            style: AppTextStyles.subHead(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: (isOverweight || isGrounded)
                                  ? Colors.grey
                                  : null,
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

    final weather = ref.read(weatherProvider);
    if (weather.isGrounded) {
      setState(() => _placing = false);
      showNeuSnack(
        context,
        weather.message != null && weather.message!.isNotEmpty
            ? weather.message!
            : 'Weather is currently unsafe for drone delivery. Please try again later.',
        tone: NeuToneKind.error,
      );
      return;
    }

    final totalWeightGrams = cart.fold<int>(
      0,
      (sum, item) => sum + ((item.weightKg * 1000).round() * item.quantity),
    );
    if (totalWeightGrams > 500) {
      setState(() => _placing = false);
      final weightKg = (totalWeightGrams / 1000.0).toStringAsFixed(2);
      showNeuSnack(
        context,
        "This order exceeds the drone's maximum payload of 0.5 kg. Your order weighs $weightKg kg.",
        tone: NeuToneKind.error,
      );
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

    final feeBreakdown = _getFeeBreakdown(cart, isWatch: false);
    final deliveryFee = feeBreakdown.totalFee;
    final totalAmount = cartNotifier.totalAmount + deliveryFee;
    final dropoffName = _dropoffName() ?? 'Selected Campus Pad';
    final paymentLabel = switch (_paymentMethod) {
      'xendit' => 'Pay online (GCash or Card)',
      'gcash' => 'Simulated GCash',
      'card' => 'Simulated Card',
      _ => 'Online Payment',
    };

    // 1. Show Pre-payment Confirmation Dialog (explaining cancellation rules)
    final confirmed = await OrderConfirmationDialog.show(
      context,
      totalAmount: totalAmount,
      paymentMethodLabel: paymentLabel,
      dropoffName: dropoffName,
    );

    if (confirmed != true) {
      if (mounted) setState(() => _placing = false);
      return;
    }

    // 2. If simulated Card is selected, open Simulated Card Entry Dialog
    if (_paymentMethod == 'card') {
      if (!mounted) return;
      final cardResult = await SimulatedCardDialog.show(context, amount: totalAmount);
      if (cardResult == null) {
        if (mounted) setState(() => _placing = false);
        return;
      }
    }

    final dbPaymentMethod = switch (_paymentMethod) {
      'xendit' => 'xendit_online',
      'gcash' => 'gcash_simulated',
      'card' => 'card_simulated',
      _ => 'xendit_online',
    };

    final rawNotes = _notesController.text.trim();
    final notes = rawNotes.isNotEmpty ? rawNotes : null;

    final orderId = await ref
        .read(orderProvider.notifier)
        .placeOrder(
          vendorId: cart.first.vendorId,
          dropoffLocationId: _selectedLocationId!,
          subtotal: cartNotifier.totalAmount,
          deliveryFee: deliveryFee,
          totalAmount: totalAmount,
          paymentMethod: dbPaymentMethod,
          items: cart,
          notes: notes,
        );

    if (!mounted) return;

    if (orderId == null) {
      setState(() => _placing = false);
      final errorMsg =
          ref.read(orderProvider).errorMessage ?? 'Order placement failed.';
      showNeuSnack(context, errorMsg, tone: NeuToneKind.error);
      return;
    }

    // 3. Handle Xendit Online checkout
    if (_paymentMethod == 'xendit') {
      try {
        final fnRes = await SupabaseService.client.functions.invoke(
          'create-xendit-payment',
          body: {'order_id': orderId},
        );

        final data = fnRes.data is Map ? fnRes.data as Map : {};
        final invoiceUrl = data['invoice_url']?.toString();

        if (fnRes.status == 200 && invoiceUrl != null && invoiceUrl.isNotEmpty) {
          cartNotifier.clear();
          setState(() => _placing = false);

          final uri = Uri.parse(invoiceUrl);
          await launchUrl(uri, mode: LaunchMode.externalApplication);

          if (!mounted) return;
          context.go('/user/payment-waiting?orderId=$orderId&invoiceUrl=${Uri.encodeComponent(invoiceUrl)}');
          return;
        } else {
          final err = data['error']?.toString() ?? 'Could not start payment. Please try again.';
          cartNotifier.clear();
          if (!mounted) return;
          setState(() => _placing = false);
          showNeuSnack(context, err, tone: NeuToneKind.error);
          context.go('/user/payment-waiting?orderId=$orderId');
          return;
        }
      } catch (e) {
        cartNotifier.clear();
        if (!mounted) return;
        setState(() => _placing = false);
        showNeuSnack(context, 'Payment initialization failed. You can resume from your orders.', tone: NeuToneKind.error);
        context.go('/user/payment-waiting?orderId=$orderId');
        return;
      }
    }

    // 4. Handle Simulated Payments (GCash & Card)
    setState(() => _placing = false);
    final receipt = _receiptFor(
      cart,
      totalAmount,
      deliveryFee,
      feeBreakdown: feeBreakdown,
    );
    cartNotifier.clear();
    context.go('/user/receipt', extra: receipt);
  }

  /// Name of the selected drop-off, read from the same provider that feeds
  /// the picker so the printed location always matches what was chosen.
  ///
  /// Written as a loop rather than `firstOrNull`: that extension arrives here
  /// through a transitive export, not a declared dependency, and would break
  /// the build the day that package stops re-exporting it.
  String? _dropoffName() {
    final locations = ref.read(dropoffLocationsProvider).value ??
        ref.read(campusLocationsProvider).value;
    if (locations == null) return null;
    for (final l in locations) {
      if (l.id == _selectedLocationId) return l.name;
    }
    return null;
  }

  /// Computes distance and weight based delivery fee with caution weather surcharge
  DeliveryFeeBreakdown _getFeeBreakdown(List<CartItem> cart, {bool isWatch = false}) {
    if (cart.isEmpty) {
      return DeliveryFeeCalculator.calculateOrderFee();
    }
    final allCampusLocations = (isWatch
            ? ref.watch(campusLocationsProvider).value
            : ref.read(campusLocationsProvider).value) ??
        [];
    final dropoffLocations = (isWatch
            ? ref.watch(dropoffLocationsProvider).value
            : ref.read(dropoffLocationsProvider).value) ??
        allCampusLocations;
    final vendors = (isWatch
        ? ref.watch(vendorProvider).vendors
        : ref.read(vendorProvider).vendors);
    final vendor =
        vendors.where((v) => v.id == cart.first.vendorId).firstOrNull;

    CampusLocation? vendorLoc;
    if (vendor != null) {
      if (vendor.campusLocationId != null &&
          vendor.campusLocationId!.isNotEmpty) {
        vendorLoc = allCampusLocations
            .where((l) => l.id == vendor.campusLocationId)
            .firstOrNull;
      }
      if (vendorLoc == null && vendor.building.isNotEmpty) {
        final bLower = vendor.building.toLowerCase();
        vendorLoc = allCampusLocations.where((l) {
          final lName = l.name.toLowerCase();
          final lCode = l.locationCode.toLowerCase();
          return lName.contains(bLower) ||
              bLower.contains(lName) ||
              lCode == bLower;
        }).firstOrNull;
      }
    }

    final dropoffLoc = dropoffLocations
        .where((l) => l.id == _selectedLocationId)
        .firstOrNull;

    final distanceKm = DeliveryFeeCalculator.calculateDistanceKm(
      startLat: vendorLoc?.latitude,
      startLng: vendorLoc?.longitude,
      endLat: dropoffLoc?.latitude,
      endLng: dropoffLoc?.longitude,
    );

    final totalWeightGrams = cart.fold<int>(
      0,
      (sum, item) => sum + ((item.weightKg * 1000).round() * item.quantity),
    );
    final weightKg = totalWeightGrams / 1000.0;
    final weather =
        isWatch ? ref.watch(weatherProvider) : ref.read(weatherProvider);

    return DeliveryFeeCalculator.calculateOrderFee(
      distanceKm: distanceKm,
      weightKg: weightKg,
      isCaution: weather.isCaution,
    );
  }

  /// Builds the printed record from the order just placed.
  ///
  /// The reference comes from the order the provider reloaded, which is sorted
  /// newest first — so the first entry is this one. When Supabase is not
  /// configured there is no row to read, and the receipt falls back to the
  /// payment reference format the server would have used.
  ReceiptData _receiptFor(
    List<CartItem> cart,
    double totalAmount,
    double deliveryFee, {
    DeliveryFeeBreakdown? feeBreakdown,
  }) {
    final placed = ref.read(orderProvider).orders;
    final user = ref.read(authProvider).user;
    final vendors = ref.read(vendorProvider).vendors;
    final vendor = vendors
        .where((v) => v.id == cart.first.vendorId)
        .firstOrNull;
    final now = DateTime.now();
    final firstOrder = placed.isNotEmpty ? placed.first : null;
    final ref0 = firstOrder != null
        ? 'ORD-${firstOrder.id.replaceAll('-', '').substring(0, 8).toUpperCase()}'
        : 'ORD-${now.millisecondsSinceEpoch.toString().substring(6)}';

    final totalWeightGrams = cart.fold<int>(
      0,
      (sum, item) => sum + ((item.weightKg * 1000).round() * item.quantity),
    );

    final rawNotes = _notesController.text.trim();
    final note = rawNotes.isNotEmpty ? rawNotes : null;

    return ReceiptData(
      orderRef: ref0,
      vendorName: cart.first.vendorName,
      vendorInfo: vendor?.building,
      customerName: user?.fullName,
      customerPhone: user?.phoneNumber,
      lines: [
        for (final item in cart)
          ReceiptLine(
            name: item.productName,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
          ),
      ],
      subtotal: cartNotifier.totalAmount,
      deliveryFee: deliveryFee,
      feeBreakdown: feeBreakdown,
      total: totalAmount,
      paymentLabel: _paymentMethod == 'gcash'
          ? 'GCash (Simulated)'
          : 'Cash on delivery',
      placedAt: now,
      dropoffName: _dropoffName(),
      totalWeightGrams: totalWeightGrams,
      customerNote: note,
      orderStatus: 'Pending Confirmation',
      deliveryId: firstOrder?.deliveryId,
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
