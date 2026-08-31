import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import 'neu_surface.dart';

/// One button in a [NeuActionFan].
class NeuFanAction {
  const NeuFanAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.destructive = false,
  });

  final IconData icon;

  /// Kept short. It sits under a 52pt circle and wraps to two lines at most.
  final String label;

  final VoidCallback onTap;

  /// Marks the destination the user is currently on.
  final bool active;

  /// Tints the button as destructive — sign out, delete.
  final bool destructive;
}

/// Extra destinations that arc out of the dock's centre button.
///
/// The dock can only hold four destinations and their labels. This is where
/// the rest go: they fan up out of the middle, in the open, with their names
/// attached — which is a different proposition from a drawer, where nine
/// destinations are equally hidden and equally two taps away.
///
/// Drive [progress] from a controller the toggle owns: 0 closed, 1 open.
class NeuActionFan extends StatelessWidget {
  const NeuActionFan({
    super.key,
    required this.progress,
    required this.actions,
    required this.onDismiss,
    this.bottomInset = 0,
  });

  final Animation<double> progress;
  final List<NeuFanAction> actions;

  /// Called when the scrim is tapped.
  final VoidCallback onDismiss;

  /// How far the dock rises off the bottom of this widget's box. The buttons
  /// are measured from the dock's top edge, not the screen's, or the lowest
  /// pair ends up behind the bar with their labels swallowed. The scrim still
  /// covers the full box.
  final double bottomInset;

  /// Total height the fan needs above the dock.
  static const double height = 232;

  /// Clearance between the dock's top edge and the lowest button. Small on
  /// purpose: the buttons came out of the dock, so a wide gap makes them look
  /// like they belong to something else.
  static const double _baseGap = 10;

  /// Base for the lowest row when the fan stacks. Higher than [_baseGap]
  /// because a stacked row runs straight across the middle, where the dock's
  /// centre action is already sticking up out of the bar.
  static const double _rowBase = 46;

  static const double _circle = 52;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value;
        return IgnorePointer(
          ignoring: t < 0.02,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Dims the page under the fan so six bright circles are not
              // competing with a full screen of admin data behind them.
              Opacity(
                opacity: t,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDismiss,
                  child: const ColoredBox(color: Color(0xB3000000)),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomInset,
                height: height,
                child: _Arc(progress: progress, actions: actions),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Arc extends StatelessWidget {
  const _Arc({required this.progress, required this.actions});

  final Animation<double> progress;
  final List<NeuFanAction> actions;

  /// Below this much width per button the row cannot hold them without the
  /// circles touching, so the fan breaks into two.
  static const double _minSlot = 60;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.isEmpty) return const SizedBox.shrink();

        final n = actions.length;
        final usable = size.width - 16;
        final twoRows = usable / n < _minSlot;
        final perRow = twoRows ? (n / 2).ceil() : n;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < n; i++)
              _place(i, n, perRow, twoRows, usable, size.width),
          ],
        );
      },
    );
  }

  Widget _place(
    int i,
    int n,
    int perRow,
    bool twoRows,
    double usable,
    double width,
  ) {
    // Lower row first, so the fan builds upward from the button that opened
    // it rather than starting at the far edge of the screen.
    final row = i < perRow ? 0 : 1;
    final inRow = row == 0 ? i : i - perRow;
    final rowCount = row == 0 ? perRow : n - perRow;

    final slot = usable / rowCount;
    final itemW = math.min(slot, 84.0);
    final cx = width / 2;

    // Spread evenly by distance, not by angle. Equal angles on a circle bunch
    // the outermost buttons together once there are more than about four, and
    // at six they overlap.
    final f = rowCount == 1 ? 0.5 : inRow / (rowCount - 1);
    final dx = (f - 0.5) * slot * (rowCount - 1);

    // The row still curves: an ellipse over the spread, flattened enough that
    // the ends stay clear of the dock.
    final norm = rowCount == 1 ? 0.0 : (f - 0.5) * 2 / 1.14;
    final curve = math.sqrt(math.max(0, 1 - norm * norm));

    final lift = twoRows
        ? NeuActionFan._rowBase + row * 88 + 14 * curve
        : NeuActionFan._baseGap + 96 * curve;

    final start = (i * 0.07).clamp(0.0, 0.4);
    final curved = CurvedAnimation(
      parent: progress,
      curve: Interval(
        start,
        math.min(start + 0.6, 1.0),
        curve: AppMotion.spring,
      ),
      // Same intervals in reverse, so the outermost button collapses first —
      // the fan closes the way it opened, backwards.
      reverseCurve: Interval(
        start,
        math.min(start + 0.6, 1.0),
        curve: AppMotion.exit,
      ),
    );

    return Positioned(
      left: cx + dx - itemW / 2,
      bottom: 0,
      width: itemW,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) {
          final t = curved.value;
          return Transform.translate(
            // Travels out of the dock's centre, not in from nowhere: each
            // button appears to come from the control that summoned it.
            offset: Offset(-dx * (1 - t), -lift * t),
            child: Transform.scale(
              scale: 0.4 + 0.6 * t,
              child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
            ),
          );
        },
        child: _FanButton(action: actions[i]),
      ),
    );
  }
}

class _FanButton extends StatelessWidget {
  const _FanButton({required this.action});

  final NeuFanAction action;

  @override
  Widget build(BuildContext context) {
    final tint = action.destructive
        ? AppColors.danger
        : (action.active ? AppColors.accentFill : AppColors.base);
    final fg = action.destructive
        ? Colors.white
        : (action.active ? AppColors.onAccentFill : AppColors.textPrimary);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeuPressable(
          onTap: () {
            HapticFeedback.lightImpact();
            action.onTap();
          },
          width: NeuActionFan._circle,
          height: NeuActionFan._circle,
          borderRadius: BorderRadius.circular(NeuActionFan._circle / 2),
          alignment: Alignment.center,
          color: tint,
          depth: NeuDepth.medium,
          semanticLabel: action.label,
          child: Icon(action.icon, size: 22, color: fg),
        ),
        const SizedBox(height: 6),
        Text(
          action.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.label(
            fontSize: 10.5,
            letterSpacing: 0,
            color: action.destructive
                ? AppColors.danger
                : (action.active
                      ? AppColors.accentText
                      : AppColors.textSecondary),
            fontWeight: action.active ? FontWeight.w700 : FontWeight.w600,
          ).copyWith(height: 1.15),
        ),
      ],
    );
  }
}

/// The control that opens a [NeuActionFan]. Sits in the dock's notch, so it
/// matches the customer shell's cart button in size, fill and halo — the same
/// slot doing a different job, not a different-looking bar.
class NeuFanToggle extends StatefulWidget {
  const NeuFanToggle({
    super.key,
    required this.progress,
    required this.onPressed,
    this.size = 56,
    this.semanticLabel = 'More destinations',
  });

  /// 0 closed, 1 open. Drives the icon's quarter turn.
  final Animation<double> progress;

  final VoidCallback onPressed;
  final double size;
  final String semanticLabel;

  @override
  State<NeuFanToggle> createState() => _NeuFanToggleState();
}

class _NeuFanToggleState extends State<NeuFanToggle> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1,
          duration: AppMotion.instant,
          curve: AppMotion.standard,
          child: Container(
            width: s,
            height: s,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentFill,
              shape: BoxShape.circle,
              boxShadow: _pressed
                  ? null
                  : [
                      ...AppShadows.raised(NeuDepth.medium),
                      ...AppShadows.glow(AppColors.accentFill, alpha: 0.30),
                    ],
            ),
            child: AnimatedBuilder(
              animation: widget.progress,
              builder: (context, _) {
                final t = widget.progress.value;
                // Menu turns into a close mark by rotating a eighth-turn and
                // cross-fading, so the two icons share a centre and the change
                // reads as one object turning rather than two swapping.
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: 1 - t,
                      child: Transform.rotate(
                        angle: t * math.pi / 4,
                        child: Icon(
                          Icons.menu_rounded,
                          color: AppColors.onAccentFill,
                          size: s * 0.42,
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: t,
                      child: Transform.rotate(
                        angle: (t - 1) * math.pi / 4,
                        child: Icon(
                          Icons.close_rounded,
                          color: AppColors.onAccentFill,
                          size: s * 0.44,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
