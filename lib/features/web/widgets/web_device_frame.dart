import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/drone_svg_painter.dart';
import '../web_breakpoints.dart';
import '../web_tokens.dart';

/// The app's tracking screen in a device frame — the page's only elevated
/// element and its only piece of product imagery.
///
/// The screen inside keeps the app's own dark surface rather than being
/// restyled to match the page, because the point is to show what the product
/// actually looks like. A mock recoloured to suit the marketing page is a
/// drawing of a product, not a product.
///
/// Values are deliberately absent. Altitude, speed and battery render as the
/// bars that hold them, because there is no flight behind this page and
/// inventing "87%, 4 mins away" would be a fabricated metric.
class WebDeviceFrame extends StatefulWidget {
  const WebDeviceFrame({super.key});

  @override
  State<WebDeviceFrame> createState() => _WebDeviceFrameState();
}

class _WebDeviceFrameState extends State<WebDeviceFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  bool _running = false;

  void _setRunning(bool shouldRun) {
    if (shouldRun == _running) return;
    _running = shouldRun;
    if (shouldRun) {
      _sweep.repeat();
    } else {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final width = switch (brk) {
      WebBreak.expanded => 300.0,
      WebBreak.medium => 280.0,
      WebBreak.compact => 260.0,
    };
    final height = width * 2.02;

    // `baseline-ui`: pause looping animations when off-screen. The radar is a
    // liveness cue for a live-position screen, so it earns its loop, but it
    // has no business burning frames once the hero has scrolled away.
    return _VisibilityTicker(
      onVisibilityChanged: (visible) => _setRunning(visible && !reduced),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF05070D),
          borderRadius: BorderRadius.circular(38),
          boxShadow: WebElevation.hero,
        ),
        child: ClipRRect(
          // Concentric radius: outer 38 minus the 10px frame leaves 28, so the
          // screen's corner stays parallel to the device's instead of
          // crowding it. `better-ui`: outer radius = inner radius + padding.
          borderRadius: BorderRadius.circular(28),
          child: Container(
            color: AppColors.bgDark,
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tracking',
                  style: WebType.entry(
                    WebBreak.compact,
                    color: AppColors.textPrimaryDark,
                  ).copyWith(fontSize: 18),
                ),
                const SizedBox(height: 3),
                Text(
                  'Live drone position',
                  style: WebType.meta(color: AppColors.textTertiaryDark),
                ),
                const SizedBox(height: 26),
                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _sweep,
                      builder: (context, _) => SizedBox(
                        width: width * 0.66,
                        height: width * 0.66,
                        child: CustomPaint(
                          painter: _RadarPainter(reduced ? 0.3 : _sweep.value),
                          child: Center(
                            child: SizedBox(
                              width: width * 0.19,
                              height: width * 0.19,
                              child: CustomPaint(
                                painter: DroneSvgPainter(
                                  animationValue: 0,
                                  lineColor: AppColors.accentLight,
                                  accentColor: AppColors.accentLight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.sunkenDark,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.58,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(child: _Readout('Altitude')),
                    Expanded(child: _Readout('Speed')),
                    Expanded(child: _Readout('Battery')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: WebType.meta(
            color: AppColors.textTertiaryDark,
          ).copyWith(fontSize: 10.5),
        ),
        const SizedBox(height: 8),
        Container(
          width: 32,
          height: 7,
          decoration: BoxDecoration(
            color: AppColors.cardDark2,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
}

/// Reports whether the child is inside the viewport, so a caller can stop a
/// loop that nobody is looking at.
class _VisibilityTicker extends StatefulWidget {
  const _VisibilityTicker({
    required this.child,
    required this.onVisibilityChanged,
  });

  final Widget child;
  final ValueChanged<bool> onVisibilityChanged;

  @override
  State<_VisibilityTicker> createState() => _VisibilityTickerState();
}

class _VisibilityTickerState extends State<_VisibilityTicker> {
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (identical(next, _position)) return;
    _position?.removeListener(_check);
    _position = next?..addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final viewport = MediaQuery.sizeOf(context).height;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;

    widget.onVisibilityChanged(bottom > 0 && top < viewport);
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Concentric rings with a single sweep arm, matching the app's radar.
class _RadarPainter extends CustomPainter {
  _RadarPainter(this.phase);
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.borderDark;

    for (final f in [0.42, 0.71, 1.0]) {
      canvas.drawCircle(centre, maxR * f, ring);
    }

    final angle = phase * 2 * math.pi;
    canvas.drawLine(
      centre,
      centre + Offset(math.cos(angle), math.sin(angle)) * maxR,
      Paint()
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
