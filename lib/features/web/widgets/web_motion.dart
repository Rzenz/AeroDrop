import 'package:flutter/material.dart';

/// Motion primitives for the marketing site.
///
/// The app's [AppMotion] vocabulary is built for a phone: short, decelerating,
/// never longer than 380ms, because a tap should feel instant. A scrolling
/// marketing page has the opposite constraint — a section entering the
/// viewport needs long enough to read as a deliberate arrival rather than a
/// flicker — so the durations here are the app's curves at a longer scale.
///
/// Both widgets below collapse to their final state when the viewer has asked
/// for reduced motion, so nothing depends on an animation having played.
class WebMotion {
  const WebMotion._();

  /// The site's easing, from `better-ui`: cubic-bezier(0.2, 0, 0, 1). A sharp
  /// start and a long settle. It is not Material's easeOutCubic and not
  /// cubic-bezier(0.4, 0, 0.2, 1) — those read softer and less deliberate at
  /// the sizes this page animates.
  static const Curve enter = Cubic(0.2, 0, 0, 1);

  /// Press feedback. Instant by the standard of anything else here.
  static const Duration press = Duration(milliseconds: 100);

  /// Hover and colour changes. `baseline-ui` caps interaction feedback at
  /// 200ms; past that a hover state feels like it is catching up with you.
  static const Duration hover = Duration(milliseconds: 160);

  /// A section arriving in the viewport. Long because it travels, and because
  /// it happens once.
  static const Duration reveal = Duration(milliseconds: 640);

  /// Between staggered siblings. `better-ui` puts an infrequent staged
  /// entrance at ~100ms per chunk.
  static const Duration stagger = Duration(milliseconds: 100);

  /// The exact press scale from `better-ui`. Not 0.95, which reads
  /// exaggerated, and not 0.98, which is invisible.
  static const double pressScale = 0.96;
}

/// Fades and lifts [child] into place the first time it scrolls into view.
///
/// Purpose (R-19): the page is long and its sections carry different kinds of
/// content. Revealing each one on arrival gives the reader a beat to register
/// where they are, and the stagger inside a section establishes its reading
/// order. It fires **once** — scrolling back up does not replay it, because a
/// re-run would be decoration rather than orientation.
class RevealOnScroll extends StatefulWidget {
  const RevealOnScroll({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 28,
    this.triggerFraction = 0.88,
  });

  final Widget child;

  /// Stagger offset when several reveals share a section.
  final Duration delay;

  /// How far below its resting place the child starts, in logical pixels.
  final double offset;

  /// Fraction of the viewport height the child's top edge must cross before
  /// it reveals. 0.88 fires when roughly the top eighth of the element is
  /// visible, which lands the motion before the reader's eye arrives.
  final double triggerFraction;

  @override
  State<RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<RevealOnScroll> {
  bool _revealed = false;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Reduced motion: skip the animation entirely rather than shortening it.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _revealed = true;
      return;
    }

    final newPosition = Scrollable.maybeOf(context)?.position;
    if (identical(newPosition, _position)) return;
    _position?.removeListener(_check);
    _position = newPosition?..addListener(_check);

    // An element already above the fold must reveal on its own, since no
    // scroll will ever fire for it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_revealed || !mounted) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final viewportHeight = MediaQuery.sizeOf(context).height;
    final topY = box.localToGlobal(Offset.zero).dy;

    if (topY < viewportHeight * widget.triggerFraction) {
      _position?.removeListener(_check);
      if (widget.delay == Duration.zero) {
        setState(() => _revealed = true);
      } else {
        Future<void>.delayed(widget.delay, () {
          if (mounted) setState(() => _revealed = true);
        });
      }
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Driven by an explicit tween rather than AnimatedSlide, whose offset is a
    // fraction of the child's own size — that would make a tall section travel
    // several hundred pixels while a short card barely moves.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _revealed ? 1 : 0),
      duration: WebMotion.reveal,
      curve: WebMotion.enter,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, (1 - t) * widget.offset),
        child: Opacity(opacity: t, child: child),
      ),
      child: widget.child,
    );
  }
}

/// Lifts [child] on pointer hover and presses it back down on tap.
///
/// Purpose (R-19): on a pointer device, lift is the only affordance that says
/// "this responds". The app communicates the same thing through its
/// neumorphic press state; this is that state translated to a cursor.
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.onTap,
    this.lift = 4,
    this.scale = 1.0,
    this.cursor = SystemMouseCursors.click,
    this.builder,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Pixels the surface rises. Kept inside the 2–6px band — past that the
  /// element reads as detaching from the page rather than responding to you.
  final double lift;

  /// Optional scale on hover, for elements too small for lift alone to read.
  final double scale;

  final MouseCursor cursor;

  /// Lets a caller restyle its own surface while hovered (a border tint, a
  /// deeper shadow) instead of only moving it.
  final Widget Function(BuildContext context, bool hovered, Widget child)?
  builder;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final lifted = _hovered && !_pressed && !reduced;

    Widget content =
        widget.builder?.call(context, _hovered, widget.child) ?? widget.child;

    content = AnimatedScale(
      scale: _pressed ? WebMotion.pressScale : (lifted ? widget.scale : 1.0),
      duration: _pressed ? WebMotion.press : WebMotion.hover,
      curve: WebMotion.enter,
      child: content,
    );

    // Pixel translation, not AnimatedSlide's size-relative offset: a 4px lift
    // must be 4px on a 60px button and on a 400px card alike.
    content = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: lifted ? 1 : 0),
      duration: WebMotion.hover,
      curve: WebMotion.enter,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, -widget.lift * t),
        child: child,
      ),
      child: content,
    );

    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : widget.cursor,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTapCancel: widget.onTap == null
            ? null
            : () => setState(() => _pressed = false),
        child: content,
      ),
    );
  }
}

/// Calls [onVisible] once, the first time [child] scrolls far enough into
/// view — the trigger for the page's two explanatory sequences (the flight
/// diagram and the home-screen drop). Same threshold and same fire-once rule
/// as [RevealOnScroll], so a sequence never starts off-screen and never
/// replays on its own.
class PlayWhenVisible extends StatefulWidget {
  const PlayWhenVisible({
    super.key,
    required this.child,
    required this.onVisible,
    this.triggerFraction = 0.8,
  });

  final Widget child;
  final VoidCallback onVisible;
  final double triggerFraction;

  @override
  State<PlayWhenVisible> createState() => _PlayWhenVisibleState();
}

class _PlayWhenVisibleState extends State<PlayWhenVisible> {
  bool _fired = false;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newPosition = Scrollable.maybeOf(context)?.position;
    if (identical(newPosition, _position)) return;
    _position?.removeListener(_check);
    _position = newPosition?..addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_fired || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < MediaQuery.sizeOf(context).height * widget.triggerFraction) {
      _fired = true;
      _position?.removeListener(_check);
      widget.onVisible();
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
