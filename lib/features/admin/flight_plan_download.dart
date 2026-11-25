import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/analytics_export_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/neu_feedback.dart';

/// The file order_to_mission.py reads: `order-<first 8 of the id>.json`.
String flightPlanFileName(String orderId) =>
    'order-${orderId.length > 8 ? orderId.substring(0, 8) : orderId}.json';

/// Admin only: fetches an order's flight plan (get_order_flight_plan) and
/// saves it as JSON, the input to order_to_mission.py. While the fetch runs
/// only this button is disabled; an error shows under it, in the server's
/// own words.
class FlightPlanDownloadButton extends StatefulWidget {
  final String orderId;

  const FlightPlanDownloadButton({super.key, required this.orderId});

  @override
  State<FlightPlanDownloadButton> createState() =>
      _FlightPlanDownloadButtonState();
}

class _FlightPlanDownloadButtonState extends State<FlightPlanDownloadButton> {
  bool _busy = false;
  String? _error;

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!SupabaseService.isConfigured) {
        throw StateError(
          'Flight plans need the server, which is not configured.',
        );
      }
      // The plan's pickup and drop-off are only final once the vendor has
      // marked the order ready; before that they fall back to the vendor's
      // building and the order's drop-off. The JSON carries delivery.status,
      // so the operator can tell which they have.
      final plan = await SupabaseService.client.rpc(
        'get_order_flight_plan',
        params: {'p_order_id': widget.orderId},
      );
      // Saved as the server returned it: re-encoded with a 2-space indent,
      // keys in the order they arrived, nothing rounded or dropped.
      final text = '${const JsonEncoder.withIndent('  ').convert(plan)}\n';
      final fileName = flightPlanFileName(widget.orderId);
      if (!mounted) return;
      final saved = await AnalyticsExportService.saveOrShareFile(
        bytes: Uint8List.fromList(utf8.encode(text)),
        fileName: fileName,
        mimeType: 'application/json',
        context: context,
        dialogTitle: 'Save flight plan',
        shareText: 'AeroDrop flight plan: $fileName',
      );
      // Null when the save dialog was cancelled
      if (!mounted || saved == null) return;
      // The full path on desktop; the file name where the OS chose the place
      showNeuSnack(
        context,
        'Flight plan saved: $saved',
        tone: NeuToneKind.success,
      );
    } on PostgrestException catch (e) {
      // The server's sentence, e.g. 'Unauthorized: caller cannot read this order'
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomButton(
          text: 'Download flight plan',
          icon: Icons.download_rounded,
          variant: ButtonVariant.ghost,
          isLoading: _busy,
          onPressed: _busy ? null : _download,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(fontSize: 12, color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}
