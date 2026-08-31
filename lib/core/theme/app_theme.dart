import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// Assembles the Material theme from the design tokens.
///
/// The neumorphic depth itself lives in `AppShadows`/`NeuSurface` rather than
/// in `ThemeData`, because Material's single-value `elevation` cannot express a
/// two-light-source shadow. What this class does is make every *stock* Material
/// widget (dialogs, snackbars, sliders, switches) sit correctly on the soft
/// canvas so nothing looks imported from a different app.
class AppTheme {
  const AppTheme._();

  /// Resolved brightness, kept as a static because the token resolvers in
  /// [AppColors]/[AppTextStyles] are pure statics with no BuildContext. Set
  /// once per build in `AeroDropApp`.
  static bool isDarkMode = true;

  static ThemeData get darkTheme => _build(Brightness.dark);
  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final base = isDark ? AppColors.bgDark : AppColors.bgLight;
    final raised = isDark ? AppColors.cardDark2 : AppColors.cardLight2;
    final sunken = isDark ? AppColors.sunkenDark : AppColors.sunkenLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final textTertiary = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiaryLight;
    // Accent surfaces take the sky tone on dark and the deep brand blue on
    // light, because the sky tone only reaches 2.07:1 against the light canvas.
    final accentFill = isDark ? AppColors.accent : AppColors.primary;
    final onAccent = isDark ? AppColors.bgDark : AppColors.onBrand;

    // Inputs are debossed wells: no visible outline in the resting state, a
    // brand-coloured ring only on focus. The ring is the affordance, so it is
    // 2px and full-contrast rather than a tint.
    InputBorder outline(Color color, double width) => OutlineInputBorder(
      borderRadius: AppRadii.brMd,
      borderSide: BorderSide(color: color, width: width),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: base,
      canvasColor: base,
      splashFactory: InkSparkle.splashFactory,

      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: isDark
            ? AppColors.primaryDark
            : AppColors.primaryLight,
        onPrimaryContainer: Colors.white,
        secondary: accentFill,
        onSecondary: onAccent,
        secondaryContainer: AppColors.accentDark,
        onSecondaryContainer: onAccent,
        tertiary: AppColors.info,
        onTertiary: Colors.white,
        error: AppColors.danger,
        onError: Colors.white,
        surface: base,
        onSurface: textPrimary,
        surfaceContainerLowest: sunken,
        surfaceContainerLow: base,
        surfaceContainer: base,
        surfaceContainerHigh: raised,
        surfaceContainerHighest: raised,
        onSurfaceVariant: textSecondary,
        outline: border,
        outlineVariant: border,
        shadow: isDark
            ? AppColors.neuDarkShadowDark
            : AppColors.neuDarkShadowLight,
        inverseSurface: textPrimary,
        onInverseSurface: base,
      ),

      // Cards are drawn by NeuSurface; the Material Card is flattened so any
      // stray stock Card blends in instead of stamping a grey box.
      cardTheme: CardThemeData(
        color: base,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.brLg),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: base,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        actionsIconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: AppTextStyles.heading(fontSize: 20, color: textPrimary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: sunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTextStyles.body(fontSize: 14, color: textTertiary),
        labelStyle: AppTextStyles.label(fontSize: 13, color: textSecondary),
        floatingLabelStyle: AppTextStyles.label(
          fontSize: 13,
          color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
        ),
        errorStyle: AppTextStyles.caption(
          fontSize: 12,
          color: AppColors.danger,
          fontWeight: FontWeight.w500,
        ),
        border: outline(Colors.transparent, 0),
        enabledBorder: outline(Colors.transparent, 0),
        focusedBorder: outline(AppColors.primary, 2),
        errorBorder: outline(AppColors.danger, 1.5),
        focusedErrorBorder: outline(AppColors.danger, 2),
        disabledBorder: outline(Colors.transparent, 0),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentFill,
          foregroundColor: onAccent,
          disabledBackgroundColor: raised,
          disabledForegroundColor: textTertiary,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.brMd),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(54),
          textStyle: AppTextStyles.title(fontSize: 15, color: onAccent),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.brMd),
          minimumSize: const Size.fromHeight(54),
          textStyle: AppTextStyles.title(fontSize: 15, color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border, width: 1.5),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.brMd),
          minimumSize: const Size.fromHeight(54),
          textStyle: AppTextStyles.title(fontSize: 15, color: textPrimary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark
              ? AppColors.primaryLight
              : AppColors.primaryDark,
          textStyle: AppTextStyles.label(fontSize: 14),
          minimumSize: const Size(44, 44),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentFill,
        foregroundColor: onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.brXl),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: base,
        selectedColor: AppColors.primary,
        secondarySelectedColor: AppColors.primary,
        disabledColor: sunken,
        labelStyle: AppTextStyles.label(fontSize: 12, color: textSecondary),
        secondaryLabelStyle: AppTextStyles.label(
          fontSize: 12,
          color: Colors.white,
        ),
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.brPill),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        showCheckmark: false,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: base,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: border,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.brSheet),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: base,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.brXl),
        titleTextStyle: AppTextStyles.heading(fontSize: 20, color: textPrimary),
        contentTextStyle: AppTextStyles.body(
          fontSize: 14,
          color: textSecondary,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: raised,
        contentTextStyle: AppTextStyles.body(fontSize: 14, color: textPrimary),
        actionTextColor: isDark ? AppColors.accent : AppColors.accentOnLight,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.brMd),
      ),

      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: AppSpacing.xl,
      ),

      iconTheme: IconThemeData(color: textSecondary, size: 22),

      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        titleTextStyle: AppTextStyles.subHead(fontSize: 15),
        subtitleTextStyle: AppTextStyles.body(
          fontSize: 13,
          color: textSecondary,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.brMd),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: isDark ? AppColors.textPrimaryDark : AppColors.primaryDark,
        unselectedLabelColor: textSecondary,
        labelStyle: AppTextStyles.label(fontSize: 13),
        unselectedLabelStyle: AppTextStyles.label(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accentFill : base,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary.withValues(alpha: 0.35)
              : sunken,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: border, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.brXs),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : textTertiary,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: sunken,
        thumbColor: base,
        overlayColor: AppColors.primary.withValues(alpha: 0.12),
        trackHeight: 6,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentFill,
        linearTrackColor: sunken,
        circularTrackColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: raised, borderRadius: AppRadii.brSm),
        textStyle: AppTextStyles.body(fontSize: 12, color: textPrimary),
      ),

      // A single shared axial slide for every route push on every platform, so
      // navigation feels the same whichever shell you are in.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),

      textTheme: TextTheme(
        displayLarge: AppTextStyles.display(fontSize: 40, color: textPrimary),
        displayMedium: AppTextStyles.display(fontSize: 34, color: textPrimary),
        displaySmall: AppTextStyles.display(fontSize: 28, color: textPrimary),
        headlineLarge: AppTextStyles.heading(fontSize: 28, color: textPrimary),
        headlineMedium: AppTextStyles.heading(fontSize: 24, color: textPrimary),
        headlineSmall: AppTextStyles.heading(fontSize: 20, color: textPrimary),
        titleLarge: AppTextStyles.subHead(fontSize: 18, color: textPrimary),
        titleMedium: AppTextStyles.subHead(fontSize: 16, color: textPrimary),
        titleSmall: AppTextStyles.subHead(fontSize: 14, color: textPrimary),
        bodyLarge: AppTextStyles.body(fontSize: 16, color: textPrimary),
        bodyMedium: AppTextStyles.body(fontSize: 14, color: textSecondary),
        bodySmall: AppTextStyles.body(fontSize: 12, color: textSecondary),
        labelLarge: AppTextStyles.label(fontSize: 14, color: textPrimary),
        labelMedium: AppTextStyles.label(fontSize: 12, color: textSecondary),
        labelSmall: AppTextStyles.caption(fontSize: 11, color: textTertiary),
      ),
    );
  }
}
