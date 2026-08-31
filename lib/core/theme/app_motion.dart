import 'package:flutter/animation.dart';

/// Motion tokens.
///
/// One vocabulary for the whole app: short durations, decelerating curves, and
/// nothing long enough to make the UI feel like it is performing. Anything
/// above [slow] belongs to a deliberate celebration moment, not to navigation.
class AppMotion {
  const AppMotion._();

  /// Press / release feedback.
  static const Duration instant = Duration(milliseconds: 90);

  /// State changes on a control — focus, selection, toggle.
  static const Duration fast = Duration(milliseconds: 160);

  /// The default. Card entrances, expands, page content.
  static const Duration normal = Duration(milliseconds: 260);

  /// Route transitions and larger surface changes.
  static const Duration slow = Duration(milliseconds: 380);

  /// Deceleration curve for anything entering or settling.
  static const Curve enter = Curves.easeOutCubic;

  /// For anything leaving.
  static const Curve exit = Curves.easeInCubic;

  /// Symmetric changes — colour, opacity, size on an existing element.
  static const Curve standard = Curves.easeInOutCubic;

  /// A restrained overshoot for toggles and selection pills. Deliberately not
  /// elasticOut — that reads as playful, which is off-brand here.
  static const Curve spring = Curves.easeOutBack;

  /// Per-item delay for staggered list entrances.
  static const Duration stagger = Duration(milliseconds: 45);

  /// Caps a stagger so long lists do not animate for seconds.
  static Duration staggerFor(int index, {int max = 8}) =>
      stagger * (index > max ? max : index);
}
