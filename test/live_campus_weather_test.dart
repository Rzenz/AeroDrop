import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerodrop/core/providers/weather_provider.dart';
import 'package:aerodrop/features/dashboard/user_dashboard_screen.dart';
import 'package:aerodrop/features/admin/admin_weather_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Migration 15: Live Campus Weather Model & Formatting Tests', () {
    test('WeatherState.fromMap correctly parses all live and override columns', () {
      final now = DateTime.now().toUtc();
      final map = {
        'id': 'w-123',
        'safety_status': 'caution',
        'condition': 'Breezy & Light Rain',
        'message': 'Deliveries delayed by 5 mins.',
        'temperature': 28.5,
        'wind_speed': 18.2,
        'wind_gusts': 31.4,
        'precipitation': 0.2,
        'weather_code': 51,
        'visibility': 8500.0,
        'last_fetched_at': now.subtract(const Duration(minutes: 5)).toIso8601String(),
        'last_fetch_error': null,
        'real_safety_status': 'caution',
        'real_condition': 'Light Rain',
        'real_message': 'Campus drizzle.',
        'simulated_temperature': null,
        'simulated_wind_speed': null,
        'simulated_condition': null,
        'simulated_message': null,
        'override_status': null,
        'override_until': null,
        'override_by': null,
        'updated_at': now.toIso8601String(),
      };

      final state = WeatherState.fromMap(map);
      expect(state.id, 'w-123');
      expect(state.safetyStatus, 'caution');
      expect(state.temperature, 28.5);
      expect(state.windSpeed, 18.2);
      expect(state.windGusts, 31.4);
      expect(state.precipitation, 0.2);
      expect(state.weatherCode, 51);
      expect(state.visibility, 8500.0);
      expect(state.realSafetyStatus, 'caution');
      expect(state.isOverrideActive, isFalse);
    });

    test('windDisplay formats speed with gusts only when gusts > windSpeed', () {
      const normalWind = WeatherState(
        windSpeed: 10.5,
        windGusts: 9.0,
      );
      expect(normalWind.windDisplay, '10.5 km/h');

      const gustyWind = WeatherState(
        windSpeed: 14.0,
        windGusts: 28.4,
      );
      expect(gustyWind.windDisplay, '14.0 km/h (gusts 28.4 km/h)');

      const noGusts = WeatherState(
        windSpeed: 8.2,
        windGusts: null,
      );
      expect(noGusts.windDisplay, '8.2 km/h');
    });

    test('lastUpdatedText formats relative time correctly', () {
      final now = DateTime.now();

      final justNow = WeatherState(
        lastFetchedAt: now.subtract(const Duration(seconds: 25)),
      );
      expect(justNow.lastUpdatedText, 'Updated just now');

      final tenMinsAgo = WeatherState(
        lastFetchedAt: now.subtract(const Duration(minutes: 10)),
      );
      expect(tenMinsAgo.lastUpdatedText, 'Updated 10 minutes ago');

      final twoHoursAgo = WeatherState(
        lastFetchedAt: now.subtract(const Duration(hours: 2)),
      );
      expect(twoHoursAgo.lastUpdatedText, 'Updated 2 hours ago');
    });

    test('isDataStale triggers on fetch error or when > 45 minutes old', () {
      final now = DateTime.now();

      final fresh = WeatherState(
        lastFetchedAt: now.subtract(const Duration(minutes: 15)),
        lastFetchError: null,
      );
      expect(fresh.isDataStale, isFalse);
      expect(fresh.staleWarningMessage, isNull);

      final staleTime = WeatherState(
        lastFetchedAt: now.subtract(const Duration(minutes: 50)),
        lastFetchError: null,
      );
      expect(staleTime.isDataStale, isTrue);
      expect(staleTime.staleWarningMessage, contains('50 minutes ago'));

      final errorWeather = WeatherState(
        lastFetchedAt: now.subtract(const Duration(minutes: 10)),
        lastFetchError: 'HTTP 503 Service Unavailable',
      );
      expect(errorWeather.isDataStale, isTrue);
      expect(errorWeather.staleWarningMessage, contains('HTTP 503'));
    });

    test('isOverrideActive and overrideRemainingText detect active overrides', () {
      final now = DateTime.now();

      final activeOverride = WeatherState(
        safetyStatus: 'grounded',
        overrideStatus: 'grounded',
        overrideUntil: now.add(const Duration(hours: 1, minutes: 30, seconds: 5)),
      );
      expect(activeOverride.isOverrideActive, isTrue);
      expect(activeOverride.overrideRemainingText, '1h 30m left');

      final expiredOverride = WeatherState(
        safetyStatus: 'safe',
        overrideStatus: 'grounded',
        overrideUntil: now.subtract(const Duration(minutes: 5)),
      );
      expect(expiredOverride.isOverrideActive, isFalse);
    });
  });

  group('Migration 15: Widget UI Tests', () {
    testWidgets('AeroDropWeatherWidget renders live telemetry and does NOT reveal override', (tester) async {
      final weather = WeatherState(
        id: 'w-1',
        safetyStatus: 'caution',
        condition: 'Breezy Showers',
        temperature: 29.4,
        windSpeed: 16.5,
        windGusts: 27.0,
        lastFetchedAt: DateTime.now().subtract(const Duration(minutes: 8)),
        overrideStatus: 'caution',
        overrideUntil: DateTime.now().add(const Duration(hours: 2)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weatherProvider.overrideWith((ref) => _MockWeatherNotifier(weather)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AeroDropWeatherWidget(),
            ),
          ),
        ),
      );

      // Verify status badge
      expect(find.text('CAUTION'), findsOneWidget);
      // Verify condition and temperature
      expect(find.text('29.4°C'), findsOneWidget);
      expect(find.text('Breezy Showers'), findsOneWidget);
      // Verify wind & gusts
      expect(find.text('16.5 km/h (gusts 27.0 km/h)'), findsOneWidget);
      // Verify relative updated text
      expect(find.text('Updated 8 minutes ago'), findsOneWidget);
      // Verify that override information is NOT visible to customers/vendors
      expect(find.textContaining('OVERRIDE'), findsNothing);
      expect(find.textContaining('Manual:'), findsNothing);
    });

    testWidgets('AdminWeatherScreen renders Manual override, REAL conditions, and Resume Live button', (tester) async {
      final weather = WeatherState(
        id: 'w-1',
        safetyStatus: 'grounded',
        condition: 'Heavy Rain (Simulated)',
        temperature: 22.0,
        windSpeed: 40.0,
        windGusts: 40.0,
        realSafetyStatus: 'safe',
        realCondition: 'Clear Sky',
        lastFetchedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        overrideStatus: 'grounded',
        overrideUntil: DateTime.now().add(const Duration(hours: 1, minutes: 45)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weatherProvider.overrideWith((ref) => _MockWeatherNotifier(weather)),
          ],
          child: const MaterialApp(
            home: AdminWeatherScreen(),
          ),
        ),
      );

      // Verify Override indicator on Admin screen
      expect(find.text('OVERRIDE ACTIVE'), findsOneWidget);
      expect(find.textContaining('Manual: GROUNDED'), findsOneWidget);
      expect(find.textContaining('left'), findsWidgets);

      // Verify REAL conditions are visible underneath
      expect(find.text('ACTUAL CAMPUS WEATHER'), findsOneWidget);
      expect(find.textContaining('SAFE • Clear Sky'), findsOneWidget);

      // Verify Resume Live Weather button is present
      expect(find.text('Resume Live Weather'), findsOneWidget);
    });

    testWidgets('AdminWeatherScreen renders data stale warning note when stale', (tester) async {
      final weather = WeatherState(
        id: 'w-1',
        safetyStatus: 'safe',
        condition: 'Clear Sky',
        temperature: 30.0,
        windSpeed: 10.0,
        lastFetchedAt: DateTime.now().subtract(const Duration(minutes: 55)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weatherProvider.overrideWith((ref) => _MockWeatherNotifier(weather)),
          ],
          child: const MaterialApp(
            home: AdminWeatherScreen(),
          ),
        ),
      );

      // Verify stale warning is shown
      expect(find.textContaining('Weather data may be out of date'), findsOneWidget);
      // Verify override is NOT active
      expect(find.text('LIVE TELEMETRY'), findsOneWidget);
      expect(find.text('OVERRIDE ACTIVE'), findsNothing);
    });
  });
}

class _MockWeatherNotifier extends WeatherNotifier {
  _MockWeatherNotifier(WeatherState initial) : super(_DummyRef()) {
    state = initial;
  }

  @override
  Future<void> loadWeatherSafety({bool isSilent = false}) async {}
}

class _DummyRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
