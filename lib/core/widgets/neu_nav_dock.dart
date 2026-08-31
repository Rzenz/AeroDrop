import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// One destination in a [NeuNavDock].
class NeuNavItem {
  const NeuNavItem({required this.icon, required this.label, this.badge});

  final IconData icon;
  final String label;

  /// Outstanding count for this destination — pending deliveries, unread
  /// alerts. Null or zero hides it.
  final int? badge;
}

/// The floating navigation dock shared by the customer and vendor shells.
///
/// With a [centerAction] the bar takes a circular bite out of its own top edge
/// and the action sits in it, half above the dock. That does two things at
/// once: it gives the action the largest target on screen without stealing a
/// navigation slot, and the bite tells you the action is not a fifth tab.
///
/// Without one — the vendor shell — it stays a plain rounded bar.
class NeuNavDock extends StatelessWidget {
  const NeuNavDock({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    this.centerAction,
    this.centerActionAfterIndex = 1,
    this.height = 70,
    this.centerActionSize = 56,
    this.surfaceColor,
    this.borderColor,
    this.shadows,
    this.selectedColor,
    this.unselectedColor,
  });

  final List<NeuNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  /// Optional action dropped into the notch at the middle of the bar.
  final Widget? centerAction;

  /// Which item the notch is cut after.
  final int centerActionAfterIndex;

  /// Height of the bar itself, not counting the action's overhang.
  final double height;

  final double centerActionSize;

  /// Overrides for a host that does not follow the app theme. The admin
  /// screens hardcode a dark background, so a theme-resolved dock turns into a
  /// bright slab sitting on them the moment the app is switched to light.
  final Color? surfaceColor;
  final Color? borderColor;
  final List<BoxShadow>? shadows;
  final Color? selectedColor;
  final Color? unselectedColor;

  /// Clearance between the action and the cut edge.
  static const double _notchMargin = 6;

  /// How much of the action sits above the bar.
  double get _overhang => centerAction == null ? 0 : centerActionSize * 0.56;

  double get _notchRadius => centerActionSize / 2 + _notchMargin;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final notched = centerAction != null;
        final gap = notched ? _notchRadius * 2 + 8 : 0.0;

        // Below ~44pt a 10pt label truncates to nonsense, so drop to icons
        // only and let the semantics layer carry the name.
        final perItem = (width - 12 - gap) / items.length;
        final showLabels = perItem >= 44;

        final row = <Widget>[];
        for (var i = 0; i < items.length; i++) {
          row.add(
            Expanded(
              child: _DockItem(
                item: items[i],
                selected: selectedIndex == i,
                showLabel: showLabels,
                onTap: () => onTap(i),
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
                badgeRing: surfaceColor,
              ),
            ),
          );
          if (notched && i == centerActionAfterIndex) {
            row.add(SizedBox(width: gap));
          }
        }

        final bar = SizedBox(
          height: height,
          child: Stack(
            children: [
              // Three passes, because one CustomPaint cannot do all of it: the
              // shadow must fall outside the shape, the blur must be clipped
              // to it, and the rim must sit over both.
              Positioned.fill(
                child: CustomPaint(
                  painter: _DockShadowPainter(
                    notchCenter: notched ? width / 2 : null,
                    notchRadius: _notchRadius,
                    shadows: shadows ?? AppShadows.floating,
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipPath(
                  clipper: _DockClipper(
                    notchCenter: notched ? width / 2 : null,
                    notchRadius: _notchRadius,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: ColoredBox(
                      // Translucent, not opaque. The dock floats over the page
                      // and should read that way — and when something dims the
                      // page behind it, the dock dims with it instead of
                      // staying lit like a panel that forgot.
                      color: (surfaceColor ?? AppColors.base).withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _DockRimPainter(
                    notchCenter: notched ? width / 2 : null,
                    notchRadius: _notchRadius,
                    color: borderColor ?? AppColors.border,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(children: row),
              ),
            ],
          ),
        );

        if (!notched) return bar;

        return SizedBox(
          height: height + _overhang,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(left: 0, right: 0, bottom: 0, child: bar),
              Positioned(top: 0, child: centerAction!),
            ],
          ),
        );
      },
    );
  }
}

/// The dock's outline: a rounded bar, with a bite taken out for the action.
Path _dockPath(Size size, double? notchCenter, double notchRadius) {
  final rect = Offset.zero & size;
  final rounded = Path()
    ..addRRect(RRect.fromRectAndRadius(rect, AppRadii.brXxl.topLeft));

  if (notchCenter == null) return rounded;

  // Flutter's own notch geometry: it eases the top edge down into the circle
  // rather than meeting it at a corner.
  final guest = Rect.fromCircle(
    center: Offset(notchCenter, 0),
    radius: notchRadius,
  );
  final withNotch = const CircularNotchedRectangle().getOuterPath(rect, guest);

  // Intersecting keeps the rounded corners, which getOuterPath drops.
  return Path.combine(PathOperation.intersect, rounded, withNotch);
}

/// Clips the blur to the dock's outline.
class _DockClipper extends CustomClipper<Path> {
  const _DockClipper({required this.notchCenter, required this.notchRadius});

  final double? notchCenter;
  final double notchRadius;

  @override
  Path getClip(Size size) => _dockPath(size, notchCenter, notchRadius);

  @override
  bool shouldReclip(_DockClipper old) =>
      old.notchCenter != notchCenter || old.notchRadius != notchRadius;
}

/// The lift under the dock.
///
/// Painted rather than left to a [BoxShadow], because the fill above it is
/// clipped to the notch and a clip would take the shadow with it.
class _DockShadowPainter extends CustomPainter {
  const _DockShadowPainter({
    required this.notchCenter,
    required this.notchRadius,
    required this.shadows,
  });

  final double? notchCenter;
  final double notchRadius;

  /// The same list every other floating surface uses, replayed against an
  /// arbitrary path so the dock matches sheets and dialogs.
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _dockPath(size, notchCenter, notchRadius);
    for (final shadow in shadows) {
      canvas.save();
      canvas.translate(shadow.offset.dx, shadow.offset.dy);
      canvas.drawPath(path, shadow.toPaint());
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DockShadowPainter old) =>
      old.notchCenter != notchCenter ||
      old.notchRadius != notchRadius ||
      old.shadows != shadows;
}

/// A hairline along the cut. Without it the notch edge disappears wherever the
/// page behind happens to match the dock.
class _DockRimPainter extends CustomPainter {
  const _DockRimPainter({
    required this.notchCenter,
    required this.notchRadius,
    required this.color,
  });

  final double? notchCenter;
  final double notchRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _dockPath(size, notchCenter, notchRadius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_DockRimPainter old) =>
      old.notchCenter != notchCenter ||
      old.notchRadius != notchRadius ||
      old.color != color;
}

/// One destination: icon, label, and the bar that marks the current page.
class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.onTap,
    this.selectedColor,
    this.unselectedColor,
    this.badgeRing,
  });

  final NeuNavItem item;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  /// Pinned by hosts that do not follow the app theme.
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? badgeRing;

  /// Wraps the icon in its count, if it has one.
  Widget _badged(Widget icon) {
    final count = item.badge ?? 0;
    if (count <= 0) return icon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -8,
          top: -5,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: AppRadii.brPill,
              // Ringed in the dock's own colour so the count stays a separate
              // shape from whatever it sits on.
              border: Border.all(
                color: badgeRing ?? AppColors.base,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                count > 99 ? '99+' : '\$count',
                style: AppTextStyles.label(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.badge != null && item.badge! > 0
          ? '${item.label}, ${item.badge} pending'
          : item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        // One tween drives colour, weight, the icon's lift and the indicator,
        // so every cue lands on the same frame instead of drifting apart.
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: selected ? 1.0 : 0.0),
          duration: AppMotion.normal,
          curve: AppMotion.standard,
          builder: (context, t, _) {
            final color = Color.lerp(
              unselectedColor ?? AppColors.textTertiary,
              selectedColor ?? AppColors.accentText,
              t,
            )!;

            return SizedBox(
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.translate(
                    // Rises as it becomes current, which makes room for the
                    // indicator below without the row changing height.
                    offset: Offset(0, -1.5 * t),
                    child: Transform.scale(
                      scale: 1 + 0.08 * t,
                      child: _badged(
                        Icon(
                          item.icon,
                          size: showLabel ? 22 : 24,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  if (showLabel) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label(
                        fontSize: 10,
                        color: color,
                        letterSpacing: 0.1,
                        fontWeight: t > 0.5 ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  // Grows out of its own centre. Scale rather than width, so
                  // the row never relayouts mid-transition.
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(t, 1, 1),
                    child: Opacity(
                      opacity: t,
                      child: Container(
                        width: 18,
                        height: 3,
                        decoration: BoxDecoration(
                          color: selectedColor ?? AppColors.accentFill,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
