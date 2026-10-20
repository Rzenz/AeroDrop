import 'package:flutter/material.dart';

import '../theme/app_shadows.dart';

/// An input border that presses the field into the canvas.
///
/// A text field in a neumorphic system is a well. Drawing the well as the
/// field's *border* — rather than wrapping the field in a debossed box —
/// keeps the helper and error text outside it, under the well where they
/// belong, and lets the decorator animate between states as usual.
///
/// [borderSide] still draws on top when it has a colour: pass the accent for
/// the focused state, so keyboard focus is visible (soft shadows alone do not
/// show it), and the danger tone for an error.
class NeuInsetInputBorder extends OutlineInputBorder {
  const NeuInsetInputBorder({
    super.borderSide = BorderSide.none,
    super.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.palette,
    this.distance = 3,
  });

  /// Fixed palette; the app theme's when null.
  final NeuPalette? palette;

  /// How deep the well reads.
  final double distance;

  @override
  NeuInsetInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) => NeuInsetInputBorder(
    borderSide: borderSide ?? this.borderSide,
    borderRadius: borderRadius ?? this.borderRadius,
    palette: palette,
    distance: distance,
  );

  // The decorator tweens between the enabled and focused borders. Without
  // these the in-between frames fall back to a plain outline and the well
  // flickers flat for the length of the tween.
  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is NeuInsetInputBorder) {
      return NeuInsetInputBorder(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
        palette: palette,
        distance: distance,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is NeuInsetInputBorder) {
      return NeuInsetInputBorder(
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        borderRadius: BorderRadius.lerp(borderRadius, b.borderRadius, t)!,
        palette: palette,
        distance: distance,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    final p = palette ?? NeuPalette.current;
    final rrect = borderRadius.toRRect(rect);
    final stroke = distance * 2.5;
    final blur = distance * 1.6;

    canvas.save();
    canvas.clipRRect(rrect);
    // Light from the top-left: the well's top-left inside edge is in shade,
    // its bottom-right catches a little light.
    _edge(
      canvas,
      rrect.shift(Offset(distance, distance)),
      p.shadow.withValues(alpha: p.dark ? 0.75 : 0.85),
      stroke,
      blur,
    );
    _edge(
      canvas,
      rrect.shift(Offset(-distance, -distance)),
      p.light.withValues(alpha: p.dark ? 0.5 : 0.9),
      stroke,
      blur,
    );
    canvas.restore();

    if (borderSide.style != BorderStyle.none &&
        borderSide.width > 0 &&
        borderSide.color.a > 0) {
      canvas.drawRRect(
        rrect.deflate(borderSide.width / 2),
        borderSide.toPaint(),
      );
    }
  }

  void _edge(
    Canvas canvas,
    RRect rrect,
    Color color,
    double width,
    double blur,
  ) {
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NeuInsetInputBorder &&
      other.borderSide == borderSide &&
      other.borderRadius == borderRadius &&
      other.palette == palette &&
      other.distance == distance;

  @override
  int get hashCode => Object.hash(borderSide, borderRadius, palette, distance);
}
