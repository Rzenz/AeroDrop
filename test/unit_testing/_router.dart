// Shared set-up for the success-path cases (CASE-106 onward): opens a screen
// inside a GoRouter so the screen can push, go to or pop back from routes.
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Text shown by the screen the tested one was opened from.
const kPreviousScreen = 'Previous screen';

/// Text shown when the tested screen opens [path].
String opened(String path) => 'Opened $path';

/// Pumps [screen] on top of a previous screen, with [destinations] it may open.
Future<void> pumpRouted(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  Size size = const Size(390, 844),
  List<String> destinations = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  AppTheme.isDarkMode = true;
  final router = GoRouter(
    initialLocation: '/screen',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Center(child: Text(kPreviousScreen))),
        routes: [GoRoute(path: 'screen', builder: (_, _) => screen)],
      ),
      for (final d in destinations)
        GoRoute(path: d, builder: (_, _) => Scaffold(body: Center(child: Text(opened(d))))),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
    ),
  );
  await tester.pump(const Duration(seconds: 2));
}
