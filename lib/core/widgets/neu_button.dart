import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import 'neu_surface.dart';

/// Button emphasis levels.
///
/// Only [accent] should appear once per screen — it is the single action the
/// screen is asking for. Everything else is [neutral] or [ghost].
enum NeuButtonVariant {
  /// The screen's primary call to action. The sky blue from the app icon,
  /// which carries dark content at 7:1.
  accent,

  /// Brand blue. For a strong action that is not *the* action.
  primary,

  /// The classic neumorphic button: canvas-coloured, depth-only.
  neutral,

  /// Destructive.
  danger,

  /// No surface at all — text and icon only.
  ghost,
}

/// The app's button.
///
/// Presses genuinely deboss: the raised shadow pair inverts to an inset well
/// and the surface scales down a hair. On a low-contrast neumorphic canvas
/// that press feedback is not decoration — it is the main signal that the
/// control was hit.
class NeuButton extends StatefulWidget {
  const NeuButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.leading,
    this.height = 54,
    this.variant = NeuButtonVariant.accent,
    this.expand = true,
    this.borderRadius,
    this.semanticLabel,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  /// A custom mark placed where [icon] would go — a brand logo, an avatar.
  /// Takes precedence over [icon]. Sized by the caller; keep it near 20pt so
  /// it sits on the same optical line as the label.
  final Widget? leading;

  final double height;
  final NeuButtonVariant variant;

  /// Fill the available width. Set false for inline/compact buttons.
  final bool expand;

  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _pressed = false;
  DateTime? _lastTap;

  bool get _disabled => widget.onPressed == null;
  bool get _blocked => _disabled || widget.isLoading;

  Color get _fill {
    if (_disabled) return AppColors.surfaceSunken;
    return switch (widget.variant) {
      NeuButtonVariant.accent => AppColors.accentFill,
      NeuButtonVariant.primary => AppColors.primary,
      NeuButtonVariant.danger => AppColors.danger,
      NeuButtonVariant.neutral => AppColors.base,
      NeuButtonVariant.ghost => Colors.transparent,
    };
  }

  Color get _foreground {
    if (_disabled) return AppColors.textTertiary;
    return switch (widget.variant) {
      NeuButtonVariant.accent => AppColors.onAccentFill,
      NeuButtonVariant.primary => Colors.white,
      NeuButtonVariant.danger => Colors.white,
      NeuButtonVariant.neutral => AppColors.textPrimary,
      NeuButtonVariant.ghost => AppColors.primaryText,
    };
  }

  /// Only the accent and danger CTAs get a coloured halo, and only at rest.
  List<BoxShadow>? get _shadows {
    if (widget.variant == NeuButtonVariant.ghost) return null;
    if (_disabled) return null;
    if (_pressed) return null;

    final neu = AppShadows.raised(NeuDepth.low);
    return switch (widget.variant) {
      NeuButtonVariant.accent => [
        ...neu,
        ...AppShadows.glow(AppColors.accentFill, alpha: 0.22),
      ],
      NeuButtonVariant.danger => [
        ...neu,
        ...AppShadows.glow(AppColors.danger, alpha: 0.18),
      ],
      _ => neu,
    };
  }

  void _setPressed(bool v) {
    if (_blocked || _pressed == v) return;
    setState(() => _pressed = v);
  }

  void _handleTap() {
    if (_blocked) return;
    final now = DateTime.now();
    if (_lastTap != null &&
        now.difference(_lastTap!) < const Duration(milliseconds: 350)) {
      return;
    }
    _lastTap = now;
    HapticFeedback.lightImpact();
    widget.onPressed!.call();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? AppRadii.brMd;

    // The label stays laid out while loading and is simply cross-faded with
    // the spinner, so the button never changes size mid-action.
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.leading != null) ...[
          widget.leading!,
          const SizedBox(width: 10),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 19, color: _foreground),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.title(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _foreground,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );

    final content = AnimatedSwitcher(
      duration: AppMotion.fast,
      child: widget.isLoading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(_foreground),
              ),
            )
          : KeyedSubtree(key: const ValueKey('label'), child: label),
    );

    Widget button = AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: AppMotion.instant,
      curve: AppMotion.standard,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _pressed
              // Pressing darkens the fill so filled variants read as pushed
              // even where the shadow inversion is subtle.
              ? Color.alphaBlend(Colors.black.withValues(alpha: 0.10), _fill)
              : _fill,
          borderRadius: radius,
          border: widget.variant == NeuButtonVariant.ghost
              ? null
              : (widget.variant == NeuButtonVariant.neutral && !_disabled
                    ? Border.all(color: AppColors.border, width: 1)
                    : null),
          boxShadow: _shadows,
        ),
        child: content,
      ),
    );

    // A pressed neutral button has no fill of its own to darken, so it gets a
    // real inset well instead.
    if (_pressed && widget.variant == NeuButtonVariant.neutral) {
      button = AnimatedScale(
        scale: 0.97,
        duration: AppMotion.instant,
        child: _InsetWell(
          radius: radius,
          height: widget.height,
          child: content,
        ),
      );
    }

    if (widget.expand) {
      button = SizedBox(width: double.infinity, child: button);
    }

    return Semantics(
      button: true,
      enabled: !_disabled,
      label: widget.semanticLabel ?? widget.text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _handleTap,
        child: button,
      ),
    );
  }
}

class _InsetWell extends StatelessWidget {
  const _InsetWell({
    required this.radius,
    required this.height,
    required this.child,
  });

  final BorderRadius radius;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => NeuSurface(
    style: NeuStyle.inset,
    height: height,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    borderRadius: radius,
    child: child,
  );
}
