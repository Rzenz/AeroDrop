import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import 'neu_surface.dart';

/// The default content card.
///
/// Sits on the canvas as a softly embossed surface. When [onTap] is supplied it
/// presses into the canvas, which is how a shadow-only card announces that it
/// is interactive.
class NeuCard extends StatelessWidget {
  const NeuCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
    this.depth = NeuDepth.low,
    this.color,
    this.accent,
    this.boxShadow,
    this.width,
    this.height,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final NeuDepth depth;
  final Color? color;

  /// Optional semantic rim — status colour, vendor brand colour. Drawn as a
  /// restrained hairline rather than a glow so it reads as information.
  final Color? accent;

  /// Escape hatch for a caller that needs a specific shadow. Overrides the
  /// neumorphic pair; use sparingly.
  final List<BoxShadow>? boxShadow;

  final double? width;
  final double? height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadii.brLg;
    final pad = padding ?? AppSpacing.allLg;
    final border = accent == null
        ? null
        : Border.all(color: accent!.withValues(alpha: 0.35), width: 1.2);

    Widget card;
    if (onTap != null) {
      card = NeuPressable(
        onTap: onTap,
        depth: depth,
        padding: pad,
        borderRadius: radius,
        color: color,
        border: border,
        width: width,
        height: height,
        semanticLabel: semanticLabel,
        child: child,
      );
    } else if (boxShadow != null) {
      card = Container(
        width: width,
        height: height,
        padding: pad,
        decoration: BoxDecoration(
          color: color ?? AppColors.base,
          borderRadius: radius,
          border: border,
          boxShadow: boxShadow,
        ),
        child: child,
      );
    } else {
      card = NeuSurface(
        depth: depth,
        padding: pad,
        borderRadius: radius,
        color: color,
        border: border,
        width: width,
        height: height,
        child: child,
      );
    }

    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}

/// A card layered *on top of* another surface.
///
/// Uses the raised fill rather than the canvas fill, because a neumorphic
/// emboss only works against the colour it was cut from — stacking two
/// canvas-coloured cards makes both disappear.
class NeuPanel extends StatelessWidget {
  const NeuPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.onTap,
    this.accent,
    this.boxShadow,
    this.depth = NeuDepth.flat,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Color? accent;
  final List<BoxShadow>? boxShadow;
  final NeuDepth depth;

  @override
  Widget build(BuildContext context) => NeuCard(
    padding: padding ?? AppSpacing.allMd,
    borderRadius: borderRadius ?? AppRadii.brMd,
    onTap: onTap,
    accent: accent,
    boxShadow: boxShadow,
    depth: depth,
    color: AppColors.surfaceRaised,
    child: child,
  );
}

/// A card that carries a semantic colour — the active delivery, an alert, the
/// selected payment method.
///
/// The tint is deliberately weak (6%): enough to read as "this one is
/// different", not enough to become a coloured slab. This is the only card
/// variant allowed to use a coloured shadow, and only at [NeuDepth.medium].
class NeuAccentCard extends StatelessWidget {
  const NeuAccentCard({
    super.key,
    required this.child,
    this.padding,
    this.glowColor = AppColors.primary,
    this.borderRadius,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color glowColor;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadii.brLg;
    final pad = padding ?? AppSpacing.allLg;
    final fill = Color.alphaBlend(
      glowColor.withValues(alpha: 0.06),
      AppColors.base,
    );
    final border = Border.all(
      color: glowColor.withValues(alpha: 0.30),
      width: 1.2,
    );

    if (onTap != null) {
      return NeuPressable(
        onTap: onTap,
        depth: NeuDepth.medium,
        padding: pad,
        borderRadius: radius,
        color: fill,
        border: border,
        child: child,
      );
    }

    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: border,
        boxShadow: [
          ...AppShadows.raised(NeuDepth.medium),
          ...AppShadows.glow(glowColor, alpha: 0.16),
        ],
      ),
      child: child,
    );
  }
}

/// A card that fades and rises into place.
///
/// Kept separate from [NeuCard] so that static content pays nothing for an
/// animation it does not use. [index] staggers items within a list.
class NeuCardEntrance extends StatelessWidget {
  const NeuCardEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.enabled = true,
  });

  final Widget child;
  final int index;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Honour the OS "reduce motion" setting — an entrance animation is
    // decoration, and decoration is exactly what that setting is for.
    if (!enabled || MediaQuery.disableAnimationsOf(context)) return child;

    return _FadeSlideIn(delay: AppMotion.staggerFor(index), child: child);
  }
}

class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: AppMotion.enter,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _a,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(_a),
      child: widget.child,
    ),
  );
}
