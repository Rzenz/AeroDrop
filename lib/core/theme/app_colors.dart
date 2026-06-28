import 'package:flutter/material.dart';

class AppColors {
  // === Brand — Electric Blue ===
  static const Color primary = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF1565C0);

  // === Accent — Vivid Yellow ===
  static const Color accent = Color(0xFFFFD600);
  static const Color accentLight = Color(0xFFFFF176);
  static const Color accentDark = Color(0xFFFFCA28);

  // === Semantic ===
  static const Color success = Color(0xFF00C896);
  static const Color warning = Color(0xFFFFB547);
  static const Color danger = Color(0xFFFF4D6A);
  static const Color info = Color(0xFF29B6F6);
  static const Color secondary = accent;

  // === Dark Theme Surfaces ===
  static const Color bgDark = Color(0xFF0D1B2A);
  static const Color bgDark2 = Color(0xFF122336);
  static const Color cardDark = Color(0xFF1A2332);
  static const Color cardDark2 = Color(0xFF222E41);
  static const Color borderDark = Color(0xFF2C3B52);

  // === Dark Theme Text ===
  static const Color textPrimaryDark = Color(0xFFF8FAFF);
  static const Color textSecondaryDark = Color(0xFF7B8FA1);

  // === Light Theme ===
  static const Color bgLight = Color(0xFFF0F6FF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0A1628);
  static const Color textSecondaryLight = Color(0xFF4A6B8A);
  static const Color borderLight = Color(0xFFCCDEF5);

  // === Gradients ===
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFFD600), Color(0xFFFFCA28)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF0D1B2A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient bgGradientDark = LinearGradient(
    colors: [Color(0xFF0D1B2A), Color(0xFF122336)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient cardGradientDark = LinearGradient(
    colors: [Color(0xFF1A2332), Color(0xFF122336)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient blueYellowGradient = LinearGradient(
    colors: [Color(0xFF1976D2), Color(0xFFFFD600)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient purpleCyanGradient = primaryGradient;
  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF29B6F6), Color(0xFF0288D1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00C896), Color(0xFF00A876)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF4D6A), Color(0xFFD32F2F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
