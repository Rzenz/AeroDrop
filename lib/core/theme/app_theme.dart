import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.bgLight,
      cardTheme: const CardThemeData(
        color: AppColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: AppTextStyles.title(fontSize: 32, color: AppColors.textPrimaryLight),
        headlineMedium: AppTextStyles.title(fontSize: 24, color: AppColors.textPrimaryLight),
        titleLarge: AppTextStyles.title(fontSize: 20, color: AppColors.textPrimaryLight, fontWeight: FontWeight.w600),
        titleMedium: AppTextStyles.title(fontSize: 16, color: AppColors.textPrimaryLight, fontWeight: FontWeight.w600),
        bodyLarge: AppTextStyles.body(fontSize: 16, color: AppColors.textPrimaryLight),
        bodyMedium: AppTextStyles.body(fontSize: 14, color: AppColors.textSecondaryLight),
        bodySmall: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryLight),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.bgDark,
      cardTheme: const CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: AppTextStyles.title(fontSize: 32, color: AppColors.textPrimaryDark),
        headlineMedium: AppTextStyles.title(fontSize: 24, color: AppColors.textPrimaryDark),
        titleLarge: AppTextStyles.title(fontSize: 20, color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600),
        titleMedium: AppTextStyles.title(fontSize: 16, color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600),
        bodyLarge: AppTextStyles.body(fontSize: 16, color: AppColors.textPrimaryDark),
        bodyMedium: AppTextStyles.body(fontSize: 14, color: AppColors.textSecondaryDark),
        bodySmall: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark),
      ),
    );
  }
}
