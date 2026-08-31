import 'package:flutter/widgets.dart';

/// Corner-radius scale.
///
/// Neumorphic shadows need a radius large enough to catch the light but not so
/// large that every element becomes a lozenge — [md] and [lg] carry most of the
/// UI, [pill] is reserved for genuinely capsule-shaped controls.
class AppRadii {
  const AppRadii._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 26;
  static const double xxl = 32;
  static const double pill = 999;

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));

  /// Top-only radius for bottom sheets.
  static const BorderRadius brSheet = BorderRadius.vertical(
    top: Radius.circular(xxl),
  );
}
