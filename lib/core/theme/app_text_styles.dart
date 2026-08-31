import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography for AeroDrop.
///
/// Two families, not three. Plus Jakarta Sans carries structure (display,
/// headings, titles, buttons) — its slightly condensed geometry holds up at
/// large sizes without the roundness that made the previous Poppins headings
/// read as generic. Inter carries everything meant to be read (body, captions)
/// because its tall x-height survives the low-contrast neumorphic surfaces.
///
/// Weights are limited to 400/500/600/700/800 on purpose: more weights make a
/// hierarchy blurrier, not richer.
class AppTextStyles {
  const AppTextStyles._();

  static TextStyle _structure({
    required double fontSize,
    required FontWeight fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.textPrimary,
    letterSpacing: letterSpacing,
    height: height,
  );

  static TextStyle _reading({
    required double fontSize,
    required FontWeight fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.inter(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.textPrimary,
    letterSpacing: letterSpacing,
    height: height,
  );

  /// Display — hero moments only: splash, onboarding, success screens.
  /// Negative tracking keeps large type from looking loose.
  static TextStyle display({
    double fontSize = 36,
    Color? color,
    double letterSpacing = -0.9,
    FontWeight fontWeight = FontWeight.w800,
  }) => _structure(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: 1.1,
  );

  /// Heading — screen titles and major section openers.
  static TextStyle heading({
    double fontSize = 24,
    Color? color,
    FontWeight fontWeight = FontWeight.w700,
  }) => _structure(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: -0.4,
    height: 1.2,
  );

  /// SubHead — card titles, list-row titles, section headers.
  static TextStyle subHead({
    double fontSize = 16,
    Color? color,
    FontWeight fontWeight = FontWeight.w600,
  }) => _structure(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  /// Body — descriptions and content. 1.5 line-height for comfortable reading.
  static TextStyle body({
    double fontSize = 14,
    Color? color,
    double? height,
    FontWeight fontWeight = FontWeight.w400,
  }) => _reading(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height ?? 1.5,
  );

  /// Label — buttons, tabs, metadata, nav items. Slight positive tracking
  /// because short uppercase-ish strings need the air.
  static TextStyle label({
    double fontSize = 12,
    Color? color,
    double letterSpacing = 0.4,
    FontWeight fontWeight = FontWeight.w600,
  }) => _reading(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.textSecondary,
    letterSpacing: letterSpacing,
    height: 1.2,
  );

  /// Caption — timestamps, helper text, the quietest tier.
  static TextStyle caption({
    double fontSize = 12,
    Color? color,
    FontWeight fontWeight = FontWeight.w400,
  }) => _reading(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.textTertiary,
    height: 1.4,
  );

  /// Numeric emphasis — stat values, prices, counters. Tabular figures stop
  /// live-updating numbers from jittering their own width.
  static TextStyle numeric({
    double fontSize = 24,
    Color? color,
    FontWeight fontWeight = FontWeight.w800,
  }) => _structure(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: -0.6,
    height: 1.1,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// The receipt face.
  ///
  /// A third family, and the only place one is justified: a receipt is a
  /// facsimile of something a thermal printer produced, and monospace with
  /// aligned columns is what makes it read as that rather than as another
  /// card. Confined to the receipt — anywhere else it is costume.
  static TextStyle receipt({
    double fontSize = 12,
    Color? color,
    FontWeight fontWeight = FontWeight.w400,
    double letterSpacing = 0,
    double height = 1.45,
  }) => GoogleFonts.robotoMono(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.textPrimary,
    letterSpacing: letterSpacing,
    height: height,
  );

  /// Generic structural style. Retained for the call sites that pass an
  /// explicit size/weight/colour triple.
  static TextStyle title({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
    required Color color,
    double? letterSpacing,
  }) => _structure(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing ?? -0.3,
    height: 1.2,
  );

  static const FontWeight semibold = FontWeight.w600;
}
