import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_theme.dart';

/// Neumorphic elevation levels.
///
/// Depth is expressed as a level rather than raw pixel offsets so that every
/// surface in the app shares one light source (top-left) and one falloff curve.
enum NeuDepth {
  /// Barely lifted — dense list rows, chips, inline tiles.
  flat,

  /// The default card lift.
  low,

  /// Primary surfaces that should read as the focus of a screen.
  medium,

  /// Dialogs, sheets, the nav dock and the FAB.
  high,
}

/// The neumorphic shadow system.
///
/// A raised surface is lit from the top-left: a light shadow offset up-left and
/// a dark shadow offset down-right, both softly blurred. Keeping blur roughly
/// twice the offset is what separates "soft material" from "drop shadow".
class AppShadows {
  const AppShadows._();

  /// Offset distance in logical pixels for each depth level.
  static double _distance(NeuDepth depth) => switch (depth) {
    NeuDepth.flat => 2,
    NeuDepth.low => 4,
    NeuDepth.medium => 6,
    NeuDepth.high => 10,
  };

  /// Opacity of the light highlight. The dark canvas needs a gentler highlight
  /// than the light one or the top-left edge turns into a visible rim.
  static double _lightAlpha(NeuDepth depth) {
    final base = AppTheme.isDarkMode ? 0.55 : 0.9;
    return switch (depth) {
      NeuDepth.flat => base * 0.7,
      NeuDepth.low => base * 0.85,
      NeuDepth.medium => base,
      NeuDepth.high => base,
    };
  }

  static double _shadowAlpha(NeuDepth depth) {
    final base = AppTheme.isDarkMode ? 0.62 : 0.72;
    return switch (depth) {
      NeuDepth.flat => base * 0.7,
      NeuDepth.low => base * 0.85,
      NeuDepth.medium => base,
      NeuDepth.high => base,
    };
  }

  /// Every raised surface in the app asks for its shadow on every build, so
  /// the four possible lists per brightness are built once and shared. The
  /// lists are const-shaped and never mutated by callers.
  static final Map<(bool, NeuDepth), List<BoxShadow>> _raisedCache = {};
  static List<BoxShadow>? _floatingCache;
  static bool? _cachedBrightness;

  static void _invalidateIfBrightnessChanged() {
    if (_cachedBrightness != AppTheme.isDarkMode) {
      _cachedBrightness = AppTheme.isDarkMode;
      _raisedCache.clear();
      _floatingCache = null;
    }
  }

  /// A raised surface at [depth]. Use on containers whose fill equals the
  /// colour of the surface behind them.
  static List<BoxShadow> raised([NeuDepth depth = NeuDepth.low]) {
    _invalidateIfBrightnessChanged();
    return _raisedCache.putIfAbsent((AppTheme.isDarkMode, depth), () {
      final d = _distance(depth);
      return List<BoxShadow>.unmodifiable([
        BoxShadow(
          color: AppColors.neuShadow.withValues(alpha: _shadowAlpha(depth)),
          offset: Offset(d, d),
          blurRadius: d * 2,
        ),
        BoxShadow(
          color: AppColors.neuLight.withValues(alpha: _lightAlpha(depth)),
          offset: Offset(-d, -d),
          blurRadius: d * 2,
        ),
      ]);
    });
  }

  /// Convenience aliases for the levels used most often.
  static List<BoxShadow> get flat => raised(NeuDepth.flat);
  static List<BoxShadow> get low => raised(NeuDepth.low);
  static List<BoxShadow> get medium => raised(NeuDepth.medium);

  /// Dialogs, bottom sheets and the nav dock — these float above the canvas
  /// rather than being embossed from it, so they take a directional shadow
  /// with only a hint of the top highlight.
  static List<BoxShadow> get floating {
    _invalidateIfBrightnessChanged();
    return _floatingCache ??= List<BoxShadow>.unmodifiable([
      BoxShadow(
        color: AppColors.neuShadow.withValues(
          alpha: AppTheme.isDarkMode ? 0.7 : 0.5,
        ),
        offset: const Offset(0, 12),
        blurRadius: 28,
        spreadRadius: -6,
      ),
      BoxShadow(
        color: AppColors.neuLight.withValues(
          alpha: AppTheme.isDarkMode ? 0.35 : 0.8,
        ),
        offset: const Offset(-4, -4),
        blurRadius: 12,
      ),
    ]);
  }

  /// A coloured halo. Reserved for the single primary action on a screen —
  /// used more than that it becomes the "glowing blob" look.
  static List<BoxShadow> glow(Color color, {double alpha = 0.30}) => [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      offset: const Offset(0, 6),
      blurRadius: 18,
      spreadRadius: -4,
    ),
  ];
}
