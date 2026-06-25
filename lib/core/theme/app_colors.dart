import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF3D5BF5);
  static const Color secondary = Color(0xFF00E5FF);
  static const Color secondaryDark = Color(0xFF00B4CC);

  // Semantic
  static const Color success = Color(0xFF00C896);
  static const Color warning = Color(0xFFFFB547);
  static const Color danger = Color(0xFFFF4D6A);
  static const Color info = Color(0xFF4DA8FF);

  // Dark Theme
  static const Color bgDark = Color(0xFF080B14);
  static const Color bgDark2 = Color(0xFF0C1220);
  static const Color cardDark = Color(0xFF0E1525);
  static const Color cardDark2 = Color(0xFF141C35);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF8892B0);
  static const Color borderDark = Color(0xFF1E2A45);

  // Light Theme
  static const Color bgLight = Color(0xFFF0F4FF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0A0E1A);
  static const Color textSecondaryLight = Color(0xFF5A6480);
  static const Color borderLight = Color(0xFFDDE3F8);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF3D5BF5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF00B4CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00C896), Color(0xFF00A876)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFFB547), Color(0xFFFF8C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF4D6A), Color(0xFFCC0033)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient bgGradientDark = LinearGradient(
    colors: [Color(0xFF080B14), Color(0xFF0E1525)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient cardGradientDark = LinearGradient(
    colors: [Color(0xFF141C35), Color(0xFF0E1525)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient purpleCyanGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
