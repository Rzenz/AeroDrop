import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_theme.dart';

// NeuDepth is part of this file's public surface in practice — every caller
// that builds a NeuSurface needs it, so re-export it rather than making each
// one import the shadow tokens too.
export '../theme/app_shadows.dart' show NeuDepth;

/// How a neumorphic surface sits relative to the material behind it.
enum NeuStyle {
  /// Embossed out of the canvas. The default for cards and buttons.
  raised,

  /// Debossed into the canvas. Inputs, switch tracks, pressed buttons,
  /// progress rails.
  inset,

  /// Same fill, no depth. For grouping without adding visual weight.
  flat,
}

/// The single neumorphic surface primitive.
///
/// Everything with depth in the app is built from this so the light source
/// stays consistent. The fill defaults to the canvas colour, which is what
/// makes the soft-shadow illusion work — passing a contrasting [color] will
/// break the effect and should be reserved for accent surfaces.
class NeuSurface extends StatelessWidget {
  const NeuSurface({
    super.key,
    required this.child,
    this.style = NeuStyle.raised,
    this.depth = NeuDepth.low,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.gradient,
    this.border,
    this.width,
    this.height,
    this.alignment,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final NeuStyle style;
  final NeuDepth depth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final Gradient? gradient;
  final BoxBorder? border;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadii.brLg;
    final fill = color ?? AppColors.base;
    final isInset = style == NeuStyle.inset;

    Widget inner = child;
    if (padding != null) inner = Padding(padding: padding!, child: inner);
    if (isInset && alignment != null) {
      inner = Align(alignment: alignment!, child: inner);
    }

    if (isInset) {
      // Paint order matters: the container's fill lands first, then the inner
      // shadow over it, then the content. Using CustomPaint's `painter` slot
      // instead would bury the shadow underneath the opaque fill.
      inner = Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _InnerShadowPainter(
                  radius: radius,
                  distance: _insetDistance(depth),
                  lightColor: AppColors.neuLight,
                  shadowColor: AppColors.neuShadow,
                  isDark: AppTheme.isDarkMode,
                ),
              ),
            ),
          ),
          inner,
        ],
      );
    }

    Widget content = Container(
      width: width,
      height: height,
      alignment: isInset ? null : alignment,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: gradient == null ? fill : null,
        gradient: gradient,
        borderRadius: radius,
        border: border,
        boxShadow: style == NeuStyle.raised ? AppShadows.raised(depth) : null,
      ),
      child: inner,
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }
    return content;
  }

  static double _insetDistance(NeuDepth depth) => switch (depth) {
    NeuDepth.flat => 2,
    NeuDepth.low => 3,
    NeuDepth.medium => 4,
    NeuDepth.high => 6,
  };
}

/// A tappable neumorphic surface that presses *into* the canvas.
///
/// The raised→inset transition is the core micro-interaction of the design
/// system: it reads as physically pushing the control, which is what makes a
/// shadow-only button legible as a button.
class NeuPressable extends StatefulWidget {
  const NeuPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.depth = NeuDepth.low,
    this.padding,
    this.borderRadius,
    this.color,
    this.gradient,
    this.border,
    this.width,
    this.height,
    this.alignment,
    this.enabled = true,
    this.scaleOnPress = 0.985,
    this.haptic = true,
    this.semanticLabel,
    this.debounce = const Duration(milliseconds: 350),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final NeuDepth depth;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? color;
  final Gradient? gradient;
  final BoxBorder? border;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final bool enabled;
  final double scaleOnPress;
  final bool haptic;
  final String? semanticLabel;

  /// Guards against double-fire on rapid taps. Matches the debounce the
  /// original cards used.
  final Duration debounce;

  @override
  State<NeuPressable> createState() => _NeuPressableState();
}

class _NeuPressableState extends State<NeuPressable> {
  bool _pressed = false;
  DateTime? _lastTap;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _setPressed(bool value) {
    if (!_interactive || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    if (!_interactive || widget.onTap == null) return;
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < widget.debounce) return;
    _lastTap = now;
    if (widget.haptic) HapticFeedback.lightImpact();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? AppRadii.brLg;

    Widget surface = AnimatedScale(
      scale: _pressed ? widget.scaleOnPress : 1.0,
      duration: AppMotion.instant,
      curve: AppMotion.standard,
      child: NeuSurface(
        style: _pressed
            ? NeuStyle.inset
            : (widget.enabled ? NeuStyle.raised : NeuStyle.flat),
        depth: widget.depth,
        padding: widget.padding,
        borderRadius: radius,
        color: widget.color,
        gradient: widget.gradient,
        border: widget.border,
        width: widget.width,
        height: widget.height,
        alignment: widget.alignment,
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1 : 0.45,
          duration: AppMotion.fast,
          child: widget.child,
        ),
      ),
    );

    if (!_interactive) {
      return widget.semanticLabel == null
          ? surface
          : Semantics(label: widget.semanticLabel, child: surface);
    }

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _handleTap,
        onLongPress: widget.onLongPress,
        child: surface,
      ),
    );
  }
}

/// A circular neumorphic icon button. Used for app-bar actions, steppers and
/// any compact control.
class NeuIconButton extends StatelessWidget {
  const NeuIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.iconSize = 20,
    this.color,
    this.iconColor,
    this.depth = NeuDepth.low,
    this.tooltip,
    this.badgeCount,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? iconColor;
  final NeuDepth depth;
  final String? tooltip;

  /// Optional unread/count badge rendered on the top-right.
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    // Never let the tap target fall below the 44pt accessibility minimum even
    // if a caller asks for a smaller visual size.
    final tapSize = math.max(size, 44.0);

    Widget button = NeuPressable(
      onTap: onPressed,
      enabled: onPressed != null,
      depth: depth,
      color: color,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
      alignment: Alignment.center,
      semanticLabel: tooltip,
      child: Icon(
        icon,
        size: iconSize,
        color: iconColor ?? AppColors.textPrimary,
      ),
    );

    if (badgeCount != null && badgeCount! > 0) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: AppRadii.brPill,
                border: Border.all(color: AppColors.base, width: 2),
              ),
              child: Center(
                child: Text(
                  badgeCount! > 99 ? '99+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final sized = SizedBox(
      width: tapSize,
      height: tapSize,
      child: Center(child: button),
    );

    return tooltip == null ? sized : Tooltip(message: tooltip!, child: sized);
  }
}

/// Paints the two inner shadows that make a surface read as debossed.
///
/// Technique: clip to the shape, then stroke the shape offset in each shadow's
/// direction with a blurred paint. The outer half of the stroke is clipped
/// away, leaving a soft gradient on the inside edge.
class _InnerShadowPainter extends CustomPainter {
  _InnerShadowPainter({
    required this.radius,
    required this.distance,
    required this.lightColor,
    required this.shadowColor,
    required this.isDark,
  });

  final BorderRadius radius;
  final double distance;
  final Color lightColor;
  final Color shadowColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rrect = radius.toRRect(Offset.zero & size);
    final strokeWidth = distance * 2.5;
    final blur = distance * 1.6;

    canvas.save();
    canvas.clipRRect(rrect);

    // Dark shadow on the top-left inside edge (light source is top-left, so an
    // inset well is occluded there).
    _stroke(
      canvas,
      rrect,
      Offset(distance, distance),
      shadowColor.withValues(alpha: isDark ? 0.75 : 0.85),
      strokeWidth,
      blur,
    );

    // Light bounce on the bottom-right inside edge.
    _stroke(
      canvas,
      rrect,
      Offset(-distance, -distance),
      lightColor.withValues(alpha: isDark ? 0.5 : 0.9),
      strokeWidth,
      blur,
    );

    canvas.restore();
  }

  void _stroke(
    Canvas canvas,
    RRect rrect,
    Offset offset,
    Color color,
    double strokeWidth,
    double blur,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawRRect(rrect.shift(offset), paint);
  }

  @override
  bool shouldRepaint(covariant _InnerShadowPainter old) =>
      old.radius != radius ||
      old.distance != distance ||
      old.lightColor != lightColor ||
      old.shadowColor != shadowColor ||
      old.isDark != isDark;
}
