import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/cart_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/providers/order_provider.dart';
import '../../../../core/providers/vendor_provider.dart';
import '../../../../core/providers/weather_provider.dart';
import '../../../../core/services/delivery_fee_calculator.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../../../cart/widgets/order_confirmation_dialog.dart';
import '../../../orders/receipt_screen.dart';
import '../../../payment/widgets/simulated_card_dialog.dart';
import '../web_kit.dart';
import 'web_customer_common.dart';

/// Checkout on the website: where it lands, how it is paid, a note for the
/// canteen — and beside them the live summary with the fee worked out from
/// the canteen's building, the drop-off and the weight. The rules are the
/// app's: the drone lifts 0.5 kg at most, nothing is placed while flights are
/// grounded, and the order goes to one canteen.
class WebCheckoutPage extends ConsumerStatefulWidget {
  const WebCheckoutPage({super.key});

  @override
  ConsumerState<WebCheckoutPage> createState() => _WebCheckoutPageState();
}

class _Pay {
  const _Pay(this.id, this.label, this.detail, this.icon, this.db);
  final String id;
  final String label;
  final String detail;
  final IconData icon;
  final String db;
}

const _payments = [
  _Pay(
    'xendit',
    'Pay online',
    'GCash or card, on the payment page',
    Icons.language_rounded,
    'xendit_online',
  ),
  _Pay(
    'gcash',
    'GCash',
    'Simulated, for testing',
    Icons.phone_android_rounded,
    'gcash_simulated',
  ),
  _Pay(
    'card',
    'Card',
    'Simulated, for testing',
    Icons.credit_card_rounded,
    'card_simulated',
  ),
];

class _WebCheckoutPageState extends ConsumerState<WebCheckoutPage> {
  String? _dropoff;
  String _payment = 'gcash';
  bool _placing = false;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  DeliveryFeeBreakdown _fee(List<CartItem> cart, {bool watch = true}) {
    if (cart.isEmpty) return DeliveryFeeCalculator.calculateOrderFee();
    T read<T>(ProviderListenable<T> p) => watch ? ref.watch(p) : ref.read(p);

    final all = read(campusLocationsProvider).value ?? [];
    final drops = read(dropoffLocationsProvider).value ?? all;
    final vendor = read(
      vendorProvider,
    ).vendors.where((v) => v.id == cart.first.vendorId).firstOrNull;

    CampusLocation? from;
    if (vendor != null) {
      final id = vendor.campusLocationId;
      if (id != null && id.isNotEmpty) {
        from = all.where((l) => l.id == id).firstOrNull;
      }
      if (from == null && vendor.building.isNotEmpty) {
        final b = vendor.building.toLowerCase();
        from = all.where((l) {
          final n = l.name.toLowerCase();
          return n.contains(b) ||
              b.contains(n) ||
              l.locationCode.toLowerCase() == b;
        }).firstOrNull;
      }
    }
    final to = drops.where((l) => l.id == _dropoff).firstOrNull;

    return DeliveryFeeCalculator.calculateOrderFee(
      distanceKm: DeliveryFeeCalculator.calculateDistanceKm(
        startLat: from?.latitude,
        startLng: from?.longitude,
        endLat: to?.latitude,
        endLng: to?.longitude,
      ),
      weightKg: cartWeightGrams(cart) / 1000.0,
      isCaution: read(weatherProvider).isCaution,
    );
  }

  String? _dropoffName() {
    final locations =
        ref.read(dropoffLocationsProvider).value ??
        ref.read(campusLocationsProvider).value;
    return locations?.where((l) => l.id == _dropoff).firstOrNull?.name;
  }

  Future<void> _place() async {
    final cart = cartNotifier.value;
    if (cart.isEmpty) return;
    HapticFeedback.mediumImpact();

    final weather = ref.read(weatherProvider);
    if (weather.isGrounded) {
      showNeuSnack(
        context,
        weather.message?.isNotEmpty == true
            ? weather.message!
            : 'Weather is unsafe for drone delivery right now. Try again later.',
        tone: NeuToneKind.error,
      );
      return;
    }
    if (cartWeightGrams(cart) > 500) {
      showNeuSnack(
        context,
        "This order is over the drone's 0.5 kg limit.",
        tone: NeuToneKind.error,
      );
      return;
    }
    if (_dropoff == null) {
      showNeuSnack(
        context,
        'Choose where the drone should land.',
        tone: NeuToneKind.error,
      );
      return;
    }

    setState(() => _placing = true);
    final fee = _fee(cart, watch: false);
    final subtotal = cartNotifier.totalAmount;
    final total = subtotal + fee.totalFee;
    final pay = _payments.firstWhere((p) => p.id == _payment);
    final dropoffName = _dropoffName() ?? 'Selected campus pad';

    final confirmed = await OrderConfirmationDialog.show(
      context,
      totalAmount: total,
      paymentMethodLabel: pay.label,
      dropoffName: dropoffName,
    );
    if (confirmed != true) {
      if (mounted) setState(() => _placing = false);
      return;
    }
    if (_payment == 'card') {
      if (!mounted) return;
      final card = await SimulatedCardDialog.show(context, amount: total);
      if (card == null) {
        if (mounted) setState(() => _placing = false);
        return;
      }
    }

    final note = _notes.text.trim();
    final orderId = await ref
        .read(orderProvider.notifier)
        .placeOrder(
          vendorId: cart.first.vendorId,
          dropoffLocationId: _dropoff!,
          subtotal: subtotal,
          deliveryFee: fee.totalFee,
          totalAmount: total,
          paymentMethod: pay.db,
          items: cart,
          notes: note.isEmpty ? null : note,
        );
    if (!mounted) return;
    if (orderId == null) {
      setState(() => _placing = false);
      showNeuSnack(
        context,
        ref.read(orderProvider).errorMessage ??
            'The order could not be placed.',
        tone: NeuToneKind.error,
      );
      return;
    }

    if (_payment == 'xendit') {
      try {
        final res = await SupabaseService.client.functions.invoke(
          'create-xendit-payment',
          body: {'order_id': orderId},
        );
        final data = res.data is Map ? res.data as Map : {};
        final url = data['invoice_url']?.toString();
        cartNotifier.clear();
        if (!mounted) return;
        setState(() => _placing = false);
        if (res.status == 200 && url != null && url.isNotEmpty) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          if (!mounted) return;
          context.go(
            '/user/payment-waiting?orderId=$orderId&invoiceUrl=${Uri.encodeComponent(url)}',
          );
        } else {
          showNeuSnack(
            context,
            data['error']?.toString() ??
                'Could not start payment. You can resume from your orders.',
            tone: NeuToneKind.error,
          );
          context.go('/user/payment-waiting?orderId=$orderId');
        }
      } catch (_) {
        cartNotifier.clear();
        if (!mounted) return;
        setState(() => _placing = false);
        showNeuSnack(
          context,
          'Payment could not start. You can resume from your orders.',
          tone: NeuToneKind.error,
        );
        context.go('/user/payment-waiting?orderId=$orderId');
      }
      return;
    }

    setState(() => _placing = false);
    final receipt = _receipt(cart, total, fee);
    cartNotifier.clear();
    context.go('/user/receipt', extra: receipt);
  }

  ReceiptData _receipt(
    List<CartItem> cart,
    double total,
    DeliveryFeeBreakdown fee,
  ) {
    final placed = ref.read(orderProvider).orders;
    final user = ref.read(authProvider).user;
    final vendor = ref
        .read(vendorProvider)
        .vendors
        .where((v) => v.id == cart.first.vendorId)
        .firstOrNull;
    final now = DateTime.now();
    final first = placed.isNotEmpty ? placed.first : null;
    final note = _notes.text.trim();
    return ReceiptData(
      orderRef: first != null
          ? 'ORD-${first.id.replaceAll('-', '').substring(0, 8).toUpperCase()}'
          : 'ORD-${now.millisecondsSinceEpoch.toString().substring(6)}',
      vendorName: cart.first.vendorName,
      vendorInfo: vendor?.building,
      customerName: user?.fullName,
      customerPhone: user?.phoneNumber,
      lines: [
        for (final i in cart)
          ReceiptLine(
            name: i.productName,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
          ),
      ],
      subtotal: cartNotifier.totalAmount,
      deliveryFee: fee.totalFee,
      feeBreakdown: fee,
      total: total,
      paymentLabel: _payment == 'gcash'
          ? 'GCash (Simulated)'
          : 'Card (Simulated)',
      placedAt: now,
      dropoffName: _dropoffName(),
      totalWeightGrams: cartWeightGrams(cart),
      customerNote: note.isEmpty ? null : note,
      orderStatus: 'Pending Confirmation',
      deliveryId: first?.deliveryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: cartNotifier,
      builder: (context, cart, _) {
        void back() =>
            context.canPop() ? context.pop() : context.go('/user/cart');
        if (cart.isEmpty) {
          return WebPage(
            title: 'Checkout',
            back: true,
            onBack: back,
            children: [
              WebEmpty(
                icon: Icons.shopping_bag_outlined,
                title: 'Nothing to check out',
                message: 'Your cart is empty.',
                action: WebButton(
                  label: 'Browse the shop',
                  onPressed: () => context.go('/user/shop'),
                ),
              ),
            ],
          );
        }

        final locations = ref.watch(dropoffLocationsProvider);
        final weather = ref.watch(weatherProvider);
        final fee = _fee(cart);
        final subtotal = cart.fold<double>(0, (s, i) => s + i.subtotal);
        final total = subtotal + fee.totalFee;
        final grams = cartWeightGrams(cart);
        final overweight = grams > 500;
        final grounded = weather.isGrounded;
        final canteens = cartCanteens(cart);
        final mixed = canteens.length > 1;

        final where = WebPanel(
          title: '1. Where it lands',
          subtitle: 'The campus pad the drone flies your order to.',
          child: locations.when(
            loading: () => const WebSkeleton(height: 120),
            error: (e, _) => Text(
              'Could not load the drop-off pads: $e',
              style: WebText.body(color: AppColors.readable(AppColors.danger)),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Text(
                  'No drop-off pads are open right now.',
                  style: WebText.body(
                    color: AppColors.readable(AppColors.danger),
                  ),
                );
              }
              if (_dropoff == null || !list.any((l) => l.id == _dropoff)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _dropoff = list.first.id);
                });
              }
              return WebGrid(
                minTile: 190,
                maxColumns: 3,
                gap: 14,
                children: [
                  for (final l in list)
                    _Choice(
                      selected: l.id == _dropoff,
                      icon: Icons.place_outlined,
                      title: l.name,
                      detail: l.locationCode,
                      onTap: () => setState(() => _dropoff = l.id),
                    ),
                ],
              );
            },
          ),
        );

        final how = WebPanel(
          title: '2. How you pay',
          child: WebGrid(
            minTile: 190,
            maxColumns: 3,
            gap: 14,
            children: [
              for (final p in _payments)
                _Choice(
                  selected: p.id == _payment,
                  icon: p.icon,
                  title: p.label,
                  detail: p.detail,
                  onTap: () => setState(() => _payment = p.id),
                ),
            ],
          ),
        );

        final note = WebPanel(
          title: '3. A note for the canteen',
          subtitle: 'Optional.',
          child: TextField(
            controller: _notes,
            maxLines: 3,
            maxLength: 200,
            cursorColor: AppColors.accentText,
            style: WebText.body(size: 15, color: AppColors.textPrimary),
            decoration: webInputDecoration(
              hint: 'Extra utensils, no onions, call when it lands…',
            ),
          ),
        );

        final summary = WebPanel(
          title: 'Order summary',
          subtitle: canteens.join(', '),
          depth: NeuDepth.medium,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final i in cart)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      WebThumb(url: i.imageUrl, name: i.productName, size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${i.quantity} × ${i.productName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: WebText.label(size: 13.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        WebText.peso(i.subtotal),
                        style: WebText.label(size: 13.5),
                      ),
                    ],
                  ),
                ),
              const WebGroove(),
              WebKeyValue('Subtotal', WebText.peso(subtotal)),
              WebKeyValue('Drone delivery', WebText.peso(fee.totalFee)),
              if (fee.breakdownText.isNotEmpty)
                Text(
                  fee.breakdownText,
                  style: WebText.body(size: 12, color: AppColors.textTertiary),
                ),
              const SizedBox(height: 10),
              _Payload(grams: grams),
              const WebGroove(),
              WebKeyValue('Total', WebText.peso(total), emphasis: true),
              if (grounded || overweight || mixed) ...[
                const SizedBox(height: 12),
                WebWell(
                  padding: const EdgeInsets.all(14),
                  radius: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        grounded
                            ? Icons.thunderstorm_outlined
                            : Icons.warning_amber_rounded,
                        size: 19,
                        color: AppColors.readable(AppColors.danger),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          grounded
                              ? (weather.message?.isNotEmpty == true
                                    ? weather.message!
                                    : 'Flights are grounded by the weather. '
                                          'Orders open again when it clears.')
                              : overweight
                              ? 'This order weighs '
                                    '${(grams / 1000).toStringAsFixed(2)} kg — '
                                    'over the drone\'s 0.5 kg limit. Remove '
                                    'something to continue.'
                              : 'One order goes to one canteen. Your cart has '
                                    'food from ${canteens.length}.',
                          style: WebText.body(
                            size: 13.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              WebButton(
                label: grounded
                    ? 'Flights grounded'
                    : (overweight
                          ? 'Over the weight limit'
                          : 'Place order · ${WebText.peso(total)}'),
                icon: Icons.flight_takeoff_rounded,
                expand: true,
                loading: _placing,
                onPressed: grounded || overweight || mixed ? null : _place,
              ),
            ],
          ),
        );

        return WebPage(
          title: 'Checkout',
          subtitle: 'Check the details, then send it on its way.',
          back: true,
          onBack: back,
          children: [
            WebSplit(
              sideWidth: 400,
              main: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  where,
                  const SizedBox(height: 22),
                  how,
                  const SizedBox(height: 22),
                  note,
                ],
              ),
              side: summary,
            ),
          ],
        );
      },
    );
  }
}

/// A selectable card: raised at rest, pressed in with an accent ring and a
/// tick when chosen.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $detail',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: const Cubic(0.2, 0, 0, 1),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? AppColors.surfaceSunken : AppColors.base,
              borderRadius: BorderRadius.circular(18),
              boxShadow: selected ? const [] : AppShadows.raised(),
              border: Border.all(
                color: selected ? AppColors.accentText : Colors.transparent,
                width: 1.6,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected
                      ? AppColors.accentText
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: WebText.label(size: 14),
                      ),
                      if (detail.isNotEmpty)
                        Text(
                          detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: WebText.body(size: 12),
                        ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: AppColors.accentText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How much of the drone's 500 g the order uses, as a filling groove.
class _Payload extends StatelessWidget {
  const _Payload({required this.grams});
  final int grams;

  @override
  Widget build(BuildContext context) {
    final share = (grams / 500).clamp(0.0, 1.0);
    final over = grams > 500;
    final tone = over
        ? AppColors.danger
        : (share > 0.8 ? AppColors.warning : AppColors.accentFill);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Cargo weight', style: WebText.body(size: 14)),
            ),
            Text(
              '$grams g of 500 g',
              style: WebText.label(
                size: 13.5,
                color: over ? AppColors.readable(AppColors.danger) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        NeuSurface(
          style: NeuStyle.inset,
          depth: NeuDepth.flat,
          color: AppColors.surfaceSunken,
          height: 8,
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: share),
            duration: const Duration(milliseconds: 400),
            curve: const Cubic(0.2, 0, 0, 1),
            builder: (context, v, _) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
