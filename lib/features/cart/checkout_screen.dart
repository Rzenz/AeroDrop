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
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/verify_email_banner.dart';
import '../../core/providers/order_provider.dart';
import '../../core/models/cart_model.dart';
import '../../core/models/order_quote_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/location_provider.dart';
import '../../core/providers/order_quote_provider.dart';
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
    // Priced by the server (quote_order_fee), the same function place_order
    // charges with. Never computed here: a failed quote shows as unavailable
    // and blocks the order rather than falling back to a local figure.
    final quoteRequest = orderQuoteRequestFor(cart, _selectedLocationId);
    final quoteAsync = quoteRequest == null
        ? const AsyncValue<OrderQuote>.loading()
        : ref.watch(orderQuoteProvider(quoteRequest));
    final quote = quoteAsync.asData?.value;
    final quoteFailed = quote == null && quoteAsync.hasError;
    final feeBreakdown = quote?.toFeeBreakdown();
    final pendingFigure = quoteFailed ? 'Unavailable' : 'Calculating…';
    final totalWeightGrams = cart.fold<int>(
      0,
      (sum, item) => sum + ((item.weightKg * 1000).round() * item.quantity),
    );
    // Over one drone load is fine (flown in trips); over maxTrips loads is not
    final trips = cartNotifier.tripsRequired;
    final isOverweight = cartNotifier.exceedsMaxTrips;
    final totalWeightKg = (totalWeightGrams / 1000.0).toStringAsFixed(2);
    final locationsAsync = ref.watch(dropoffLocationsProvider);
    final weather = ref.watch(weatherProvider);
    final isGrounded = weather.isGrounded;
    // Migration 35: the database refuses orders from unverified accounts;
    // stop here instead of letting the person get that far.
    final needsVerification =
        ref.watch(authProvider).user?.needsEmailVerification == true;

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
                        // Default to the drop-off saved on the profile when
                        // it is still selectable. Only a default: picking a
                        // different one here changes this order alone.
                        final savedId =
                            ref.watch(authProvider).user?.campusLocationId;
                        final defaultId =
                            locations.any((l) => l.id == savedId)
                            ? savedId!
                            : locations.first.id;

                        // Initialize selection if null
                        if (_selectedLocationId == null ||
                            !locations.any(
                              (l) => l.id == _selectedLocationId,
                            )) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() {
                              _selectedLocationId = defaultId;
                            });
                          });
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedLocationId ?? defaultId,
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
                          value: quote != null
                              ? '₱${quote.subtotal.toStringAsFixed(2)}'
                              : pendingFigure,
                        ),
                        const SizedBox(height: 6),
                        _SummaryRow(
                          label: 'Drone Delivery Fee',
                          value: quote != null
                              ? '₱${quote.deliveryFee.toStringAsFixed(2)}'
                              : pendingFigure,
                          valueColor: quoteFailed
                              ? AppColors.danger
                              : Colors.white,
                        ),
                        if (quoteFailed)
                          _QuoteError(
                            message: _quoteErrorText(quoteAsync.error),
                            onRetry: quoteRequest == null
                                ? null
                                : () => ref.invalidate(
                                    orderQuoteProvider(quoteRequest),
                                  ),
                          ),
                        if (feeBreakdown != null &&
                            feeBreakdown.breakdownText.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              feeBreakdown.breakdownText,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption(
                                fontSize: 10,
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                          ),
                        ],
                        if (trips > 1 && !isOverweight) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'This order needs $trips drone trips; the route fee is charged per trip.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption(
                                fontSize: 11,
                                color: AppColors.warning,
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
                          value:
                              '500 g per trip, up to ${DeliveryFeeCalculator.maxTrips} trips',
                        ),
                        const SizedBox(height: 10),
                        Divider(color: AppColors.border),
                        const SizedBox(height: 10),
                        _SummaryRow(
                          label: 'Total',
                          value: quote != null
                              ? '₱${quote.totalAmount.toStringAsFixed(2)}'
                              : pendingFigure,
                          valueColor: quoteFailed
                              ? AppColors.danger
                              : AppColors.accent,
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

                  if (needsVerification) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.mark_email_unread_outlined,
                            color: AppColors.warning,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Verify your email to place this order.',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          NeuButton(
                            text: 'Verify email',
                            expand: false,
                            height: 36,
                            onPressed: () => showVerifyEmailSheet(context),
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
                              'This order weighs $totalWeightKg kg and would need $trips drone trips. The maximum is ${DeliveryFeeCalculator.maxTrips} trips (1.0 kg). Please split it into separate orders.',
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
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
                    onPressed:
                        (_placing ||
                            isOverweight ||
                            isGrounded ||
                            needsVerification ||
                            quote == null)
                        ? null
                        : _placeOrder,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.bgDark,
                      disabledBackgroundColor:
                          (isOverweight ||
                              isGrounded ||
                              needsVerification ||
                              quoteFailed)
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
                                ? 'Order Too Heavy'
                                : isGrounded
                                ? 'Flight Grounded'
                                : needsVerification
                                ? 'Verify Email First'
                                : quoteFailed
                                ? 'Fee Unavailable'
                                : quote == null
                                ? 'Calculating Fee…'
                                : 'Confirm Order',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.subHead(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color:
                                  (isOverweight ||
                              isGrounded ||
                              needsVerification ||
                              quoteFailed)
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

    if (cartNotifier.exceedsMaxTrips) {
      setState(() => _placing = false);
      final weightKg = cartNotifier.totalWeightKg.toStringAsFixed(2);
      showNeuSnack(
        context,
        'This order weighs $weightKg kg; the maximum is ${DeliveryFeeCalculator.maxTrips} drone trips (1.0 kg). Please split it into separate orders.',
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

    // Fetch a fresh quote rather than trusting the one on screen: the weather
    // or the drop-off may have moved since it loaded, and the server charges
    // its current figure. No quote, no order.
    final OrderQuote quote;
    try {
      quote = await ref.refresh(
        orderQuoteProvider(
          orderQuoteRequestFor(cart, _selectedLocationId)!,
        ).future,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      showNeuSnack(
        context,
        '${_quoteErrorText(e)} Your order was not placed.',
        tone: NeuToneKind.error,
      );
      return;
    }
    if (!mounted) return;

    final feeBreakdown = quote.toFeeBreakdown();
    final deliveryFee = quote.deliveryFee;
    final totalAmount = quote.totalAmount;
    final dropoffName = _dropoffName() ?? 'Selected Campus Pad';
    final paymentLabel = switch (_paymentMethod) {
      'xendit' => 'Pay online (GCash or Card)',
      'gcash' => 'Simulated GCash',
      'card' => 'Simulated Card',
      _ => 'Online Payment',
    };

    // 0. A multi-trip order is delivered in parts; make sure that is wanted
    if (cartNotifier.needsMultipleTrips) {
      final trips = cartNotifier.tripsRequired;
      final weightKg = cartNotifier.totalWeightKg.toStringAsFixed(2);
      final proceed = await showNeuConfirm(
        context,
        title: 'Deliver in $trips trips?',
        message:
            'Your order weighs $weightKg kg, more than one drone load '
            '(${DeliveryFeeCalculator.maxPayloadKg.toStringAsFixed(1)} kg). '
            'The drone will deliver it in $trips separate trips, and the '
            'order is complete only after the last one arrives.\n\n'
            'Delivery fee: ₱${deliveryFee.toStringAsFixed(2)}',
        confirmLabel: 'Continue',
        cancelLabel: 'Edit cart',
        icon: Icons.repeat_rounded,
      );
      if (!mounted) return;
      if (!proceed) {
        setState(() => _placing = false);
        context.pop();
        return;
      }
    }

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
      final cardResult = await SimulatedCardDialog.show(
        context,
        amount: totalAmount,
      );
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
          // Ignored by the server since migration 31, which prices the order
          // itself; passed so the place_order signature stays unchanged.
          subtotal: quote.subtotal,
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

        if (fnRes.status == 200 &&
            invoiceUrl != null &&
            invoiceUrl.isNotEmpty) {
          cartNotifier.clear();
          setState(() => _placing = false);

          final uri = Uri.parse(invoiceUrl);
          await launchUrl(uri, mode: LaunchMode.externalApplication);

          if (!mounted) return;
          context.go(
            '/user/payment-waiting?orderId=$orderId&invoiceUrl=${Uri.encodeComponent(invoiceUrl)}',
          );
          return;
        } else {
          final err =
              data['error']?.toString() ??
              'Could not start payment. Please try again.';
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
        showNeuSnack(
          context,
          'Payment initialization failed. You can resume from your orders.',
          tone: NeuToneKind.error,
        );
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
      subtotal: quote.subtotal,
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
    final locations =
        ref.read(dropoffLocationsProvider).value ??
        ref.read(campusLocationsProvider).value;
    if (locations == null) return null;
    for (final l in locations) {
      if (l.id == _selectedLocationId) return l.name;
    }
    return null;
  }

  /// A quote failure as a sentence for the checkout.
  static String _quoteErrorText(Object? error) {
    final detail = error is StateError ? error.message : null;
    return detail != null && detail.isNotEmpty
        ? 'The delivery fee could not be calculated: $detail'
        : 'The delivery fee could not be calculated. Check your connection '
              'and try again.';
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
    required double subtotal,
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
      subtotal: subtotal,
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

/// Why the fee is missing, with a way to ask again.
class _QuoteError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _QuoteError({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: AppColors.danger,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption(
                fontSize: 11,
                color: AppColors.danger,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                'Retry',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentText,
                ),
              ),
            ),
        ],
      ),
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
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: bold ? 14 : 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
