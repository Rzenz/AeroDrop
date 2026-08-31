import 'package:flutter/widgets.dart';

/// The 4pt spacing scale. Every gap, pad and inset in the redesigned UI comes
/// from here so rhythm stays consistent across 60+ screens.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double giant = 64;

  // Common ready-made insets — avoids re-typing EdgeInsets everywhere.
  static const EdgeInsets allXs = EdgeInsets.all(xs);
  static const EdgeInsets allSm = EdgeInsets.all(sm);
  static const EdgeInsets allMd = EdgeInsets.all(md);
  static const EdgeInsets allLg = EdgeInsets.all(lg);
  static const EdgeInsets allXl = EdgeInsets.all(xl);

  static const SizedBox gapXxs = SizedBox(height: xxs, width: xxs);
  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);

  /// Horizontal page gutter, widened on tablets/desktop so content does not
  /// stretch into an unreadable line length.
  static double pageGutter(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1200) return xxxl;
    if (w >= 600) return xxl;
    if (w < 360) return md;
    return lg;
  }

  /// Bottom padding that clears the floating nav dock plus the home indicator.
  ///
  /// Sized for the customer dock, which is the taller of the two: its centre
  /// action overhangs the bar, and a list ending underneath that circle looks
  /// like it was cut off rather than scrolled past.
  static double dockClearance(BuildContext context) =>
      112 + MediaQuery.paddingOf(context).bottom;
}

/// Layout breakpoints. Mirrors the Material window-size classes.
class AppBreakpoints {
  const AppBreakpoints._();

  static const double tablet = 600;
  static const double desktop = 1200;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360;

  /// Column count for product/tile grids at the current width.
  static int gridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= desktop) return 4;
    if (w >= tablet) return 3;
    return 2;
  }
}
