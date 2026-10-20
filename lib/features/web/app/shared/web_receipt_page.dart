import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../../../orders/receipt_screen.dart';
import '../web_kit.dart';

/// The receipt as a page: the printed slip on the left, exactly as the app
/// prints it, and the summary with what to do next beside it. Saving
/// downloads the slip as a PNG through the browser.
class WebReceiptPage extends StatefulWidget {
  const WebReceiptPage({super.key, required this.data});

  final ReceiptData data;

  @override
  State<WebReceiptPage> createState() => _WebReceiptPageState();
}

class _WebReceiptPageState extends State<WebReceiptPage> {
  final _paper = GlobalKey();
  bool _saving = false;

  bool get _vendor => GoRouterState.of(context).uri.path.startsWith('/vendor');

  Future<void> _download() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary =
          _paper.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('The receipt could not be encoded.');
      final safe = widget.data.orderRef.replaceAll(RegExp(r'[^\w\-]'), '_');
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save receipt',
        fileName: 'AeroDrop-Receipt-$safe.png',
        bytes: bytes.buffer.asUint8List(),
        type: FileType.custom,
        allowedExtensions: ['png'],
      );
      if (!mounted) return;
      showNeuSnack(context, 'Receipt downloaded.', tone: NeuToneKind.success);
    } catch (e) {
      if (mounted) {
        showNeuSnack(
          context,
          'The receipt could not be saved: $e',
          tone: NeuToneKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final home = _vendor ? '/vendor' : '/user';

    final slip = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: NeuSurface(
          depth: NeuDepth.medium,
          borderRadius: BorderRadius.circular(26),
          padding: const EdgeInsets.all(18),
          color: AppColors.surfaceSunken,
          child: RepaintBoundary(
            key: _paper,
            child: ReceiptPaper(data: d),
          ),
        ),
      ),
    );

    final summary = WebPanel(
      depth: NeuDepth.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 40,
            color: AppColors.readable(AppColors.success),
          ),
          const SizedBox(height: 10),
          Text(
            d.orderStatus == null ? 'Order placed' : d.orderStatus!,
            style: WebText.display(24),
          ),
          const SizedBox(height: 4),
          Text(d.vendorName, style: WebText.body(size: 14)),
          const WebGroove(vertical: 16),
          WebKeyValue('Reference', d.orderRef),
          WebKeyValue('Paid with', d.paymentLabel),
          if (d.dropoffName != null) WebKeyValue('Lands at', d.dropoffName!),
          WebKeyValue('Subtotal', WebText.peso(d.subtotal)),
          WebKeyValue('Drone delivery', WebText.peso(d.deliveryFee)),
          WebKeyValue('Total', WebText.peso(d.total), emphasis: true),
          const SizedBox(height: 18),
          if (d.deliveryId != null) ...[
            WebButton(
              label: 'Track the drone',
              icon: Icons.navigation_rounded,
              expand: true,
              onPressed: () => context.push(
                '${_vendor ? '/vendor' : '/user'}/track/details?id=${d.deliveryId}',
              ),
            ),
            const SizedBox(height: 10),
          ],
          WebButton(
            label: 'Download receipt',
            icon: Icons.download_rounded,
            kind: WebButtonKind.secondary,
            expand: true,
            loading: _saving,
            onPressed: _download,
          ),
          const SizedBox(height: 10),
          WebButton(
            label: 'Back to the dashboard',
            kind: WebButtonKind.ghost,
            expand: true,
            onPressed: () => context.go(home),
          ),
        ],
      ),
    );

    return PopScope(
      // The receipt ends the checkout flow; back goes home, not to the
      // emptied cart.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(home);
      },
      child: WebPage(
        title: 'Receipt',
        subtitle:
            'Placed ${d.placedAt.day}/${d.placedAt.month}/${d.placedAt.year}',
        back: true,
        onBack: () => context.go(home),
        maxWidth: 1000,
        children: [
          WebSplit(main: slip, side: summary, sideWidth: 360, breakpoint: 820),
        ],
      ),
    );
  }
}
