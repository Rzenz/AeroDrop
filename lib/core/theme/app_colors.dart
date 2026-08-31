import 'package:flutter/material.dart';
import 'app_theme.dart';

/// AeroDrop colour tokens — tuned for a soft neumorphic surface system.
///
/// Neumorphism only reads correctly when a component's fill matches the
/// surface it sits on, so [bgDark]/[cardDark] (and their light twins) are
/// deliberately close in value. Depth comes from [AppShadows], not from
/// contrasting fills.
///
/// Every token name predates the neumorphic retune and is kept stable so the
/// ~1400 existing references across `lib/features` keep resolving.
class AppColors {
  // === Brand — sampled from the app icon ===
  // The icon is a vertical gradient from a bright sky blue down to a deep
  // indigo, with pure-white line art. Those three values are the whole brand:
  // [accent] is the top of that gradient, [primary] the bottom, and white is
  // what sits on top of them.
  //
  // There is deliberately no yellow. The previous palette used a vivid amber
  // accent that appears nowhere in the mark.

  /// Bottom of the icon gradient. Primary actions, active states, identity.
  static const Color primary = Color(0xFF3A6FD4);

  /// Text- and icon-safe brand blue on a dark surface (5.1:1 on [bgDark]).
  static const Color primaryLight = Color(0xFF5D93EE);

  /// For fills that carry white content.
  static const Color primaryDark = Color(0xFF2C56AC);

  /// Top of the icon gradient. Highlights, progress, the active nav pill.
  /// Light enough that dark content sits on it at 7:1.
  static const Color accent = Color(0xFF4FB1F6);
  static const Color accentLight = Color(0xFF8ACDFA);
  static const Color accentDark = Color(0xFF2E96E4);

  /// Accent deep enough to use as *text* on the light canvas, where the sky
  /// tone itself only reaches 2.8:1.
  static const Color accentOnLight = Color(0xFF1466A8);

  // === Semantic ===
  // Nudged toward the blue-leaning brand so status colours read as part of the
  // same family rather than borrowed from a different app.
  static const Color success = Color(0xFF2BBE8A);
  static const Color warning = Color(0xFFF0A03C);
  static const Color danger = Color(0xFFEF5C74);
  static const Color info = Color(0xFF4FB1F6);
  static const Color secondary = accent;

  // === Dark surfaces — the deep end of the icon gradient ===
  /// Canvas *and* default raised-card fill. These must stay equal for the
  /// neumorphic soft-shadow illusion to work.
  static const Color bgDark = Color(0xFF19223B);
  static const Color bgDark2 = Color(0xFF19223B);
  static const Color cardDark = Color(0xFF19223B);

  /// One step up — a surface layered on another raised surface.
  static const Color cardDark2 = Color(0xFF1F2947);

  /// One step down — the fill for inset wells (inputs, tracks, switches).
  static const Color sunkenDark = Color(0xFF141B30);

  /// Hairline separator. Low contrast on purpose: neumorphism leans on shadow,
  /// and a strong border flattens the effect.
  static const Color borderDark = Color(0xFF2A3557);

  /// Neumorphic shadow pair for the dark surface.
  static const Color neuLightShadowDark = Color(0xFF232E4E);
  static const Color neuDarkShadowDark = Color(0xFF0C1120);

  // === Dark theme text ===
  /// Faintly blue-white, matching the icon's line art rather than pure grey.
  static const Color textPrimaryDark = Color(0xFFEDF2FC);
  static const Color textSecondaryDark = Color(0xFF94A3C4);
  static const Color textTertiaryDark = Color(0xFF6B7A9E);

  // === Light surfaces — the cloud end ===
  static const Color bgLight = Color(0xFFEBF1FB);
  static const Color cardLight = Color(0xFFEBF1FB);
  static const Color cardLight2 = Color(0xFFF2F6FD);
  static const Color sunkenLight = Color(0xFFE1E9F7);
  static const Color borderLight = Color(0xFFD2DDF0);

  static const Color neuLightShadowLight = Color(0xFFFFFFFF);
  static const Color neuDarkShadowLight = Color(0xFFBCC9E2);

  // === Light theme text ===
  static const Color textPrimaryLight = Color(0xFF16203A);
  static const Color textSecondaryLight = Color(0xFF56658A);
  static const Color textTertiaryLight = Color(0xFF7B89A8);

  /// White, for content sitting on a [primary] or gradient fill — the icon's
  /// own pairing.
  static const Color onBrand = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------
  // Brightness-aware resolvers — prefer these in new code.
  // ---------------------------------------------------------------------

  static bool get _dark => AppTheme.isDarkMode;

  /// The scaffold canvas. Also the correct fill for a raised neumorphic card.
  static Color get base => _dark ? bgDark : bgLight;

  /// A surface layered above [base].
  static Color get surfaceRaised => _dark ? cardDark2 : cardLight2;

  /// The fill for an inset well — inputs, switch tracks, pressed buttons.
  static Color get surfaceSunken => _dark ? sunkenDark : sunkenLight;

  static Color get border => _dark ? borderDark : borderLight;

  static Color get textPrimary => _dark ? textPrimaryDark : textPrimaryLight;
  static Color get textSecondary =>
      _dark ? textSecondaryDark : textSecondaryLight;
  static Color get textTertiary => _dark ? textTertiaryDark : textTertiaryLight;

  /// Top-left highlight of the neumorphic shadow pair.
  static Color get neuLight => _dark ? neuLightShadowDark : neuLightShadowLight;

  /// Bottom-right shadow of the neumorphic shadow pair.
  static Color get neuShadow => _dark ? neuDarkShadowDark : neuDarkShadowLight;

  /// Readable accent for body-sized text. The sky tone only reaches 2.8:1 on
  /// the light canvas, so light mode drops to a deeper blue.
  static Color get accentText => _dark ? accent : accentOnLight;

  /// Fill colour for an accent *surface* — a primary button, the FAB, a
  /// progress bar, an avatar.
  ///
  /// The sky tone only reaches 2.07:1 against the light canvas, below the 3:1
  /// a UI component needs, so light mode uses the deep end of the icon
  /// gradient instead. Both values come from the logo: dark mode borrows its
  /// top, light mode its bottom.
  static Color get accentFill => _dark ? accent : primary;

  /// Content sitting on [accentFill]. Dark on the sky tone (6.7:1), white on
  /// the deep blue (4.9:1) — which is the logo's own pairing.
  static Color get onAccentFill => _dark ? bgDark : onBrand;

  /// Adjusts a saturated status colour so it is legible as *text* on the
  /// current canvas.
  ///
  /// The semantic tones are tuned to sit on the dark canvas. On the light one
  /// they land around 2:1 — success at 1.9:1 is the worst — so light mode
  /// darkens them. 0.45 is the blend that carries every semantic colour past
  /// 4.5:1 without turning them muddy.
  static Color readable(Color tone) =>
      _dark ? tone : Color.lerp(tone, const Color(0xFF000000), 0.45)!;

  /// Readable brand blue for body-sized text on either canvas.
  static Color get primaryText => _dark ? primaryLight : primaryDark;

  // ---------------------------------------------------------------------
  // Gradients
  //
  // [brandGradient] is the icon, reproduced exactly: sky at the top, indigo at
  // the bottom, vertical. It is reserved for identity moments — the app mark,
  // the launch screen, the primary floating action — where the surface is
  // standing in for the logo. Everywhere else stays flat, because a gradient
  // that appears on every card stops meaning anything.
  //
  // The remaining entries keep their old names for existing call sites but are
  // near-monochrome: in a neumorphic system a gradient describes light falling
  // across a surface, not decoration.
  // ---------------------------------------------------------------------

  /// The app icon's gradient.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF4FB1F6), Color(0xFF3A6FD4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4A82E2), Color(0xFF2C56AC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient accentGradient = brandGradient;

  /// Soft raised-surface sheen for hero panels. Reads as lit material rather
  /// than a coloured slab.
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1F2A49), Color(0xFF161E35)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Page background. Almost flat by design — the canvas must stay quiet so
  /// raised elements can read against it.
  static const LinearGradient bgGradientDark = LinearGradient(
    colors: [Color(0xFF1A233D), Color(0xFF172038)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient cardGradientDark = LinearGradient(
    colors: [Color(0xFF1E2845), Color(0xFF182137)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF3ED09A), Color(0xFF1E9C71)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFEF5C74), Color(0xFFC63E56)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
