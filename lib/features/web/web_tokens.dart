import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import 'web_breakpoints.dart';

/// The marketing site's own token set.
///
/// Design read: a public landing page for UCLM students, composed after the
/// "Habit Builder" night-sky layout (centred display headline, tilted phone,
/// gradient tiles), but coloured from AeroDrop's own mark rather than that
/// shot's violet-and-pink. Dials: ENERGY 3 / RHYTHM 2 / MOTION 2.
///
/// Why the page is dark (R-21): the app itself is dark-first — its canvas is
/// [AppColors.bgDark] — and the product is a drone in the sky over campus.
///
/// The canvas is the app's own [AppColors.bgDark], not a deeper night: the
/// site is cut from the same neumorphic material as the app ([web]), and
/// soft raised and pressed surfaces only read on a mid-dark canvas — on a
/// near-black one the light half of every shadow pair disappears.
///
/// Four colours carry the chrome: [canvas], [text], [rule], and one accent,
/// the sky blue at the top of the icon gradient. Everything else that has
/// colour is a [WebSky] tile, and those carry meaning (see that class).
class WebInk {
  const WebInk._();

  /// The page — the app's dark canvas, and the fill of every raised surface
  /// on it.
  static const Color canvas = AppColors.bgDark;

  /// One step up, for a surface layered on another — the mobile menu sheet,
  /// a dropdown's menu.
  static const Color raised = AppColors.cardDark2;

  /// The site's neumorphic palette: the app's dark one. The website is dark
  /// in either app theme.
  static const NeuPalette web = NeuPalette.darkPalette;

  /// Headlines and body copy. The app's own blue-white, not pure white, so it
  /// sits in the icon's line-art family. 16:1 on [canvas].
  static const Color text = AppColors.textPrimaryDark;

  /// Secondary copy. 7:1 on [canvas].
  static const Color textSoft = Color(0xFFA3AECB);

  /// Numerals and quiet metadata. 4.8:1 on [canvas], so it passes as body
  /// text too, but it is only used where it is meant to recede.
  static const Color textFaint = Color(0xFF8291B4);

  /// Hairline, for the few places a rule still says more than depth.
  static const Color rule = AppColors.borderDark;

  /// The single chrome accent: the top of the icon gradient. 6.6:1 on
  /// [canvas], so it is safe as link and marker text. The app's mid blue
  /// ([AppColors.primary]) drops to 4:1 on this canvas and is kept for fills.
  static const Color accent = AppColors.accent;

  // ─── The closing panel ─────────────────────────────────────────────────────

  /// The closing call-to-action panel is the icon gradient itself, bottom
  /// stop to a deeper indigo. White on its lightest stop is 4.8:1.
  static const List<Color> panel = [AppColors.primary, Color(0xFF1F2F7A)];

  static const Color onPanel = Color(0xFFFFFFFF);
  static const Color onPanelRule = Color(0x33FFFFFF);
}

/// The hero's gradient tiles.
///
/// The reference shot uses unrelated pastel gradients. Unrelated pastels are
/// the default-palette tell (R-01), so the skies here are the sky over campus
/// through a school day — dawn, noon, dusk, after dark — and the hero's four
/// canteen tiles take them in reading order, so the row reads as one day of
/// orders. The night sky is the app icon's own gradient. A drone delivery
/// product flies through all of them, which is the reason the palette exists
/// at all. [afternoon] is kept for small marks elsewhere on the page.
///
/// Text on every light tile is [WebInk.canvas] (at least 8:1 on the lightest
/// stop); the night tile carries white (4.8:1 on its lightest stop).
enum WebSky {
  dawn(Color(0xFFFFE2A6), Color(0xFF9ED6F6), dark: true),
  noon(Color(0xFFCBEEFF), Color(0xFF7CC4F8), dark: true),
  afternoon(Color(0xFFFFD4B4), Color(0xFFF5A79E), dark: true),
  dusk(Color(0xFFF7B39E), Color(0xFFA9A8EE), dark: true),
  night(AppColors.primary, Color(0xFF1F2F7A), dark: false);

  const WebSky(this.from, this.to, {required this.dark});

  final Color from;
  final Color to;

  /// True when the tile takes dark text.
  final bool dark;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [from, to],
  );

  Color get ink => dark ? WebInk.canvas : const Color(0xFFFFFFFF);

  /// Secondary text on the tile — the category label and the link. Above
  /// 5:1 on every light stop. The night tile keeps full white, because any
  /// tint of white falls under 4.5:1 on the icon's mid blue.
  Color get inkSoft => dark ? const Color(0xFF2A3157) : const Color(0xFFFFFFFF);
}

/// Layered elevation, per the `beautiful-shadows` recipe, retuned for a dark
/// canvas where a neutral shadow needs more opacity to register at all.
///
/// Exactly two things are elevated: the phone in the hero, and the nav bar
/// once it detaches. The tiles sit on the canvas and get their separation
/// from their own fill.
class WebElevation {
  const WebElevation._();

  /// The phone. The last layer is long and soft so the device reads as
  /// held above the tiles rather than stacked on them.
  static const List<BoxShadow> hero = [
    BoxShadow(color: Color(0x26000000), blurRadius: 3, offset: Offset(0, 3)),
    BoxShadow(color: Color(0x2E000000), blurRadius: 10, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x38000000), blurRadius: 26, offset: Offset(0, 24)),
    BoxShadow(color: Color(0x47000000), blurRadius: 60, offset: Offset(0, 48)),
    BoxShadow(color: Color(0x52000000), blurRadius: 110, offset: Offset(0, 90)),
  ];

  static const List<BoxShadow> bar = [
    BoxShadow(color: Color(0x33000000), blurRadius: 1, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x40000000), blurRadius: 28, offset: Offset(0, 10)),
  ];
}

/// The type scale.
///
/// One display moment uses Unbounded: the hero headline. It is the closest
/// open face to the reference's wide grotesk, and its wide set suits a
/// product about horizon and airspace (R-06). It is set uppercase there only
/// — a wide face in sentence case at reading sizes reads as a costume. Section titles stay in Plus Jakarta Sans, the app's own
/// display family, and body copy stays in Inter, the app's text family, so
/// the page and the app read as one product.
class WebType {
  const WebType._();

  static const double _displayTracking = -0.02;
  static const double _titleTracking = -0.032;

  static double _preferredDisplay(WebBreak brk) => switch (brk) {
    WebBreak.expanded => 112.0,
    WebBreak.medium => 76.0,
    WebBreak.compact => 44.0,
  };

  static TextStyle _unbounded(double size, Color? color) =>
      GoogleFonts.unbounded(
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 0.98,
        letterSpacing: size * _displayTracking,
        color: color ?? WebInk.text,
      );

  /// The hero headline. One per page.
  static TextStyle display(WebBreak brk, {Color? color}) =>
      _unbounded(_preferredDisplay(brk), color);

  /// The largest [display] size whose [longestLine] still fits [maxWidth] on
  /// one line, capped at the breakpoint's own size.
  ///
  /// The Dart equivalent of `clamp(2rem, 9vw, 7rem)`. Width scales linearly
  /// with font size because the tracking is itself a fraction of the size, so
  /// measuring once at a probe size is exact rather than iterative. The 0.96
  /// margin absorbs the metric difference before and after the webfont loads.
  static double fitDisplay({
    required String longestLine,
    required double maxWidth,
    required WebBreak brk,
  }) {
    const probe = 100.0;
    final preferred = _preferredDisplay(brk);
    final minimum = brk.isCompact ? 28.0 : 44.0;

    final painter = TextPainter(
      text: TextSpan(text: longestLine, style: _unbounded(probe, null)),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final measured = painter.width;
    painter.dispose();
    if (measured <= 0) return preferred;

    return (probe * maxWidth * 0.96 / measured).clamp(minimum, preferred);
  }

  /// [display] at an explicit size, for callers using [fitDisplay].
  static TextStyle displayAt(double size, {Color? color}) =>
      _unbounded(size, color);

  /// Section openers.
  static TextStyle title(WebBreak brk, {Color? color}) {
    final size = switch (brk) {
      WebBreak.expanded => 54.0,
      WebBreak.medium => 40.0,
      WebBreak.compact => 30.0,
    };
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w800,
      height: 1.04,
      letterSpacing: size * _titleTracking,
      color: color ?? WebInk.text,
    );
  }

  /// A row heading inside a list, and the statement on a sky tile.
  static TextStyle entry(WebBreak brk, {Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: brk.isCompact ? 19 : 23,
        fontWeight: FontWeight.w700,
        height: 1.24,
        letterSpacing: brk.isCompact ? -0.3 : -0.5,
        color: color ?? WebInk.text,
      );

  /// The sentence that bridges a display size and the reading size.
  static TextStyle lead(WebBreak brk, {Color? color}) => GoogleFonts.inter(
    fontSize: brk.isCompact ? 16 : 18,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: color ?? WebInk.textSoft,
  );

  static TextStyle body({Color? color}) => GoogleFonts.inter(
    fontSize: 15.5,
    fontWeight: FontWeight.w400,
    height: 1.68,
    color: color ?? WebInk.textSoft,
  );

  /// Nav items, buttons, link text.
  static TextStyle action({
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) => GoogleFonts.inter(
    fontSize: 14.5,
    fontWeight: weight,
    height: 1.2,
    letterSpacing: -0.1,
    color: color ?? WebInk.text,
  );

  /// Section markers and quiet metadata. Sentence case with modest tracking —
  /// wide-tracked uppercase is the shorthand for "technical" that every
  /// generated page reaches for.
  static TextStyle meta({Color? color}) => GoogleFonts.inter(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.02,
    color: color ?? WebInk.textFaint,
  );

  /// The editorial numerals that index a list. Tabular so 01 and 11 occupy
  /// the same width and the column stays straight.
  static TextStyle numeral(WebBreak brk, {Color? color}) => GoogleFonts.inter(
    fontSize: brk.isCompact ? 13 : 14,
    fontWeight: FontWeight.w600,
    height: 1,
    letterSpacing: 0.04,
    color: color ?? WebInk.textFaint,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// A full-width hairline. The page's only structural divider.
class WebRule extends StatelessWidget {
  const WebRule({super.key, this.color = WebInk.rule});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(height: 1, color: color);
}

/// The landing page's photographs, from Unsplash (Unsplash License: free to
/// use, no attribution required — sources in assets/images/landing/CREDITS.md).
///
/// They replace the colour gradients the page used for its tiles, panels and
/// hero light. Each sits under a flat navy tint where text crosses it, so the
/// copy keeps its contrast on any part of the picture.
class WebPhoto {
  const WebPhoto._();

  static const _dir = 'assets/images/landing';
  static const hero = '$_dir/hero_drone_dusk.jpg';
  static const download = '$_dir/download_drone_skyline.jpg';
  static const wallpaper = '$_dir/phone_wallpaper_city.jpg';
  static const annex = '$_dir/canteen_annex.jpg';
  static const oldBuilding = '$_dir/canteen_old_building.jpg';
  static const engineering = '$_dir/canteen_engineering.jpg';
  static const maritime = '$_dir/canteen_maritime.jpg';

  /// The university's own photograph, already in the app.
  static const campus = 'assets/images/uclm_campus.jpg';

  /// A photograph that fails to load leaves its box's own colour showing
  /// rather than an error: the page still reads without it.
  static Widget missing(BuildContext _, Object _, StackTrace? _) =>
      const SizedBox.shrink();

  /// The same fallback for a photograph drawn as a [DecorationImage].
  static void ignore(Object _, StackTrace? _) {}

  /// A caption plate over a photograph: the canvas at 92%, so the plate
  /// holds text contrast even where the photo behind it is white.
  static Color get plate => WebInk.canvas.withValues(alpha: 0.92);

  /// Secondary text on a [plate]. Lighter than [WebInk.textSoft], which
  /// drops under 4.5:1 once a bright photo shows through the plate.
  static const Color plateSoft = Color(0xFFC9D2E8);
}
