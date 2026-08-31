import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'neu_surface.dart';

/// The one back button.
///
/// Every screen that can be backed out of uses this, so the control the user
/// reaches for most sits at the same size, in the same place, with the same
/// depth on every screen. Before this existed the app carried six different
/// back buttons — flat bordered squares, bare [IconButton]s, a scrim circle
/// over the product hero — which made the same gesture look like a different
/// affordance depending on where you had navigated from.
///
/// The dimensions are deliberately fixed rather than parameterised. A back
/// button that can be resized per screen is a back button that will be.
class NeuBackButton extends StatelessWidget {
  const NeuBackButton({
    super.key,
    this.onPressed,
    this.tooltip = 'Back',
    this.fallbackRoute,
    this.color,
    this.iconColor,
  });

  /// Visual diameter. [NeuIconButton] still guarantees a 44pt tap target.
  static const double diameter = 42;

  /// Chevron size. Small relative to the button — the raised surface is what
  /// signals "tap here", the glyph only says which way.
  static const double glyphSize = 16;

  static const IconData glyph = Icons.arrow_back_ios_new_rounded;

  /// Overrides the default pop. Use for screens that need to land somewhere
  /// specific rather than unwind the stack.
  final VoidCallback? onPressed;

  final String tooltip;

  /// Where to go when there is nothing to pop.
  ///
  /// A screen reached with `context.go` replaces the stack rather than adding
  /// to it, so `pop` has nothing to undo and the button does nothing at all.
  /// Give those screens the route that should count as "back".
  final String? fallbackRoute;

  /// Pins the surface and glyph colours. Only needed where the surrounding
  /// page does not follow the app theme — the admin screens hardcode a dark
  /// background, so a theme-resolved button turns white on them in light mode.
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return NeuIconButton(
      icon: glyph,
      iconSize: glyphSize,
      size: diameter,
      tooltip: tooltip,
      color: color,
      iconColor: iconColor,
      onPressed: onPressed ?? () => _pop(context, fallbackRoute),
    );
  }

  static void _pop(BuildContext context, String? fallback) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    if (fallback != null) {
      context.go(fallback);
      return;
    }
    Navigator.maybePop(context);
  }
}
