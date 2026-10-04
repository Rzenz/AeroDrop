import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/order_model.dart';
import '../../core/providers/order_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_feedback.dart';

class OnlinePaymentWaitingScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String? initialInvoiceUrl;

  const OnlinePaymentWaitingScreen({
    super.key,
    required this.orderId,
    this.initialInvoiceUrl,
  });

  @override
  ConsumerState<OnlinePaymentWaitingScreen> createState() =>
      _OnlinePaymentWaitingScreenState();
}

class _OnlinePaymentWaitingScreenState
    extends ConsumerState<OnlinePaymentWaitingScreen> {
  OrderModel? _order;
  String? _invoiceUrl;
  String _paymentStatus = 'pending';
  String _orderStatus = 'pending';
  String? _paymentChannel;
  bool _isLoading = true;
  bool _isLaunching = false;
  bool _isCancelling = false;

  int _remainingSeconds = 900; // 15 minutes
  Timer? _countdownTimer;
  Timer? _pollTimer;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _invoiceUrl = widget.initialInvoiceUrl;
    _initOrderAndSubscriptions();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initOrderAndSubscriptions() async {
    await _fetchOrder();
    _startCountdown();
    _subscribeToRealtime();
    _startPollTimer();
  }

  Future<void> _fetchOrder() async {
    if (!SupabaseService.isConfigured || widget.orderId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final res = await SupabaseService.client
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

      if (res != null && mounted) {
        final order = OrderModel.fromMap(Map<String, dynamic>.from(res));
        _updateWithOrder(order);
      }
    } catch (e) {
      debugPrint('Error fetching order for waiting screen: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateWithOrder(OrderModel order) {
    setState(() {
      _order = order;
      _paymentStatus = order.paymentStatus.toLowerCase();
      _orderStatus = order.orderStatus.toLowerCase();
      _paymentChannel = order.paymentChannel;
      if (order.paymentInvoiceUrl != null && order.paymentInvoiceUrl!.isNotEmpty) {
        _invoiceUrl = order.paymentInvoiceUrl;
      }

      // Compute remaining time against 15-minute invoice window
      final elapsed = DateTime.now().difference(order.createdAt).inSeconds;
      final left = 900 - elapsed;
      _remainingSeconds = left > 0 ? left : 0;
    });

    if (_paymentStatus == 'paid') {
      _countdownTimer?.cancel();
      _pollTimer?.cancel();
      HapticFeedback.heavyImpact();
    } else if (_paymentStatus == 'expired' ||
        _paymentStatus == 'failed' ||
        _orderStatus == 'cancelled') {
      _countdownTimer?.cancel();
      _pollTimer?.cancel();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        // Time expired
        if (_paymentStatus == 'pending') {
          setState(() {
            _paymentStatus = 'expired';
          });
        }
      }
    });
  }

  void _subscribeToRealtime() {
    if (!SupabaseService.isConfigured || widget.orderId.isEmpty) return;

    try {
      _realtimeChannel = SupabaseService.client
          .channel('xendit_waiting_${widget.orderId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: widget.orderId,
            ),
            callback: (payload) {
              final newRow = payload.newRecord;
              final pStatus = newRow['payment_status']?.toString().toLowerCase() ?? 'pending';
              final oStatus = newRow['order_status']?.toString().toLowerCase() ?? 'pending';
              final channel = newRow['payment_channel']?.toString();
              final invUrl = newRow['payment_invoice_url']?.toString();

              if (!mounted) return;
              setState(() {
                _paymentStatus = pStatus;
                _orderStatus = oStatus;
                if (channel != null) _paymentChannel = channel;
                if (invUrl != null && invUrl.isNotEmpty) _invoiceUrl = invUrl;
              });

              if (pStatus == 'paid') {
                _countdownTimer?.cancel();
                _pollTimer?.cancel();
                HapticFeedback.heavyImpact();
                ref.read(orderProvider.notifier).loadOrders();
              } else if (pStatus == 'expired' || pStatus == 'failed' || oStatus == 'cancelled') {
                _countdownTimer?.cancel();
                _pollTimer?.cancel();
                ref.read(orderProvider.notifier).loadOrders();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime subscription error on waiting screen: $e');
    }
  }

  void _startPollTimer() {
    // 4-second fallback poll to ensure updates if websocket is suspended
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted || _paymentStatus == 'paid' || _paymentStatus == 'expired') {
        timer.cancel();
        return;
      }
      await _fetchOrder();
    });
  }

  Future<void> _openInvoice() async {
    if (_invoiceUrl == null || _invoiceUrl!.isEmpty) {
      // Re-invoke create-xendit-payment to generate/retrieve the URL
      setState(() => _isLaunching = true);
      try {
        final fnRes = await SupabaseService.client.functions.invoke(
          'create-xendit-payment',
          body: {'order_id': widget.orderId},
        );
        final data = fnRes.data is Map ? fnRes.data as Map : {};
        final newUrl = data['invoice_url']?.toString();
        if (fnRes.status == 200 && newUrl != null) {
          setState(() => _invoiceUrl = newUrl);
          await launchUrl(Uri.parse(newUrl), mode: LaunchMode.externalApplication);
        } else {
          final err = data['error']?.toString() ?? 'Unable to open checkout portal.';
          if (mounted) showNeuSnack(context, err, tone: NeuToneKind.error);
        }
      } catch (e) {
        if (mounted) {
          showNeuSnack(context, 'Could not launch payment: $e', tone: NeuToneKind.error);
        }
      } finally {
        if (mounted) setState(() => _isLaunching = false);
      }
      return;
    }

    setState(() => _isLaunching = true);
    try {
      final uri = Uri.parse(_invoiceUrl!);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        showNeuSnack(context, 'Could not open browser: $e', tone: NeuToneKind.error);
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(
          'Cancel This Order?',
          style: AppTextStyles.subHead(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'If you cancel, any reserved items will be returned to the store and no payment will be processed.',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Order', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);
    try {
      final ok = await ref.read(orderProvider.notifier).cancelOrder(widget.orderId);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _paymentStatus = 'failed';
          _orderStatus = 'cancelled';
        });
        showNeuSnack(context, 'Order has been cancelled.', tone: NeuToneKind.info);
      } else {
        showNeuSnack(context, 'Unable to cancel order.', tone: NeuToneKind.error);
      }
    } catch (e) {
      if (mounted) {
        showNeuSnack(context, 'Cancellation failed: $e', tone: NeuToneKind.error);
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      appBar: CustomAppBar(
        title: 'Online Payment',
        fallbackRoute: '/user/orders',
        onBackPressed: () => context.go('/user/orders'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (_paymentStatus == 'paid')
                    _buildPaidView()
                  else if (_paymentStatus == 'expired' || _orderStatus == 'cancelled')
                    _buildExpiredView()
                  else if (_paymentStatus == 'failed')
                    _buildFailedView()
                  else
                    _buildWaitingView(),
                ],
              ),
            ),
    );
  }

  Widget _buildWaitingView() {
    final shortId = widget.orderId.length >= 8
        ? widget.orderId.substring(0, 8).toUpperCase()
        : widget.orderId.toUpperCase();

    return Column(
      children: [
        const SizedBox(height: 20),
        // Pulsing Radar / Payment Icon
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: 0.12),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 2),
          ),
          child: const Center(
            child: Icon(
              Icons.credit_card_rounded,
              size: 48,
              color: AppColors.accent,
            ),
          ),
        )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1200.ms),

        const SizedBox(height: 28),
        Text(
          'Waiting for Payment',
          style: AppTextStyles.display(fontSize: 22, color: AppColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Order #$shortId',
          style: AppTextStyles.subHead(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Countdown Timer Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _remainingSeconds < 180 ? AppColors.danger : AppColors.accent,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 18,
                color: _remainingSeconds < 180 ? AppColors.danger : AppColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                'Expires in ${_formatTime(_remainingSeconds)}',
                style: AppTextStyles.subHead(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _remainingSeconds < 180 ? AppColors.danger : Colors.white,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        NeuCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Complete your payment in the Xendit checkout window. This page will automatically update once verified.',
                      style: AppTextStyles.body(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              if (_order != null) ...[
                const SizedBox(height: 16),
                Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Amount', style: AppTextStyles.body(color: AppColors.textSecondary)),
                    Text(
                      '₱${_order!.totalAmount.toStringAsFixed(2)}',
                      style: AppTextStyles.subHead(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 32),
        // Primary Action: Reopen Payment Page
        NeuButton(
          text: _isLaunching ? 'Opening Checkout...' : 'Reopen Payment Page',
          icon: Icons.open_in_browser_rounded,
          variant: NeuButtonVariant.accent,
          isLoading: _isLaunching,
          onPressed: _openInvoice,
        ),
        const SizedBox(height: 14),

        // Secondary Action: Cancel Order
        NeuButton(
          text: 'Cancel Order',
          icon: Icons.close_rounded,
          variant: NeuButtonVariant.danger,
          isLoading: _isCancelling,
          onPressed: _cancelOrder,
        ),
        const SizedBox(height: 14),

        // Tertiary Action: Back to Orders list
        TextButton(
          onPressed: () => context.go('/user/orders'),
          child: Text(
            'Check Orders List (Payment continues in background)',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildPaidView() {
    final methodDisplay = _paymentChannel != null && _paymentChannel!.isNotEmpty
        ? (_paymentChannel!.toUpperCase().contains('GCASH')
            ? 'GCash'
            : (_paymentChannel!.toUpperCase().contains('CARD') ? 'Card' : _paymentChannel))
        : 'Online Payment';

    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.success, width: 2),
          ),
          child: const Center(
            child: Icon(Icons.check_circle_rounded, size: 54, color: AppColors.success),
          ),
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 24),
        Text(
          'Payment Confirmed!',
          style: AppTextStyles.display(fontSize: 24, color: AppColors.success),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Your payment via $methodDisplay was successfully received and verified.',
          style: AppTextStyles.body(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        NeuCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Payment Channel', style: AppTextStyles.body(color: AppColors.textSecondary)),
                  Text(
                    methodDisplay!,
                    style: AppTextStyles.subHead(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Status', style: AppTextStyles.body(color: AppColors.textSecondary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PAID',
                      style: AppTextStyles.label(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (_order != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Amount', style: AppTextStyles.body(color: AppColors.textSecondary)),
                    Text(
                      '₱${_order!.totalAmount.toStringAsFixed(2)}',
                      style: AppTextStyles.subHead(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.accent),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 36),
        NeuButton(
          text: 'Continue to Order Tracking',
          icon: Icons.arrow_forward_rounded,
          variant: NeuButtonVariant.accent,
          onPressed: () => context.go('/user/orders/${widget.orderId}'),
        ),
      ],
    );
  }

  Widget _buildExpiredView() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.danger.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.danger, width: 2),
          ),
          child: const Center(
            child: Icon(Icons.timer_off_outlined, size: 48, color: AppColors.danger),
          ),
        ).animate().fadeIn().scale(),
        const SizedBox(height: 24),
        Text(
          'Payment Window Expired',
          style: AppTextStyles.display(fontSize: 22, color: AppColors.danger),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'The 15-minute payment session has timed out. No funds were captured, and reserved items have been restored to the vendor.',
          style: AppTextStyles.body(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),
        NeuButton(
          text: 'View My Orders',
          icon: Icons.list_alt_rounded,
          variant: NeuButtonVariant.neutral,
          onPressed: () => context.go('/user/orders'),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => context.go('/user'),
          child: Text('Return to Food & Drinks', style: TextStyle(color: AppColors.accent)),
        ),
      ],
    );
  }

  Widget _buildFailedView() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.danger.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.danger, width: 2),
          ),
          child: const Center(
            child: Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
          ),
        ).animate().fadeIn().scale(),
        const SizedBox(height: 24),
        Text(
          'Payment Incomplete',
          style: AppTextStyles.display(fontSize: 22, color: AppColors.danger),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'The online transaction was cancelled or could not be completed. Your order has been marked cancelled.',
          style: AppTextStyles.body(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),
        NeuButton(
          text: 'Back to Orders',
          icon: Icons.list_alt_rounded,
          variant: NeuButtonVariant.neutral,
          onPressed: () => context.go('/user/orders'),
        ),
      ],
    );
  }
}
