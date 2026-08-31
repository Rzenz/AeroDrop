import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/entrance.dart';

/// First-run introduction.
///
/// One screen, not three. The old carousel asked for two swipes before anyone
/// could reach a sign-in button, and the two slides in the middle repeated
/// what the third already said. A single panel states what the app does and
/// puts the way in under it.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_armed) return;
    _armed = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  void _start() {
    HapticFeedback.mediumImpact();
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final compact = size.height < 720;
    final gutter = AppSpacing.pageGutter(context);

    // The banner takes a share of the screen so the copy below it always has
    // the same room, rather than being whatever is left over. At large text
    // scales it gives some of that share back — the words need it more than
    // the pattern does.
    final scaled = media.textScaler.scale(16) / 16;
    final fraction = scaled > 1.2
        ? 0.34
        : compact
        ? 0.46
        : 0.52;
    final bannerHeight = (size.height * fraction).clamp(220.0, 520.0);

    return Scaffold(
      backgroundColor: AppColors.base,
      body: Column(
        children: [
          SizedBox(
            height: bannerHeight,
            child: _Banner(progress: _intro, compact: compact),
          ),
          Expanded(
            // Centred when it fits, scrollable when it does not. The call to
            // action is the only thing on this screen worth reaching, so it
            // must never be the part that falls off the bottom.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      compact ? AppSpacing.md : AppSpacing.xl,
                      gutter,
                      compact ? AppSpacing.md : AppSpacing.xl,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Entrance(
                          progress: _intro,
                          start: 0.42,
                          child: _Headline(compact: compact),
                        ),
                        SizedBox(
                          height: compact ? AppSpacing.xs : AppSpacing.sm,
                        ),
                        Entrance(
                          progress: _intro,
                          start: 0.50,
                          child: Text(
                            'Order from campus vendors and have it flown to your '
                            'drop zone.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: compact ? AppSpacing.lg : AppSpacing.xxl,
                        ),
                        Entrance(
                          progress: _intro,
                          start: 0.58,
                          child: _SlideToStart(onConfirmed: _start),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Banner ────────────────────────────────────────────────────────────────

/// The brand panel: a tiled drone pattern under the app mark, cut off along a
/// curve so the screen does not read as two stacked rectangles.
class _Banner extends StatelessWidget {
  const _Banner({required this.progress, required this.compact});

  final Animation<double> progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final settle = CurvedAnimation(
      parent: progress,
      curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
    );

    return ClipPath(
      clipper: const _ArcClipper(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.brandGradient),
          ),
          // The pattern is the product's own line art, repeated. Drawn rather
          // than shipped as an image so it tiles at any size and stays a
          // single colour at any density.
          // Its own layer: thirty pieces of vector art that never change,
          // sitting under a knob that repaints on every frame of a drag.
          const Positioned.fill(child: RepaintBoundary(child: _DronePattern())),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: AnimatedBuilder(
                animation: settle,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, 24 * (1 - settle.value)),
                  child: Transform.scale(
                    scale: 0.88 + 0.12 * settle.value,
                    child: Opacity(opacity: settle.value, child: child),
                  ),
                ),
                child: _Lockup(compact: compact),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuts the banner's lower edge into a shallow dome.
class _ArcClipper extends CustomClipper<Path> {
  const _ArcClipper();

  /// How far the centre of the curve hangs below its edges.
  static const double _drop = 56;

  @override
  Path getClip(Size size) => Path()
    ..lineTo(0, size.height - _drop)
    ..quadraticBezierTo(
      size.width / 2,
      size.height + _drop,
      size.width,
      size.height - _drop,
    )
    ..lineTo(size.width, 0)
    ..close();

  @override
  bool shouldReclip(_ArcClipper old) => false;
}

/// The mark and the wordmark, on the banner.
class _Lockup extends StatelessWidget {
  const _Lockup({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: compact ? 66 : 84),
        SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
        Text(
          'AeroDrop',
          maxLines: 1,
          style: AppTextStyles.display(
            fontSize: compact ? 31 : 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'UCLM Drone Delivery System',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.label(
            fontSize: compact ? 10.5 : 11.5,
            letterSpacing: compact ? 1.1 : 1.6,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}

/// A field of drones and parcels, tiled behind the lockup.
class _DronePattern extends StatelessWidget {
  const _DronePattern();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const cell = 92.0;
          final cols = (constraints.maxWidth / cell).ceil() + 1;
          final rows = (constraints.maxHeight / cell).ceil() + 1;

          return Opacity(
            // Faint enough to stay a texture. Any louder and it competes with
            // the mark it is meant to sit behind.
            opacity: 0.16,
            child: Stack(
              children: [
                for (var r = 0; r < rows; r++)
                  for (var c = 0; c < cols; c++)
                    Positioned(
                      // Every other row is offset half a cell, so the grid
                      // reads as a pattern rather than as a spreadsheet.
                      left: c * cell + (r.isOdd ? cell / 2 : 0) - cell / 2,
                      top: r * cell - cell / 2,
                      width: cell,
                      height: cell,
                      child: Transform.rotate(
                        angle: ((r * 7 + c * 13) % 5 - 2) * 0.12,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: SvgPicture.asset(
                            'assets/svg/drone_delivery.svg',
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Copy and call to action ───────────────────────────────────────────────

/// Two tones, so the question and the answer read as one line.
class _Headline extends StatelessWidget {
  const _Headline({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final base = AppTextStyles.display(
      fontSize: compact ? 27 : 32,
    ).copyWith(height: 1.15);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Hungry? ',
            style: base.copyWith(color: AppColors.accentText),
          ),
          TextSpan(text: 'We fly it over.', style: base),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// The way in: drag the drone across the track to begin.
///
/// A slide rather than a tap because this is the one deliberate action on a
/// screen that has nothing else on it — and because a drag lets the control
/// show progress while it is happening, which a button cannot.
///
/// The knob follows the finger one-to-one and is released to a spring, per the
/// rule that gesture-driven motion is physics and not a curve: a flick carries
/// its velocity through the snap instead of having it thrown away and replaced
/// with a fixed duration.
class _SlideToStart extends StatefulWidget {
  const _SlideToStart({required this.onConfirmed});

  final VoidCallback onConfirmed;

  @override
  State<_SlideToStart> createState() => _SlideToStartState();
}

class _SlideToStartState extends State<_SlideToStart>
    with TickerProviderStateMixin {
  /// Knob position, 0 at rest and 1 at the far end.
  late final AnimationController _knob = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
  );

  /// Drives the chevrons. Stops once the user starts dragging — the hint has
  /// done its job and competing with the thing it was pointing at is noise.
  late final AnimationController _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  /// How far along the user has to get before releasing completes it. Low
  /// enough that a confident flick lands, high enough that a brush does not.
  static const double _threshold = 0.55;

  static const double _height = 68;
  static const double _knobSize = 52;
  static const double _inset = 8;

  /// A firm, barely-bouncy spring. Overshoot on a control that ends against a
  /// physical edge reads as a bug, not as personality.
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 32,
  );

  bool _dragging = false;
  bool _done = false;
  bool _armed = false;
  double _travel = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_armed) return;
    _armed = true;
    if (!MediaQuery.disableAnimationsOf(context)) _nudge.repeat();
  }

  @override
  void dispose() {
    _knob.dispose();
    _nudge.dispose();
    super.dispose();
  }

  void _onStart(DragStartDetails _) {
    if (_done) return;
    setState(() => _dragging = true);
    _knob.stop();
    _nudge.stop();
  }

  void _onUpdate(DragUpdateDetails d) {
    if (_done) return;
    _knob.value = (_knob.value + d.primaryDelta! / _travel).clamp(0.0, 1.0);
  }

  void _onEnd(DragEndDetails d) {
    if (_done) return;
    setState(() => _dragging = false);

    // Velocity in track-fractions per second, which is the unit the
    // controller animates in.
    final velocity = d.primaryVelocity == null
        ? 0.0
        : d.primaryVelocity! / _travel;

    // A hard flick completes even from short of the threshold: the user's
    // intent is in the speed, not only in the distance.
    final completes = _knob.value >= _threshold || velocity > 1.4;

    _knob
        .animateWith(
          SpringSimulation(_spring, _knob.value, completes ? 1 : 0, velocity),
        )
        .whenCompleteOrCancel(() {
          if (!mounted || !completes || _done) return;
          _done = true;
          widget.onConfirmed();
        });

    if (completes) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
      if (!MediaQuery.disableAnimationsOf(context)) _nudge.repeat();
    }
  }

  /// Completes without a drag.
  ///
  /// The semantics layer routes here, so the control is operable by anyone who
  /// cannot make a precise horizontal gesture — a slider that only answers to
  /// dragging is a locked door for them.
  void _complete() {
    if (_done) return;
    _done = true;
    HapticFeedback.mediumImpact();
    _knob
        .animateWith(SpringSimulation(_spring, _knob.value, 1, 0))
        .whenCompleteOrCancel(() {
          if (mounted) widget.onConfirmed();
        });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Get started',
      hint: 'Swipe right, or double tap to continue',
      excludeSemantics: true,
      onTap: _complete,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _travel = math.max(1, constraints.maxWidth - _inset * 2 - _knobSize);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _onStart,
            onHorizontalDragUpdate: _onUpdate,
            onHorizontalDragEnd: _onEnd,
            child: SizedBox(
              height: _height,
              child: AnimatedBuilder(
                animation: _knob,
                builder: (context, _) {
                  final t = _knob.value;
                  return Stack(
                    children: [
                      Positioned.fill(child: _Track(progress: t)),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _Label(progress: t, nudge: _nudge),
                        ),
                      ),
                      Positioned(
                        left: _inset + t * _travel,
                        top: (_height - _knobSize) / 2,
                        child: _Knob(size: _knobSize, pressed: _dragging),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The groove, with the distance already covered filled in behind the knob.
class _Track extends StatelessWidget {
  const _Track({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.base,
        borderRadius: AppRadii.brPill,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.raised(NeuDepth.medium),
      ),
      child: ClipRRect(
        borderRadius: AppRadii.brPill,
        child: Align(
          alignment: Alignment.centerLeft,
          // Width, not a transform: the fill is a measurement of how far the
          // user has got, and a scaled rounded rect would distort its ends.
          widthFactor: progress.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.accentFill.withValues(alpha: 0.18),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// The label and the chevrons, both giving way as the knob advances.
class _Label extends StatelessWidget {
  const _Label({required this.progress, required this.nudge});

  final double progress;
  final Animation<double> nudge;

  @override
  Widget build(BuildContext context) {
    // Clears early rather than at the end, so the knob is never sitting on
    // top of the words it is covering.
    final fade = (1 - progress * 1.8).clamp(0.0, 1.0);

    return Opacity(
      opacity: fade,
      child: Row(
        children: [
          const SizedBox(width: _SlideToStartState._knobSize + 18),
          Expanded(
            child: Text(
              'Get Started',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.title(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _Chevrons(progress: nudge),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
    );
  }
}

/// The drone the user pushes across the track.
class _Knob extends StatelessWidget {
  const _Knob({required this.size, required this.pressed});

  final double size;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: pressed ? 1.06 : 1,
      duration: AppMotion.instant,
      curve: AppMotion.standard,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accentFill,
          shape: BoxShape.circle,
          boxShadow: [
            ...AppShadows.raised(NeuDepth.low),
            ...AppShadows.glow(AppColors.accentFill, alpha: 0.30),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.22),
          child: RepaintBoundary(
            child: SvgPicture.asset(
              'assets/svg/drone_delivery.svg',
              colorFilter: ColorFilter.mode(
                AppColors.onAccentFill,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three chevrons brightening in sequence, left to right.
class _Chevrons extends StatelessWidget {
  const _Chevrons({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                // A travelling wave: each chevron peaks a third of a cycle
                // after the one before it.
                color: AppColors.accentText.withValues(
                  alpha:
                      0.25 +
                      0.75 *
                          math.max(
                            0,
                            math.sin((progress.value - i * 0.14) * 2 * math.pi),
                          ),
                ),
              ),
          ],
        );
      },
    );
  }
}
