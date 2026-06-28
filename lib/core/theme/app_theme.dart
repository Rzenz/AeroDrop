import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.bgDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.cardDark,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Color(0xFF0D1B2A),
        onSurface: AppColors.textPrimaryDark,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimaryDark),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.bgDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)), // 32px pill shape
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardDark2,
        selectedColor: AppColors.primary,
        labelStyle: AppTextStyles.label(color: AppColors.textPrimaryDark),
        side: const BorderSide(color: AppColors.borderDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), // 100px full pill shape
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)), // 28px top corners
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
      ),
      textTheme: TextTheme(
        headlineLarge: AppTextStyles.display(fontSize: 38),
        headlineMedium: AppTextStyles.heading(fontSize: 28),
        titleLarge: AppTextStyles.subHead(fontSize: 18, color: AppColors.textPrimaryDark),
        titleMedium: AppTextStyles.subHead(fontSize: 16, color: AppColors.textPrimaryDark),
        bodyLarge: AppTextStyles.body(fontSize: 16),
        bodyMedium: AppTextStyles.body(fontSize: 14, color: AppColors.textSecondaryDark),
        bodySmall: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark),
        labelLarge: AppTextStyles.label(fontSize: 12),
      ),
    );
  }

  static ThemeData get lightTheme => darkTheme; // Enforce deep navy dark mode across all views for visual consistency and premium aesthetic
}
