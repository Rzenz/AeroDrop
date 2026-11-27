import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/drone_bridge_client.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/neu_feedback.dart';

/// Reads the drop-off and cruise altitude from an order's flight plan
/// (get_order_flight_plan), the same numbers the bridge checks against.
(double, double, double?)? dropoffFromFlightPlan(Object? plan) {
  if (plan is! Map) return null;
  final wps = plan['waypoints'];
  if (wps is! List) return null;
  for (final wp in wps) {
    if (wp is Map && wp['role'] == 'dropoff') {
      final lat = (wp['latitude'] as num?)?.toDouble();
      final lon = (wp['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;
      final alt = (plan['altitude_m_agl'] as num?)?.toDouble();
      return (lat, lon, alt);
    }
  }
  return null;
}

/// Admin only: sends this delivery to the ground-station bridge, which arms
/// the drone and flies it. Shown while the delivery waits for its flight
/// (status assigning). The bridge's answer shows under the button.
class SendToDroneButton extends StatefulWidget {
  final String deliveryId;
  final String orderId;

  const SendToDroneButton({
    super.key,
    required this.deliveryId,
    required this.orderId,
  });

  @override
  State<SendToDroneButton> createState() => _SendToDroneButtonState();
}

class _SendToDroneButtonState extends State<SendToDroneButton> {
  String _address = '';
  bool _busy = false;
  BridgeReply? _reply;

  @override
  void initState() {
    super.initState();
    loadBridgeAddress().then((a) {
      if (mounted) setState(() => _address = a);
    });
  }

  Future<void> _editAddress() async {
    final controller = TextEditingController(text: _address);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ground station address'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: '192.168.1.100 or 192.168.1.100:5005',
            helperText: 'The laptop running aio.py, on the same Wi-Fi',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    if (value.trim().isNotEmpty && parseBridgeAddress(value) == null) {
      if (mounted) {
        showNeuSnack(
          context,
          'That address is not valid',
          tone: NeuToneKind.error,
        );
      }
      return;
    }
    await saveBridgeAddress(value);
    if (mounted) setState(() => _address = value.trim());
  }

  Future<void> _send() async {
    if (parseBridgeAddress(_address) == null) {
      await _editAddress();
      if (parseBridgeAddress(_address) == null) return;
    }
    if (!mounted) return;
    final go = await showNeuConfirm(
      context,
      title: 'Send to drone?',
      message:
          'The drone will arm and take off from the base right away. Make '
          'sure the package is attached, the area around the drone is clear, '
          'and the pilot has the RadioMaster ready to take over.',
      confirmLabel: 'Send',
      icon: Icons.flight_takeoff_rounded,
    );
    if (!go || !mounted) return;

    setState(() {
      _busy = true;
      _reply = null;
    });
    try {
      final plan = await SupabaseService.client.rpc(
        'get_order_flight_plan',
        params: {'p_order_id': widget.orderId},
      );
      final drop = dropoffFromFlightPlan(plan);
      if (drop == null) {
        throw StateError('The order has no drop-off position.');
      }
      final reply = await sendDeliveryToBridge(
        address: _address,
        payload: bridgePayload(
          deliveryId: widget.deliveryId,
          lat: drop.$1,
          lon: drop.$2,
          alt: drop.$3,
        ),
      );
      if (mounted) setState(() => _reply = reply);
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _reply = BridgeReply(false, e.message));
    } catch (e) {
      if (mounted) setState(() => _reply = BridgeReply(false, '$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reply = _reply;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomButton(
          text: 'Send to drone',
          icon: Icons.flight_takeoff_rounded,
          isLoading: _busy,
          onPressed: _busy ? null : _send,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                _address.isEmpty
                    ? 'Ground station: not set'
                    : 'Ground station: $_address',
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _editAddress,
              child: const Text('Change'),
            ),
          ],
        ),
        if (reply != null)
          Text(
            reply.message,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(
              fontSize: 12,
              color: reply.ok ? AppColors.success : AppColors.danger,
            ),
          ),
      ],
    );
  }
}
