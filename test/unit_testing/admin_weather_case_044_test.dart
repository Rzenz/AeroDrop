import 'package:aerodrop/core/providers/weather_provider.dart';
import 'package:aerodrop/features/admin/admin_weather_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fakes.dart';
import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-044', () {
    testWidgets(
      'Test Case Description: Admin opens Campus Weather Controls while live weather is safe (30.4 C, partly cloudy) | '
      'Expected Result: The live reading shows SAFE with the condition, and the SAFE / CAUTION / GROUNDED dispatch options are offered',
      (tester) async {
        expect(safeWeather().isGrounded, isFalse);
        expect(safeWeather().isCaution, isFalse);

        await pumpScreen(
          tester,
          const AdminWeatherScreen(),
          overrides: [weatherProvider.overrideWith((ref) => FakeWeather(safeWeather()))],
          size: const Size(600, 1600),
        );

        expect(find.textContaining('Partly cloudy'), findsWidgets);
        expect(find.text('SAFE'), findsWidgets);
        expect(find.text('CAUTION'), findsOneWidget);
        expect(find.text('GROUNDED'), findsOneWidget);
      },
    );
  });
}
