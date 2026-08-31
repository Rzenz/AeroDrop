import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/router/app_router.dart';
import 'core/providers/settings_provider.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';

class AeroDropApp extends ConsumerWidget {
  const AeroDropApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // The design tokens resolve through this static because they are plain
    // statics with no BuildContext. Depend on platformBrightness specifically
    // rather than the whole MediaQuery, so an unrelated metric change (the
    // keyboard opening, a rotation) does not rebuild the entire app.
    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    AppTheme.isDarkMode = isDark;

    // Match the system bars to the canvas so the app reads edge to edge.
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? AppColors.bgDark : AppColors.bgLight,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return MaterialApp.router(
      title: 'AeroDrop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // Cap text scaling: the design holds up to 1.6x, beyond which fixed
        // chrome like the nav dock starts to lose its labels. Users who need
        // more still get it — this only bounds the runaway end of the range.
        final scaler = MediaQuery.textScalerOf(
          context,
        ).clamp(minScaleFactor: 0.85, maxScaleFactor: 1.6);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
