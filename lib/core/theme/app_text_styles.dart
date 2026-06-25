import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  // Plus Jakarta Sans for titles
  static TextStyle title({
    required double fontSize,
    FontWeight fontWeight = FontWeight.bold,
    required Color color,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  // Inter for body text
  static TextStyle body({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    required Color color,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  // Convenience alias: FontWeight.w600 does not exist in Flutter; use w600.
  // ponytail: exposing as a const so callers don't scatter FontWeight.w600 everywhere.
  static const FontWeight semibold = FontWeight.w600;
}
