import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/order_model.dart';
import '../../../../core/providers/order_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../web_kit.dart';
import '../web_status.dart';

/// Waiting for an online payment: the 15-minute window counting down, the
/// way back to the payment page, and the order beside it. It follows the
/// order live (and polls every four seconds as a fallback), exactly as the
/// app's waiting screen does.
class WebPaymentWaitingPage extends ConsumerStatefulWidget {
  const WebPaymentWaitingPage({
    super.key,
    required this.orderId,
    this.invoiceUrl,
  });

  final String orderId;
  final String? invoiceUrl;

  @override
  ConsumerState<WebPaymentWaitingPage> createState() =>
      _WebPaymentWaitingPageState();
}

class _WebPaymentWaitingPageState extends ConsumerState<WebPaymentWaitingPage> {
  static const _window = 900;

  OrderModel? _order;
  String? _invoice;
  String _pay = 'pending';
  String _status = 'pending';
  bool _loading = true;
  bool _opening = false;
  bool _cancelling = false;
  int _left = _window;
  Timer? _tick;
  Timer? _poll;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoiceUrl;
    _start();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _poll?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  bool get _settled =>
      _pay == 'paid' ||
      _pay == 'expired' ||
      _pay == 'failed' ||
      _status == 'cancelled';

  Future<void> _start() async {
    await _fetch();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left > 0) {
        setState(() => _left--);
      } else {
        t.cancel();
        if (_pay == 'pending') setState(() => _pay = 'expired');
      }
    });
    _poll = Timer.periodic(const Duration(seconds: 4), (t) async {
      if (!mounted || _settled) {
        t.cancel();
        return;
      }
      await _fetch();
    });
    _listen();
  }

  Future<void> _fetch() async {
    if (!SupabaseService.isConfigured || widget.orderId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final r = await SupabaseService.client
          .from('orders')
          .select(
            '*, vendor:users!vendor_id(full_name, business_name), '
            'customer:users!user_id(full_name, phone_number), '
            'campus_locations!delivery_location_id(name), '
            'order_items(product_name, quantity, unit_price, weight_grams), '
            'deliveries(id, status, progress, drone_id, estimated_delivery_seconds, delivery_started_at, delivery_completed_at)',
          )
          .eq('id', widget.orderId)
          .maybeSingle();
      if (r != null && mounted) {
        _apply(OrderModel.fromMap(Map<String, dynamic>.from(r)));
      }
    } catch (e) {
      debugPrint('Payment waiting: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _apply(OrderModel o) {
    setState(() {
      _order = o;
      _pay = o.paymentStatus.toLowerCase();
      _status = o.orderStatus.toLowerCase();
      if (o.paymentInvoiceUrl?.isNotEmpty ?? false) {
        _invoice = o.paymentInvoiceUrl;
      }
      final left = _window - DateTime.now().difference(o.createdAt).inSeconds;
      _left = left > 0 ? left : 0;
    });
    if (_settled) {
      _tick?.cancel();
      _poll?.cancel();
      if (_pay == 'paid') HapticFeedback.heavyImpact();
    }
  }

  void _listen() {
    if (!SupabaseService.isConfigured || widget.orderId.isEmpty) return;
    try {
      _channel = SupabaseService.client
          .channel('web_xendit_waiting_${widget.orderId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: widget.orderId,
            ),
            callback: (p) {
              final row = p.newRecord;
              if (!mounted) return;
              setState(() {
                _pay =
                    row['payment_status']?.toString().toLowerCase() ??
                    'pending';
                _status =
                    row['order_status']?.toString().toLowerCase() ?? 'pending';
                final url = row['payment_invoice_url']?.toString();
                if (url != null && url.isNotEmpty) _invoice = url;
              });
              if (_settled) {
                _tick?.cancel();
                _poll?.cancel();
                ref.read(orderProvider.notifier).loadOrders();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Payment waiting realtime: $e');
    }
  }

  Future<void> _open() async {
    setState(() => _opening = true);
    try {
      var url = _invoice;
      if (url == null || url.isEmpty) {
        final res = await SupabaseService.client.functions.invoke(
          'create-xendit-payment',
          body: {'order_id': widget.orderId},
        );
        final data = res.data is Map ? res.data as Map : {};
        url = data['invoice_url']?.toString();
        if (res.status != 200 || url == null) {
          if (mounted) {
            showNeuSnack(
              context,
              data['error']?.toString() ??
                  'The payment page could not be opened.',
              tone: NeuToneKind.error,
            );
          }
          return;
        }
        setState(() => _invoice = url);
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        showNeuSnack(
          context,
          'Could not open the payment page: $e',
          tone: NeuToneKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showNeuConfirm(
      context,
      title: 'Cancel this order?',
      message: 'Reserved items go back to the canteen and nothing is charged.',
      confirmLabel: 'Cancel order',
      cancelLabel: 'Keep order',
      destructive: true,
      icon: Icons.cancel_outlined,
    );
    if (!ok || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final done = await ref
          .read(orderProvider.notifier)
          .cancelOrder(widget.orderId);
      if (!mounted) return;
      if (done) {
        setState(() {
          _pay = 'failed';
          _status = 'cancelled';
        });
      }
      showNeuSnack(
        context,
        done ? 'Order cancelled.' : 'The order could not be cancelled.',
        tone: done ? NeuToneKind.info : NeuToneKind.error,
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mm = (_left ~/ 60).toString().padLeft(2, '0');
    final ss = (_left % 60).toString().padLeft(2, '0');
    final (
      IconData icon,
      Color tone,
      String title,
      String line,
    ) = switch (_pay) {
      'paid' => (
        Icons.verified_rounded,
        AppColors.success,
        'Payment received',
        'The canteen has your order. It flies once it is packed.',
      ),
      'expired' => (
        Icons.timer_off_outlined,
        AppColors.warning,
        'Payment window closed',
        'The 15 minutes ran out before a payment arrived.',
      ),
      _ when _status == 'cancelled' || _pay == 'failed' => (
        Icons.cancel_outlined,
        AppColors.danger,
        'Order cancelled',
        'Nothing was charged.',
      ),
      _ => (
        Icons.hourglass_top_rounded,
        AppColors.accent,
        'Waiting for your payment',
        'Finish paying on the payment page. This updates by itself.',
      ),
    };
    final waiting = !_settled;

    final status = WebPanel(
      depth: NeuDepth.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 44, color: AppColors.readable(tone)),
          const SizedBox(height: 12),
          Text(title, style: WebText.display(26)),
          const SizedBox(height: 6),
          Text(line, style: WebText.body(size: 15)),
          if (waiting) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                Text('$mm:$ss', style: WebText.numeric(size: 34)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('left to pay', style: WebText.body(size: 13.5)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            NeuSurface(
              style: NeuStyle.inset,
              depth: NeuDepth.flat,
              color: AppColors.surfaceSunken,
              height: 10,
              borderRadius: BorderRadius.circular(5),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (_left / _window).clamp(0.0, 1.0),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _left < 120
                        ? AppColors.warning
                        : AppColors.accentFill,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (waiting)
                WebButton(
                  label: 'Open the payment page',
                  icon: Icons.open_in_new_rounded,
                  loading: _opening,
                  onPressed: _open,
                ),
              if (waiting)
                WebButton(
                  label: 'Cancel order',
                  kind: WebButtonKind.secondary,
                  loading: _cancelling,
                  onPressed: _cancel,
                ),
              if (!waiting)
                WebButton(
                  label: 'View the order',
                  icon: Icons.receipt_long_outlined,
                  onPressed: () => context.go('/user/orders/${widget.orderId}'),
                ),
              if (!waiting)
                WebButton(
                  label: 'Back to the shop',
                  kind: WebButtonKind.secondary,
                  onPressed: () => context.go('/user/shop'),
                ),
            ],
          ),
        ],
      ),
    );

    final o = _order;
    final summary = WebPanel(
      title: 'Order ${orderRef(widget.orderId)}',
      subtitle: o?.vendorName,
      child: o == null
          ? (_loading
                ? const WebSkeleton(height: 140)
                : Text(
                    'Order details are not available.',
                    style: WebText.body(),
                  ))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final i in o.items)
                  WebKeyValue(
                    '${i.quantity} × ${i.productName}',
                    WebText.peso(i.unitPrice * i.quantity),
                  ),
                const WebGroove(),
                WebKeyValue('Drone delivery', WebText.peso(o.deliveryFee)),
                WebKeyValue(
                  'Total',
                  WebText.peso(o.totalAmount),
                  emphasis: true,
                ),
                if (o.dropoffLocationName != null)
                  WebKeyValue('Lands at', o.dropoffLocationName!),
              ],
            ),
    );

    return WebPage(
      title: 'Payment',
      back: true,
      onBack: () => context.go('/user/orders'),
      maxWidth: 1040,
      children: [
        WebSplit(main: status, side: summary, sideWidth: 360, breakpoint: 860),
      ],
    );
  }
}
