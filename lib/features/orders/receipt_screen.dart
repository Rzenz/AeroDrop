import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_feedback.dart';
import '../../core/widgets/receipt_printer.dart';

/// Everything printed on the receipt.
///
/// Built by the checkout screen from the order it just placed, and handed over
/// as route `extra`. A plain value object rather than a provider read: the
/// receipt is a record of one moment, and it must not change under the user
/// because the cart or the order list moved on behind it.
class ReceiptData {
  const ReceiptData({
    required this.orderRef,
    required this.vendorName,
    required this.lines,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.paymentLabel,
    required this.placedAt,
    this.dropoffName,
  });

  final String orderRef;
  final String vendorName;
  final List<ReceiptLine> lines;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String paymentLabel;
  final DateTime placedAt;
  final String? dropoffName;
}

/// One printed line item.
class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final int quantity;
  final double unitPrice;

  double get amount => unitPrice * quantity;
}

/// The receipt that prints itself after an order is placed.
///
/// The paper feeds out of a slot rather than fading in, because that is the
/// one motion that says "this is a record of something that happened" instead
/// of "here is another confirmation card". It runs once, on a screen a user
/// reaches a handful of times — which is exactly where a longer sequence earns
/// its keep.

/// The receipt that prints itself after an order is placed.
///
/// The machine, the feed and the torn edge live in [ReceiptPrinter]; this
/// screen owns the stage, the sheet's contents, and what happens once the
/// paper is out.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.data});

  final ReceiptData data;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  /// Captures the paper alone — not the machine, not the buttons — so the
  /// saved PNG is the receipt and nothing else.
  final _paperKey = GlobalKey();

  /// Starts at [ReceiptPrinterStage.printing] rather than processing: the
  /// order was placed and awaited by the checkout screen before this route was
  /// pushed, so a "Processing your order" beat here would be a wait the app is
  /// not actually doing. The stage exists on the component for callers that
  /// mount the printer before their order resolves.
  ReceiptPrinterStage _stage = ReceiptPrinterStage.printing;

  Timer? _finish;
  bool _saving = false;
  bool _armed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_armed) return;
    _armed = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _stage = ReceiptPrinterStage.complete;
      return;
    }
    _finish = Timer(ReceiptPrinter.feedDuration, () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _stage = ReceiptPrinterStage.complete);
    });
  }

  @override
  void dispose() {
    _finish?.cancel();
    super.dispose();
  }

  bool get _printed => _stage == ReceiptPrinterStage.complete;

  Future<void> _download() async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    try {
      final boundary =
          _paperKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // 3x so the saved image holds up when opened full-screen in Photos.
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (bytes == null) throw StateError('Could not encode the receipt.');

      await Gal.putImageBytes(
        bytes.buffer.asUint8List(),
        name: 'AeroDrop-${widget.data.orderRef}',
        album: 'AeroDrop',
      );

      if (!mounted) return;
      showNeuSnack(
        context,
        'Receipt saved to your photos.',
        tone: NeuToneKind.success,
      );
    } on GalException catch (e) {
      if (!mounted) return;
      // Gal reports a refused photo-library permission as its own type, and
      // that needs different advice from a failure to encode.
      showNeuSnack(
        context,
        e.type == GalExceptionType.accessDenied
            ? 'AeroDrop needs permission to add to your photos.'
            : 'Could not save the receipt. Please try again.',
        tone: NeuToneKind.error,
      );
    } catch (_) {
      if (!mounted) return;
      showNeuSnack(
        context,
        'Could not save the receipt. Please try again.',
        tone: NeuToneKind.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpacing.pageGutter(context);

    return PopScope(
      // Back during printing would leave the user on the cart they just
      // emptied. The receipt is the end of the flow; home is the way out.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/user');
      },
      child: Scaffold(
        backgroundColor: AppColors.base,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    AppSpacing.md,
                    gutter,
                    AppSpacing.md,
                  ),
                  child: ReceiptPrinter(
                    stage: _stage,
                    screen: _Summary(data: widget.data),
                    // Clipped inside the boundary, so the saved PNG carries
                    // the torn edge too rather than a square crop of it.
                    paper: RepaintBoundary(
                      key: _paperKey,
                      child: ClipPath(
                        clipper: const ReceiptTornEdgeClipper(),
                        child: _Paper(data: widget.data),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpacing.lg),
                child: _Actions(
                  visible: _printed,
                  saving: _saving,
                  onDownload: _download,
                  onHome: () {
                    HapticFeedback.lightImpact();
                    context.go('/user');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What shows on the machine's screen: who it is from, and the amount.
class _Summary extends StatelessWidget {
  const _Summary({required this.data});

  final ReceiptData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.vendorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.heading(fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                '${data.lines.length} item${data.lines.length == 1 ? '' : 's'}',
                style: AppTextStyles.caption(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Total', style: AppTextStyles.caption(fontSize: 11.5)),
            const SizedBox(height: 2),
            Text(_peso(data.total), style: AppTextStyles.numeric(fontSize: 20)),
          ],
        ),
      ],
    );
  }
}

String _peso(double v) => '₱${v.toStringAsFixed(2)}';

String _stamp(DateTime d) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} ${d.year} · $h:$m';
}

/// The printed sheet.
///
/// Deliberately not themed: paper is paper in both light and dark mode, and a
/// receipt that inverts with the app would stop looking like a thing that came
/// out of a machine. Its ink colours are fixed for the same reason, which also
/// means the saved PNG looks the same for everyone.
class _Paper extends StatelessWidget {
  const _Paper({required this.data});

  final ReceiptData data;

  static const _stock = Color(0xFFF4F3EF);
  static const _ink = Color(0xFF15161A);
  static const _faint = Color(0xFF7B7E88);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _stock,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 22,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: _PrintedMark()),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'AERODROP',
                    style: AppTextStyles.receipt(
                      fontSize: 12,
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'UCLM Drone Delivery',
                    style: AppTextStyles.receipt(fontSize: 10, color: _faint),
                  ),
                ),
                const SizedBox(height: 16),
                const _Perforation(),
                const SizedBox(height: 14),

                for (final line in data.lines) ...[
                  _LineItem(line: line),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 2),
                const _Perforation(),
                const SizedBox(height: 12),

                _Row(label: 'Subtotal', value: _peso(data.subtotal)),
                _Row(label: 'Delivery fee', value: _peso(data.deliveryFee)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        'TOTAL PAID',
                        style: AppTextStyles.receipt(
                          fontSize: 12.5,
                          color: _ink,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Text(
                      _peso(data.total),
                      style: AppTextStyles.receipt(
                        fontSize: 19,
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _Perforation(),
                const SizedBox(height: 12),

                _Row(label: 'Order', value: data.orderRef, mono: true),
                _Row(label: 'Paid with', value: data.paymentLabel),
                if (data.dropoffName != null)
                  _Row(label: 'Drop-off', value: data.dropoffName!),
                _Row(label: 'Date', value: _stamp(data.placedAt)),

                const SizedBox(height: 20),
                Center(child: _Barcode(seed: data.orderRef)),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    data.orderRef.replaceAll('-', ' '),
                    style: AppTextStyles.receipt(
                      fontSize: 9,
                      color: _faint,
                      letterSpacing: 2.4,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
          // The tooth depth the printer's clipper bites out of the sheet, so
          // the content never runs into the tear.
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// The mark, printed.
///
/// The line-art version rather than the app tile: the sheet is one ink on one
/// stock, and a saturated gradient logo would be the only colour on it.
///
/// Multiplied against the paper instead of being cut out in an editor — under
/// multiply, white goes to exactly the stock colour and the linework stays
/// black, so the mark sits on the paper with no seam and the source asset is
/// left untouched.
class _PrintedMark extends StatelessWidget {
  const _PrintedMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(_Paper._stock, BlendMode.multiply),
        child: Image.asset(
          'assets/images/receipt_mark.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({required this.line});

  final ReceiptLine line;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.name.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.receipt(
                  fontSize: 11.5,
                  color: _Paper._ink,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                '${line.quantity} × ${_peso(line.unitPrice)}',
                style: AppTextStyles.receipt(
                  fontSize: 10,
                  color: _Paper._faint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _peso(line.amount),
          style: AppTextStyles.receipt(fontSize: 11.5, color: _Paper._ink),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.receipt(
                fontSize: 10.5,
                color: _Paper._faint,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTextStyles.receipt(
                fontSize: 10.5,
                color: _Paper._ink,
                fontWeight: mono ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A dashed rule, drawn so the dash length stays constant at any width.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(double.infinity, 1),
    painter: _DashPainter(),
  );
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _Paper._faint.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + dash, size.width), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}

/// A barcode. Its bars come from the order reference, so two receipts never
/// carry the same pattern — a fixed decorative barcode is a lie about a real
/// document.
class _Barcode extends StatelessWidget {
  const _Barcode({required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(double.infinity, 46),
    painter: _BarcodePainter(seed: seed),
  );
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter({required this.seed});

  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed.hashCode);
    final paint = Paint()..color = _Paper._ink;

    var x = size.width * 0.16;
    final limit = size.width * 0.84;
    while (x < limit) {
      final w = 1.0 + rng.nextInt(3);
      if (rng.nextBool()) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      }
      x += w + 1;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.seed != seed;
}

/// The zig-zag where the paper was torn off the roll.
// ─── Actions ───────────────────────────────────────────────────────────────

/// Download and Home, revealed once the paper is out.
///
/// Held back rather than disabled: a button you cannot press yet is noise, and
/// there is nothing to download until the receipt exists.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.visible,
    required this.saving,
    required this.onDownload,
    required this.onHome,
  });

  final bool visible;
  final bool saving;
  final VoidCallback onDownload;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: AppMotion.normal,
      curve: AppMotion.enter,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 0.35),
          duration: AppMotion.slow,
          curve: AppMotion.enter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NeuButton(
                text: 'Download Receipt',
                icon: Icons.download_rounded,
                isLoading: saving,
                onPressed: onDownload,
              ),
              const SizedBox(height: AppSpacing.sm),
              NeuButton(
                text: 'Home',
                variant: NeuButtonVariant.neutral,
                icon: Icons.home_rounded,
                onPressed: onHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
