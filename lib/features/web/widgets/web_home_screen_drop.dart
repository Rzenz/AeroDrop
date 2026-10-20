import 'package:flutter/material.dart';

import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/drone_svg_painter.dart';
import '../web_tokens.dart';
import 'web_motion.dart';

/// A phone home screen that a drone delivers the AeroDrop icon onto.
///
/// Motion purpose (`animate`): explanation, at the rare-and-first-time tier
/// where a little delight is allowed. "Install" is abstract; a drone lowering
/// the icon into an empty slot says what happens and says it in the
/// product's own terms. It plays once when it scrolls into view, then holds.
/// Under reduced motion it renders the finished screen.
///
/// Choosing a platform in the Download section replays it on that platform's
/// phone, so the steps beside it and the picture always agree: the platform
/// changed, and here is the app landing on that phone.
///
/// The other slots are deliberately blank. Drawing other companies' app
/// icons would borrow their brands, and drawing invented ones would be
/// filler (R-38).
/// Which phone to draw. The difference is kept to the camera cut-out and the
/// corner radius — enough to tell an Android phone from an iPhone at a
/// glance without drawing either maker's hardware in detail.
enum WebPhoneKind { android, iphone }

class WebHomeScreenDrop extends StatefulWidget {
  const WebHomeScreenDrop({
    super.key,
    required this.width,
    this.kind = WebPhoneKind.android,
    this.replay = 0,
  });

  final double width;
  final WebPhoneKind kind;

  /// Change this to play the drop again from the start.
  final int replay;

  @override
  State<WebHomeScreenDrop> createState() => _WebHomeScreenDropState();
}

class _WebHomeScreenDropState extends State<WebHomeScreenDrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _drop.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant WebHomeScreenDrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.replay != oldWidget.replay && !reduced) {
      _drop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _drop.dispose();
    super.dispose();
  }

  // The screen is laid out at this size and scaled, like the hero phone.
  static const Size _design = Size(260, 540);

  double get _outerRadius => widget.kind == WebPhoneKind.iphone ? 40 : 30;

  @override
  Widget build(BuildContext context) {
    final height = widget.width * _design.height / _design.width;

    return PlayWhenVisible(
      onVisible: () {
        if (_drop.value == 0) _drop.forward();
      },
      child: Semantics(
        image: true,
        label: 'A drone placing the AeroDrop icon on a phone home screen',
        excludeSemantics: true,
        child: Container(
          width: widget.width,
          height: height,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF05070D),
            borderRadius: BorderRadius.circular(_outerRadius),
            boxShadow: WebElevation.hero,
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: ClipRRect(
            // Concentric: the outer radius minus the 8px bezel.
            borderRadius: BorderRadius.circular(_outerRadius - 8),
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox.fromSize(
                size: _design,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _drop,
                    builder: (context, _) =>
                        _Screen(t: _drop.value, kind: widget.kind),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({required this.t, required this.kind});
  final double t;
  final WebPhoneKind kind;

  static const _cols = 4;
  static const _rows = 5;
  static const _slot = 46.0;
  static const _top = 74.0;
  static const _rowGap = 24.0;

  /// The empty slot the icon is delivered into: second row, second column.
  static const _targetRow = 1;
  static const _targetCol = 1;

  static double _phase(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    const w = 260.0;
    const gapX = (w - 28 * 2 - _slot * _cols) / (_cols - 1);
    Offset slotAt(int row, int col) =>
        Offset(28 + col * (_slot + gapX), _top + row * (_slot + _rowGap));

    final target = slotAt(_targetRow, _targetCol);

    // Beats: fly in and hover (0–0.42), lower on the line (0.42–0.62),
    // release and settle (0.62–0.72), drone leaves and the label appears
    // (0.72–1).
    final arrive = Curves.easeOutCubic.transform(_phase(t, 0, 0.42));
    final lower = Curves.easeInOutCubic.transform(_phase(t, 0.42, 0.62));
    final settle = _phase(t, 0.62, 0.72);
    final leave = Curves.easeInCubic.transform(_phase(t, 0.72, 0.95));
    final label = _phase(t, 0.74, 0.9);

    // The drone hovers 58px above the slot, arrives from above the screen,
    // and leaves up and to the right once the icon is down.
    const hoverGap = 58.0;
    final droneX = target.dx + _slot / 2 + leave * 150;
    final droneY = (target.dy - hoverGap) - (1 - arrive) * 190 - leave * 260;

    // The icon hangs on a line under the drone until released.
    final hanging = settle == 0;
    final iconY = hanging ? droneY + 26 + lower * (hoverGap - 26) : target.dy;
    // A small settle on release: 1.06 back to 1 — restrained, not a bounce.
    final iconScale = hanging ? 0.9 + 0.1 * lower : 1.06 - 0.06 * settle;

    return DecoratedBox(
      // The wallpaper: a city at night, dimmed so the icons and their
      // labels stay the brightest thing on the screen.
      decoration: const BoxDecoration(
        color: WebInk.canvas,
        image: DecorationImage(
          image: AssetImage(WebPhoto.wallpaper),
          onError: WebPhoto.ignore,
          fit: BoxFit.cover,
          alignment: Alignment(0.1, 0),
          colorFilter: ColorFilter.mode(Color(0x59000000), BlendMode.srcOver),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Camera cut-out: an island on iPhone, a punch-hole on Android.
          Positioned(
            top: kind == WebPhoneKind.iphone ? 12 : 14,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedContainer(
                duration: WebMotion.hover,
                curve: WebMotion.enter,
                width: kind == WebPhoneKind.iphone ? 78 : 16,
                height: kind == WebPhoneKind.iphone ? 22 : 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF05070D),
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),

          // Blank slots.
          for (var r = 0; r < _rows; r++)
            for (var c = 0; c < _cols; c++)
              if (!(r == _targetRow && c == _targetCol))
                Positioned(
                  left: slotAt(r, c).dx,
                  top: slotAt(r, c).dy,
                  child: _blank(),
                ),

          // The target slot's outline, until the icon lands in it.
          Positioned(
            left: target.dx,
            top: target.dy,
            child: Opacity(
              opacity: 1 - settle,
              child: Container(
                width: _slot,
                height: _slot,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: WebInk.accent.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // Dock.
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [for (var i = 0; i < 4; i++) _blank()],
              ),
            ),
          ),

          // The tether, while the icon hangs.
          if (hanging && t > 0)
            Positioned(
              left: droneX - 0.75,
              top: droneY + 12,
              child: Container(
                width: 1.5,
                height: (iconY - droneY - 12).clamp(0.0, 200.0),
                color: WebInk.text.withValues(alpha: 0.7),
              ),
            ),

          // The icon.
          if (t > 0)
            Positioned(
              left: (hanging ? droneX - _slot / 2 : target.dx),
              top: iconY,
              child: Transform.scale(
                scale: iconScale,
                child: const BrandMark(size: _slot, elevated: false),
              ),
            ),

          // Its label, once it has landed.
          Positioned(
            left: target.dx - 12,
            width: _slot + 24,
            top: target.dy + _slot + 6,
            child: Opacity(
              opacity: label,
              child: Text(
                'AeroDrop',
                textAlign: TextAlign.center,
                style: WebType.meta(
                  color: Colors.white,
                ).copyWith(fontSize: 10.5, fontWeight: FontWeight.w500),
              ),
            ),
          ),

          // The drone.
          if (t > 0 && t < 0.97)
            Positioned(
              left: droneX - 24,
              top: droneY - 20,
              child: SizedBox(
                width: 48,
                height: 48,
                child: CustomPaint(
                  painter: DroneSvgPainter(
                    animationValue: t * 18,
                    lineColor: WebInk.text,
                    accentColor: WebInk.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _blank() => Container(
    width: _slot,
    height: _slot,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
    ),
  );
}
