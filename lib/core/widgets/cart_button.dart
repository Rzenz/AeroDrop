import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../../mock_data/cart_mock.dart';
import 'neu_surface.dart';

/// Where an item should fly to when it is added.
///
/// Every mounted [NeuCartButton] registers itself here and drops out on
/// dispose. A single shared key would throw the moment two screens overlap
/// during a route transition, which is exactly when someone taps "Add".
class CartAnchor {
  const CartAnchor._();

  static final List<GlobalKey> _keys = [];

  static void _register(GlobalKey key) => _keys.add(key);
  static void _unregister(GlobalKey key) => _keys.remove(key);

  /// The most recently mounted cart, in global coordinates. Null when no cart
  /// is on screen — the caller should then skip the flight rather than guess.
  static Rect? rect() {
    for (final key in _keys.reversed) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) continue;
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return null;
  }
}

/// The cart, wherever it appears in a header.
///
/// Replaces three hand-rolled versions that had drifted apart — one on a black
/// scrim, one bare, all three with a different badge. Raised and debossed like
/// every other control, and it bumps when the count goes up so the result of
/// an add is visible even if the flight was missed.
class NeuCartButton extends StatefulWidget {
  const NeuCartButton({super.key, required this.onPressed, this.size = 42});

  final VoidCallback onPressed;
  final double size;

  @override
  State<NeuCartButton> createState() => _NeuCartButtonState();
}

class _NeuCartButtonState extends State<NeuCartButton>
    with SingleTickerProviderStateMixin {
  final _anchorKey = GlobalKey();
  late final AnimationController _bump;
  int _count = cartNotifier.totalItems;

  @override
  void initState() {
    super.initState();
    _bump = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    cartNotifier.addListener(_onCart);
    CartAnchor._register(_anchorKey);
  }

  @override
  void dispose() {
    CartAnchor._unregister(_anchorKey);
    cartNotifier.removeListener(_onCart);
    _bump.dispose();
    super.dispose();
  }

  void _onCart() {
    final next = cartNotifier.totalItems;
    final grew = next > _count;
    _count = next;
    if (!mounted) return;
    setState(() {});
    // Only on the way up. Bumping when an item is removed would celebrate the
    // wrong thing.
    if (grew) _bump.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bump,
      builder: (context, child) {
        // Out and back on one curve: a single overshoot, not a bounce.
        final t = math.sin(_bump.value * math.pi);
        return Transform.scale(
          scale: 1 + 0.16 * Curves.easeOutCubic.transform(t),
          child: child,
        );
      },
      child: KeyedSubtree(
        key: _anchorKey,
        child: NeuIconButton(
          icon: Icons.shopping_cart_rounded,
          iconSize: 19,
          size: widget.size,
          tooltip: 'Cart',
          badgeCount: _count,
          onPressed: widget.onPressed,
        ),
      ),
    );
  }
}

/// Sends a thumbnail arcing from [from] into the cart.
///
/// Feedback and spatial consistency in one move: it confirms the tap landed
/// and shows where the thing went, which is the whole reason the cart count
/// changing on its own is not enough.
///
/// [onArrive] fires when the puck lands, so a confirmation reads as the
/// result of the flight rather than as a second thing happening at the same
/// time. When the flight cannot run — no cart on screen, or reduced motion —
/// it fires immediately instead, so the caller's feedback is never lost.
///
/// [announce] is for callers that show nothing else; skip it when [onArrive]
/// raises a toast, or a screen reader hears the same sentence twice.
void flyToCart(
  BuildContext context, {
  required Rect from,
  required Widget thumbnail,
  String? announce,
  VoidCallback? onArrive,
}) {
  if (announce != null) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      announce,
      Directionality.of(context),
    );
  }

  HapticFeedback.mediumImpact();

  final to = CartAnchor.rect();
  final overlay = Overlay.maybeOf(context, rootOverlay: true);

  if (to == null ||
      overlay == null ||
      MediaQuery.disableAnimationsOf(context)) {
    onArrive?.call();
    return;
  }

  late OverlayEntry entry;
  entry = OverlayEntry(
    // Positioned.fill at the top level: the overlay lays its entries out in a
    // Stack, and anything wrapped around a Positioned before it reaches that
    // Stack silently drops the geometry and the puck renders full-bleed.
    builder: (_) => Positioned.fill(
      child: IgnorePointer(
        child: _Flight(
          from: from,
          to: to,
          thumbnail: thumbnail,
          onDone: () {
            entry.remove();
            onArrive?.call();
          },
        ),
      ),
    ),
  );
  overlay.insert(entry);
}

class _Flight extends StatefulWidget {
  const _Flight({
    required this.from,
    required this.to,
    required this.thumbnail,
    required this.onDone,
  });

  final Rect from;
  final Rect to;
  final Widget thumbnail;
  final VoidCallback onDone;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  /// Long enough to follow across a phone, short enough not to hold the user
  /// up: they can tap again before it lands and the second flight just starts.
  static const _duration = Duration(milliseconds: 520);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.from.center;
    final end = widget.to.center;

    // Arcs up and over rather than cutting straight across. A straight line
    // between two points on a screen reads as a glitch; the curve reads as a
    // thing being tossed.
    final control = Offset(
      start.dx + (end.dx - start.dx) * 0.35,
      math.min(start.dy, end.dy) - (start.dy - end.dy).abs() * 0.35 - 60,
    );

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOutCubic.transform(_c.value);
        final inv = 1 - t;

        final pos =
            start * (inv * inv) + control * (2 * inv * t) + end * (t * t);

        // Shrinks toward the cart, and only fades at the very end so it does
        // not vanish mid-flight and leave the eye nowhere to land.
        final scale = 1 - 0.66 * t;
        final opacity = t < 0.82 ? 1.0 : (1 - (t - 0.82) / 0.18);

        return Stack(
          children: [
            Positioned(
              left: pos.dx - widget.from.width / 2,
              top: pos.dy - widget.from.height / 2,
              width: widget.from.width,
              height: widget.from.height,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Transform.rotate(angle: t * 0.5, child: child),
                ),
              ),
            ),
          ],
        );
      },
      child: _Puck(child: widget.thumbnail),
    );
  }
}

/// The thing in flight: the product, on a raised tile so it reads as a token
/// lifted off the page rather than a floating cut-out.
class _Puck extends StatelessWidget {
  const _Puck({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadii.brMd,
        color: AppColors.surfaceRaised,
        boxShadow: [
          ...AppShadows.raised(NeuDepth.medium),
          ...AppShadows.glow(AppColors.accentFill, alpha: 0.22),
        ],
      ),
      child: ClipRRect(borderRadius: AppRadii.brMd, child: child),
    );
  }
}
