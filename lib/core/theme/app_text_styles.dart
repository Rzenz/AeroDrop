import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  /// Display: Poppins ExtraBold, 36–48px, white, tight letter-spacing
  static TextStyle display({
    double fontSize = 40,
    Color color = AppColors.textPrimaryDark,
    double letterSpacing = -1.0,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Heading: Poppins Bold, 24–32px, white
  static TextStyle heading({
    double fontSize = 28,
    Color color = AppColors.textPrimaryDark,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: color,
    );
  }

  /// SubHead: Poppins SemiBold, 16–18px, #7B8FA1
  static TextStyle subHead({
    double fontSize = 16,
    Color color = AppColors.textSecondaryDark,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }

  /// Body: Inter Regular, 14–16px, #F8FAFF at 85% opacity
  static TextStyle body({
    double fontSize = 14,
    Color color = const Color(0xD9F8FAFF), // 85% opacity white
    double? height,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  /// Label: Nunito SemiBold, 12px, uppercase, 1.2px letter-spacing
  static TextStyle label({
    double fontSize = 12,
    Color color = AppColors.textSecondaryDark,
    double letterSpacing = 1.2,
  }) {
    return GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: letterSpacing,
    ).copyWith(
      fontFeatures: const [FontFeature.enable('smcp')], // small caps if supported
    );
  }

  /// Generic title method for backward compatibility
  static TextStyle title({
    required double fontSize,
    FontWeight fontWeight = FontWeight.bold,
    required Color color,
    double? letterSpacing,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static const FontWeight semibold = FontWeight.w600;
}
