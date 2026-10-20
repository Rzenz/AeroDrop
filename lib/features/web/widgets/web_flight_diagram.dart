import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../core/widgets/drone_svg_painter.dart';
import '../web_breakpoints.dart';
import '../web_tokens.dart';
import 'web_actions.dart';
import 'web_motion.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/widgets/neu_input_border.dart';

/// One delivery, played out: the four pre-flight checks, then the three legs
/// the dispatch function actually flies — hub to vendor empty, vendor to the
/// customer loaded, back to the hub empty.
///
/// It is a diagram, not a map. The stops are placed for legibility, because
/// the campus coordinates in the repo disagree with each other by kilometres
/// and a map drawn from them would show a campus that does not exist.
///
/// Motion purpose (`animate`): explanation. It is the one place on the page
/// that shows the order of operations rather than describing it. It plays
/// once when it scrolls into view, holds on the last frame, and replays only
/// when asked. Under reduced motion it renders the finished run.
class WebFlightDiagram extends StatefulWidget {
  const WebFlightDiagram({super.key});

  /// The dispatch checks, in the order the dispatch function runs them.
  static const checks = [
    'Weather not grounded',
    'Drone idle',
    'Battery at 15% or more',
    'Cargo under 0.5 kg',
  ];

  @override
  State<WebFlightDiagram> createState() => _WebFlightDiagramState();
}

/// The timeline, as fractions of [_WebFlightDiagramState._run].
class _Beat {
  static const checksEnd = 0.24;
  static const leg1End = 0.46;
  static const leg2End = 0.74;
  static const leg3End = 0.94;
}

class _WebFlightDiagramState extends State<WebFlightDiagram>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7200),
  );

  bool get _reduced => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduced) _run.value = 1;
  }

  void _play() {
    if (_reduced) return;
    _run.forward(from: 0);
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);

    return PlayWhenVisible(
      onVisible: _play,
      child: Container(
        padding: EdgeInsets.all(brk.isCompact ? 20 : 28),
        decoration: BoxDecoration(
          color: WebInk.canvas,
          borderRadius: BorderRadius.circular(brk.isCompact ? 24 : 30),
          boxShadow: WebInk.web.shadows(NeuDepth.medium),
        ),
        child: AnimatedBuilder(
          animation: _run,
          builder: (context, _) {
            final t = _run.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Checks(t: t),
                SizedBox(height: brk.isCompact ? 18 : 24),
                AspectRatio(
                  aspectRatio: brk.isCompact ? 1.1 : 1.45,
                  child: CustomPaint(painter: _RoutePainter(t)),
                ),
                const SizedBox(height: 18),
                const WebRule(),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _Caption(t: t)),
                    const SizedBox(width: 16),
                    // Offered only once a run has finished, so it never
                    // interrupts one, and never under reduced motion.
                    AnimatedOpacity(
                      opacity: t >= 1 && !_reduced ? 1 : 0,
                      duration: WebMotion.hover,
                      child: IgnorePointer(
                        ignoring: t < 1 || _reduced,
                        child: WebRuledAction(
                          label: 'Fly it again',
                          onTap: _play,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Checks extends StatelessWidget {
  const _Checks({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final n = WebFlightDiagram.checks.length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < n; i++)
          _Check(
            label: WebFlightDiagram.checks[i],
            passed: t >= _Beat.checksEnd * (i + 1) / n,
          ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.label, required this.passed});
  final String label;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    // A check marks a real state change in the sequence, so it carries a
    // static cue (the tick and the label colour), not only the motion.
    return AnimatedContainer(
      duration: WebMotion.hover,
      curve: WebMotion.enter,
      padding: const EdgeInsets.fromLTRB(9, 6, 12, 6),
      // Waiting checks sit pressed into the panel; a passed one stands up.
      decoration: ShapeDecoration(
        color: passed ? WebInk.canvas : WebInk.web.sunken,
        shape: passed
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            : NeuInsetInputBorder(
                palette: WebInk.web,
                distance: 1.5,
                borderRadius: BorderRadius.circular(10),
              ),
        shadows: passed ? WebInk.web.shadows(NeuDepth.flat) : const [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: WebMotion.hover,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: Tween(begin: 0.25, end: 1.0).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              passed ? Icons.check_rounded : Icons.circle_outlined,
              key: ValueKey(passed),
              size: 14,
              color: passed ? WebInk.accent : WebInk.textFaint,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: WebType.meta(
                color: passed ? WebInk.text : WebInk.textSoft,
              ).copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.t});
  final double t;

  String get _text {
    if (t <= 0) return 'Every run starts with four checks on the ground.';
    if (t < _Beat.checksEnd) {
      return 'Pre-flight: nothing leaves the hub until all four pass.';
    }
    if (t < _Beat.leg1End) {
      return 'Leg 1 of 3 · Hub to the vendor, flying empty.';
    }
    if (t < _Beat.leg2End) {
      return 'Leg 2 of 3 · Vendor to your building, carrying the order.';
    }
    if (t < _Beat.leg3End) return 'Leg 3 of 3 · Back to the hub to recharge.';
    return 'Delivered. The run is logged and your receipt is issued.';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.bottomLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: WebMotion.enter)),
          child: child,
        ),
      ),
      child: Text(
        _text,
        key: ValueKey(_text),
        style: WebType.body(color: WebInk.text).copyWith(fontSize: 14.5),
      ),
    );
  }
}

/// Draws the three stops, the three legs, and the drone.
class _RoutePainter extends CustomPainter {
  _RoutePainter(this.t);

  final double t;

  // Stop positions as fractions of the canvas.
  static const _hub = Offset(0.14, 0.26);
  static const _vendor = Offset(0.86, 0.22);
  static const _building = Offset(0.56, 0.84);

  static double _phase(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  Path _leg(Size s, Offset a, Offset control, Offset b) {
    Offset p(Offset f) => Offset(f.dx * s.width, f.dy * s.height);
    return Path()
      ..moveTo(p(a).dx, p(a).dy)
      ..quadraticBezierTo(p(control).dx, p(control).dy, p(b).dx, p(b).dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final legs = [
      _leg(size, _hub, const Offset(0.50, -0.06), _vendor),
      _leg(size, _vendor, const Offset(0.96, 0.70), _building),
      _leg(size, _building, const Offset(0.06, 0.86), _hub),
    ];
    final progress = [
      Curves.easeInOutCubic.transform(
        _phase(t, _Beat.checksEnd, _Beat.leg1End),
      ),
      Curves.easeInOutCubic.transform(_phase(t, _Beat.leg1End, _Beat.leg2End)),
      Curves.easeInOutCubic.transform(_phase(t, _Beat.leg2End, _Beat.leg3End)),
    ];

    final planned = Paint()
      ..color = WebInk.rule
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < legs.length; i++) {
      final metric = legs[i].computeMetrics().first;

      // The planned route, dashed.
      for (var d = 0.0; d < metric.length; d += 12) {
        canvas.drawPath(metric.extractPath(d, d + 6), planned);
      }

      // The flown part. The loaded leg is drawn in the accent and heavier,
      // because it is the one carrying the customer's order.
      if (progress[i] > 0) {
        final loaded = i == 1;
        canvas.drawPath(
          metric.extractPath(0, metric.length * progress[i]),
          Paint()
            ..color = loaded ? WebInk.accent : WebInk.textSoft
            ..style = PaintingStyle.stroke
            ..strokeWidth = loaded ? 3.5 : 2
            ..strokeCap = StrokeCap.round,
        );
      }

      _legLabel(canvas, size, metric, i);
    }

    // The hub's label goes underneath: the drone parks on the hub before and
    // after the run, and would sit on a label placed above it.
    _stop(canvas, size, _hub, 'Hub', below: true);
    _stop(canvas, size, _vendor, 'Vendor', below: false);
    _stop(canvas, size, _building, 'Your building', below: true);

    _drone(canvas, size, legs, progress);
  }

  void _legLabel(Canvas canvas, Size size, PathMetric metric, int i) {
    const labels = ['Leg 1 · empty', 'Leg 2 · loaded', 'Leg 3 · empty'];
    final tangent = metric.getTangentForOffset(metric.length * 0.5);
    if (tangent == null) return;
    final painter = TextPainter(
      text: TextSpan(
        text: labels[i],
        style: WebType.meta(
          color: i == 1 ? WebInk.accent : WebInk.textFaint,
        ).copyWith(fontSize: 11.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Offset each label to the outside of its curve.
    final nudge = switch (i) {
      0 => const Offset(-0.5, -1.9),
      1 => const Offset(0.25, 0.4),
      _ => const Offset(-1.15, 0.6),
    };
    final at =
        tangent.position +
        Offset(painter.width * nudge.dx, painter.height * nudge.dy);
    // Kept inside the canvas: on a phone the curves run close to the edges
    // and an outside label would be clipped by the card.
    final origin = Offset(
      at.dx.clamp(0.0, size.width - painter.width),
      at.dy.clamp(0.0, size.height - painter.height),
    );
    // A backing in the card's own fill, so a label that lands on a route
    // line (as they do on narrow screens) still reads.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (origin & painter.size).inflate(4),
        const Radius.circular(5),
      ),
      Paint()..color = WebInk.raised,
    );
    painter.paint(canvas, origin);
    painter.dispose();
  }

  void _stop(
    Canvas canvas,
    Size size,
    Offset at,
    String label, {
    required bool below,
  }) {
    final c = Offset(at.dx * size.width, at.dy * size.height);
    canvas.drawCircle(c, 9, Paint()..color = WebInk.raised);
    canvas.drawCircle(
      c,
      9,
      Paint()
        ..color = WebInk.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(c, 3.5, Paint()..color = WebInk.text);

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: WebType.action(color: WebInk.text).copyWith(fontSize: 13),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = (c.dx - painter.width / 2).clamp(
      0.0,
      size.width - painter.width,
    );
    painter.paint(
      canvas,
      Offset(dx, below ? c.dy + 16 : c.dy - 16 - painter.height),
    );
    painter.dispose();
  }

  void _drone(Canvas canvas, Size size, List<Path> legs, List<double> p) {
    // Where the drone is: on the leg in progress, otherwise parked at the
    // hub — before the run and after it.
    Offset at = Offset(_hub.dx * size.width, _hub.dy * size.height);
    var loaded = false;
    for (var i = 0; i < legs.length; i++) {
      if (p[i] > 0 && p[i] < 1) {
        final metric = legs[i].computeMetrics().first;
        at = metric.getTangentForOffset(metric.length * p[i])!.position;
        loaded = i == 1;
      }
    }

    const side = 38.0;
    final flying = p.any((v) => v > 0 && v < 1);

    // The package hangs under the drone on the loaded leg only.
    if (loaded) {
      final box = Rect.fromCenter(
        center: at + const Offset(0, 16),
        width: 12,
        height: 10,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(2.5)),
        Paint()..shader = WebSky.afternoon.gradient.createShader(box),
      );
    }

    canvas.save();
    canvas.translate(at.dx - side / 2, at.dy - side / 2 - 4);
    DroneSvgPainter(
      // Propellers turn only while it flies.
      animationValue: flying ? t * 24 : 0,
      lineColor: WebInk.text,
      accentColor: WebInk.accent,
    ).paint(canvas, const Size(side, side));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.t != t;
}
