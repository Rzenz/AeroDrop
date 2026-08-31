import 'dart:math' as math;
import 'dart:ui' show ImageFilter, PathMetric, Tangent;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_feedback.dart';

/// The choice screen between onboarding and authentication.
///
/// Onboarding explains the product; this screen asks a single question — which
/// door are you coming in through. So it carries no new argument for the app,
/// just the mark, one line naming what it does, and the four ways in.
///
/// The backdrop is the UC Lapu-Lapu and Mandaue campus itself, with a drone
/// crossing the sky above it. Photography of the actual place beats an
/// invented graphic: it tells a student where this app runs before they read
/// a word of it.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  /// One controller for the whole screen. Every beat below is an [Interval] on
  /// it, which keeps the choreography readable in one place and costs a single
  /// ticker instead of one per element.
  late final AnimationController _intro;

  /// The delivery run, repeating. Split from [_intro] on purpose: one is a
  /// one-shot entrance, the other never stops, and folding a loop into a
  /// timeline that also drives the buttons would mean the buttons' interval
  /// re-fires on every lap.
  late final AnimationController _loop;

  static const _total = Duration(milliseconds: 1750);

  /// Slow enough to read as a drone crossing a campus rather than a marquee.
  /// This is the only motion left on screen once the entrance finishes, so it
  /// has to survive being watched.
  static const _lap = Duration(milliseconds: 6200);

  bool _reduceMotionApplied = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: _total);
    _loop = AnimationController(vsync: this, duration: _lap);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotionApplied) return;
    _reduceMotionApplied = true;

    // Honour the OS "reduce motion" switch: show the finished composition
    // rather than a shorter version of the same movement.
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
      // Parked mid-route rather than hidden. The composition still reads as a
      // delivery in progress; it simply does not move.
      _loop.value = 0.45;
    } else {
      // The lap only begins once the route has finished drawing itself, so the
      // drone never flies over a line that is not there yet.
      _intro.forward().then((_) {
        if (mounted) _loop.repeat();
      });
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  void _go(String location) {
    HapticFeedback.lightImpact();
    context.push(location);
  }

  void _continueWithGoogle() {
    HapticFeedback.lightImpact();
    // Deliberately not a silent no-op. The app has no OAuth provider wired to
    // Supabase yet, so the honest thing is to say so rather than open a sheet
    // that cannot finish. Replace this body with the real call once
    // `signInWithOAuth(OAuthProvider.google)` is configured.
    showNeuSnack(
      context,
      'Google sign-in is not connected yet. Use your email and password.',
      tone: NeuToneKind.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height;
    final compact = height < 720;
    final gutter = AppSpacing.pageGutter(context);

    // The photo gets a share of the screen, not the leftover. Large text
    // scales need the room more than the campus does, so it gives some back
    // rather than pushing the buttons off the bottom.
    final scaled = media.textScaler.scale(16) / 16;
    final heroFraction = scaled > 1.2
        ? 0.30
        : compact
        ? 0.36
        : 0.46;
    final heroHeight = (height * heroFraction).clamp(170.0, 440.0);

    return Scaffold(
      backgroundColor: AppColors.base,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: _CampusHero(intro: _intro, loop: _loop),
          ),
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                // Sits on the bottom edge when there is room and scrolls when
                // there is not, so the last button stays reachable at any text
                // size.
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _Panel(
                      progress: _intro,
                      gutter: gutter,
                      compact: compact,
                      onLogin: () => _go('/login'),
                      onVendorLogin: () => _go('/login?role=vendor'),
                      onGoogle: _continueWithGoogle,
                      onRegister: () => _go('/register'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero ──────────────────────────────────────────────────────────────────

/// The campus photograph, a slow push-in, and a drone crossing the sky.
///
/// The lower edge ramps to the canvas colour so the photo does not end on a
/// hard line — the panel below reads as the same surface continuing, which is
/// what stops this looking like a picture pasted above a form.
class _CampusHero extends StatelessWidget {
  const _CampusHero({required this.intro, required this.loop});

  final Animation<double> intro;
  final Animation<double> loop;

  @override
  Widget build(BuildContext context) {
    final settle = CurvedAnimation(
      parent: intro,
      curve: const Interval(0, 0.9, curve: Curves.easeOutCubic),
    );
    final fade = CurvedAnimation(
      parent: intro,
      curve: const Interval(0, 0.3, curve: Curves.easeOut),
    );

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The hero keeps a dark treatment in both themes. The photo is a
          // blue building under a bright sky and the drone is drawn in white
          // line art — on a light canvas the drone disappears into the clouds.
          const ColoredBox(color: AppColors.bgDark),

          FadeTransition(
            opacity: fade,
            child: AnimatedBuilder(
              animation: settle,
              // A slow push-in that comes to rest. It ends on 1.0 rather than
              // drifting forever, so the backdrop is genuinely still and the
              // only thing moving is the delivery.
              builder: (context, child) => Transform.scale(
                scale: 1.12 - 0.12 * settle.value,
                child: child,
              ),
              child: Image.asset(
                'assets/images/uclm_campus.jpg',
                fit: BoxFit.cover,
                // Keeps the signage in frame when a narrow screen crops the
                // sides off a landscape photograph.
                alignment: const Alignment(-0.12, 0),
                // Held well back against the dark base underneath. The sky in
                // this photograph is near-white and the route is drawn in
                // light — at full strength the two cancel out.
                opacity: const AlwaysStoppedAnimation(0.45),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Brand wash. Pulls the photograph's greys toward the icon's palette
          // without tinting it so hard the building stops being a building.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x3D4FB1F6), Color(0x662C56AC)],
              ),
            ),
          ),

          // Isolated so a lap repaints the route and the drone, and leaves the
          // photograph, the wash and the ramp alone.
          RepaintBoundary(
            child: _Route(intro: intro, loop: loop),
          ),

          // Melt into the panel.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 0.84, 1.0],
                colors: [
                  AppColors.base.withValues(alpha: 0.0),
                  AppColors.base.withValues(alpha: 0.12),
                  AppColors.base.withValues(alpha: 0.86),
                  AppColors.base,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pickup pin, route, drop-off pin, and the drone running between them.
///
/// The route is the product in one picture: an order leaves a vendor, flies a
/// corridor, lands at a drop zone. It is the same read as the tracking screen,
/// which is where this user ends up.
class _Route extends StatelessWidget {
  const _Route({required this.intro, required this.loop});

  final Animation<double> intro;
  final Animation<double> loop;

  /// Where the drone stops flying and starts landing, on the lap timeline.
  static const _arrive = 0.80;

  @override
  Widget build(BuildContext context) {
    final pins = CurvedAnimation(
      parent: intro,
      curve: const Interval(0.08, 0.34, curve: Curves.easeOutBack),
    );
    final draw = CurvedAnimation(
      parent: intro,
      curve: const Interval(0.18, 0.70, curve: Curves.easeInOutCubic),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.isEmpty) return const SizedBox.shrink();

        final metric = _corridor(size).computeMetrics().first;
        final origin = metric.getTangentForOffset(0)!.position;
        final target = metric.getTangentForOffset(metric.length)!.position;

        // Built once and handed to the AnimatedBuilder below as its `child`.
        // The drone carries a blurred copy of itself as a shadow; rebuilding
        // that inside the animation would re-rasterize a blur every frame.
        final drone = RepaintBoundary(
          child: _DroneMark(size: math.min(size.shortestSide * 0.16, 54)),
        );

        return Stack(
          children: [
            // The corridor, dashed and faint. Its own painter so a lap does
            // not redraw it — only the flown overlay changes.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: draw,
                builder: (context, _) => CustomPaint(
                  painter: _CorridorPainter(metric: metric, drawn: draw.value),
                ),
              ),
            ),

            Positioned.fill(
              child: AnimatedBuilder(
                animation: loop,
                builder: (context, child) {
                  final t = (loop.value / _arrive).clamp(0.0, 1.0);
                  final flown = Curves.easeInOutCubic.transform(t);

                  // The line reaches the pin; the drone stops just short of
                  // it. Landing the two on the same point merges the marker
                  // and the aircraft into one unreadable shape.
                  final tangent = metric.getTangentForOffset(
                    metric.length * flown * 0.94,
                  );

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _FlownPainter(
                            metric: metric,
                            flown: flown,
                            fade: _tailFade(loop.value),
                          ),
                        ),
                      ),
                      if (tangent != null)
                        _positionDrone(tangent, loop.value, child!),
                    ],
                  );
                },
                child: drone,
              ),
            ),

            // Both pins on one builder. Reading `pins.value` straight into
            // the tree would sample it once, at first build, and leave them
            // parked at scale zero forever.
            // Positioned.fill, not a bare child: a Stack whose children are
            // all Positioned has nothing to size itself from, collapses to
            // zero, and then clips the pins out of existence.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: pins,
                builder: (context, _) => Stack(
                  children: [
                    _pin(origin, pins.value, Icons.location_on_rounded, false),
                    _pin(target, pins.value, Icons.location_on_rounded, true),
                  ],
                ),
              ),
            ),

            // The landing ring, once per lap, on the drop pin.
            Positioned(
              left: target.dx - 40,
              top: target.dy - 40,
              child: AnimatedBuilder(
                animation: loop,
                builder: (context, _) => _LandingPulse(t: loop.value),
              ),
            ),
          ],
        );
      },
    );
  }

  /// A shallow arc rising into the sky between the two pins. Curved because
  /// campus flight corridors are, and because a straight line across a hero
  /// reads as a divider rather than a route.
  Path _corridor(Size size) {
    final start = Offset(size.width * 0.15, size.height * 0.60);
    final end = Offset(size.width * 0.85, size.height * 0.30);
    final control = Offset(size.width * 0.48, size.height * 0.06);
    return Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
  }

  /// Fades the flown line back to bare dashes after the drone lands, so the
  /// next lap starts from an empty corridor instead of cutting.
  double _tailFade(double lap) {
    if (lap <= _arrive) return 1;
    return 1 - ((lap - _arrive) / (1 - _arrive)).clamp(0.0, 1.0);
  }

  Widget _positionDrone(Tangent tangent, double lap, Widget drone) {
    // Banks into the curve rather than sitting flat on it. Capped well short
    // of the raw tangent angle — a drone that rotates a full 40 degrees reads
    // as a paper plane.
    final angle = math.atan2(tangent.vector.dy, tangent.vector.dx) * 0.4;

    // Lifts off over the first slice of the lap and sets down over the last,
    // so it leaves and reaches a pin instead of blinking in mid-air.
    final opacity = lap < 0.06
        ? lap / 0.06
        : lap > _arrive
        ? (1 - (lap - _arrive) / 0.12).clamp(0.0, 1.0)
        : 1.0;

    return Positioned(
      left: tangent.position.dx - _DroneMark.box / 2,
      top: tangent.position.dy - _DroneMark.box / 2,
      // Opacity and rotation only. Position comes from Positioned, which is a
      // layout write, but it changes one leaf with no children to reflow.
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(angle: angle, child: drone),
      ),
    );
  }

  Widget _pin(Offset at, double t, IconData icon, bool isTarget) {
    const size = 34.0;
    final tint = isTarget ? AppColors.accent : Colors.white;

    return Positioned(
      left: at.dx - size / 2,
      // Map pins point at their spot from above it, so the anchor is the tip,
      // not the middle.
      top: at.dy - size,
      child: Transform.scale(
        scale: t.clamp(0.0, 1.2),
        alignment: Alignment.bottomCenter,
        child: Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.bgDark.withValues(alpha: 0.82),
              shape: BoxShape.circle,
              border: Border.all(
                color: tint.withValues(alpha: 0.7),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.bgDark.withValues(alpha: 0.55),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: 18, color: tint),
          ),
        ),
      ),
    );
  }
}

/// The drone with its own shadow. Built once per layout and reused across
/// every frame of the lap.
class _DroneMark extends StatelessWidget {
  const _DroneMark({required this.size});

  final double size;

  /// The layout box the parent positions against.
  static const box = 54.0;

  @override
  Widget build(BuildContext context) {
    final art = SvgPicture.asset('assets/svg/drone_delivery.svg');

    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // A blurred dark copy of the drone itself, not a shadow on a
              // circle. A circular BoxShadow behind line art paints a grey
              // disc, which against a bright sky looks like a sticker.
              Transform.translate(
                offset: const Offset(0, 2),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Color(0xB30C1120),
                      BlendMode.srcIn,
                    ),
                    child: art,
                  ),
                ),
              ),
              ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                child: art,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The full corridor, dashed, drawing itself once on entrance.
class _CorridorPainter extends CustomPainter {
  const _CorridorPainter({required this.metric, required this.drawn});

  final PathMetric metric;

  /// How much of the corridor has appeared, 0–1.
  final double drawn;

  @override
  void paint(Canvas canvas, Size size) {
    if (drawn <= 0) return;
    final end = metric.length * drawn;

    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.30);

    final shade = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.bgDark.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    const dash = 8.0;
    const gap = 7.0;
    var d = 0.0;
    while (d < end) {
      final seg = metric.extractPath(d, math.min(d + dash, end));
      // A dark pass under the light one so the dashes survive the bright sky
      // in the upper half of the photograph.
      canvas.drawPath(seg, shade);
      canvas.drawPath(seg, ink);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_CorridorPainter old) =>
      old.drawn != drawn || old.metric != metric;
}

/// The distance already flown, drawn solid over the dashes.
class _FlownPainter extends CustomPainter {
  const _FlownPainter({
    required this.metric,
    required this.flown,
    required this.fade,
  });

  final PathMetric metric;
  final double flown;

  /// Dims the whole flown line while the corridor resets between laps.
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    if (flown <= 0 || fade <= 0) return;
    final path = metric.extractPath(0, metric.length * flown);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent.withValues(alpha: 0.24 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent.withValues(alpha: fade),
    );
  }

  @override
  bool shouldRepaint(_FlownPainter old) =>
      old.flown != flown || old.fade != fade || old.metric != metric;
}

/// One expanding ring on the drop pin as the drone sets down.
///
/// Not a permanent pulse. A marker that throbs forever is a notification; this
/// fires once per delivery, which is what actually happened.
class _LandingPulse extends StatelessWidget {
  const _LandingPulse({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    const from = _Route._arrive - 0.04;
    const span = 0.20;
    final p = ((t - from) / span);
    if (p <= 0 || p >= 1) return const SizedBox(width: 80, height: 80);

    final eased = Curves.easeOutCubic.transform(p);

    return SizedBox(
      width: 80,
      height: 80,
      child: Center(
        child: Transform.scale(
          scale: 0.4 + eased * 0.9,
          child: Opacity(
            opacity: (1 - eased) * 0.55,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Panel ─────────────────────────────────────────────────────────────────

/// Mark, one line, four doors.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.progress,
    required this.gutter,
    required this.compact,
    required this.onLogin,
    required this.onVendorLogin,
    required this.onGoogle,
    required this.onRegister,
  });

  final Animation<double> progress;
  final double gutter;
  final bool compact;
  final VoidCallback onLogin;
  final VoidCallback onVendorLogin;
  final VoidCallback onGoogle;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final buttonHeight = compact ? 50.0 : 54.0;
    final gap = compact ? AppSpacing.xs + 2 : AppSpacing.sm;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          gutter,
          compact ? AppSpacing.sm : AppSpacing.md,
          gutter,
          compact ? AppSpacing.md : AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Entrance(
              progress: progress,
              start: 0.30,
              child: Align(
                alignment: Alignment.centerLeft,
                child: BrandMark(size: compact ? 42 : 48),
              ),
            ),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            Entrance(
              progress: progress,
              start: 0.36,
              child: _Headline(compact: compact),
            ),
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),

            // Returning users first — most people arriving here already have
            // an account, and the two vendor and student doors sit together
            // because they are the same decision.
            Entrance(
              progress: progress,
              start: 0.46,
              child: NeuButton(
                text: 'Login',
                height: buttonHeight,
                onPressed: onLogin,
              ),
            ),
            SizedBox(height: gap),

            Entrance(
              progress: progress,
              start: 0.52,
              child: NeuButton(
                text: 'Login as vendor',
                variant: NeuButtonVariant.neutral,
                icon: Icons.storefront_rounded,
                height: buttonHeight,
                onPressed: onVendorLogin,
              ),
            ),
            SizedBox(height: gap),

            Entrance(
              progress: progress,
              start: 0.58,
              child: NeuButton(
                text: 'Continue with Google',
                variant: NeuButtonVariant.neutral,
                height: buttonHeight,
                leading: SvgPicture.asset(
                  'assets/svg/google_g.svg',
                  width: 19,
                  height: 19,
                ),
                onPressed: onGoogle,
              ),
            ),
            SizedBox(height: gap),

            Entrance(
              progress: progress,
              start: 0.64,
              child: NeuButton(
                text: 'Register an account',
                variant: NeuButtonVariant.neutral,
                height: buttonHeight,
                onPressed: onRegister,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two tones so the product name is the first thing read and the sentence
/// still says what the app does.
class _Headline extends StatelessWidget {
  const _Headline({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final base = AppTextStyles.display(
      fontSize: compact ? 20 : 23,
    ).copyWith(height: 1.25);

    return Text.rich(
      TextSpan(
        children: [
          // Sky blue, from the top of the app icon's gradient. [accentText]
          // rather than the raw accent so the name still clears 4.5:1 if the
          // app is switched to the light canvas.
          TextSpan(
            text: 'AeroDrop',
            style: base.copyWith(color: AppColors.accentText),
          ),
          TextSpan(
            text: '  delivers meals, books and campus supplies by drone.',
            style: base,
          ),
        ],
      ),
    );
  }
}
