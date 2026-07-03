import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class WeatherState {
  final String weatherStatus; // 'safe' | 'caution' | 'grounded'
  final String advisoryMessage;
  final bool dispatchEnabled;
  final int delayMinutes;
  final bool isLoading;
  final String? errorMessage;

  const WeatherState({
    this.weatherStatus = 'safe',
    this.advisoryMessage =
        'Weather conditions are safe for campus drone dispatch.',
    this.dispatchEnabled = true,
    this.delayMinutes = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  WeatherState copyWith({
    String? weatherStatus,
    String? advisoryMessage,
    bool? dispatchEnabled,
    int? delayMinutes,
    bool? isLoading,
    String? errorMessage,
  }) =>
      WeatherState(
        weatherStatus: weatherStatus ?? this.weatherStatus,
        advisoryMessage: advisoryMessage ?? this.advisoryMessage,
        dispatchEnabled: dispatchEnabled ?? this.dispatchEnabled,
        delayMinutes: delayMinutes ?? this.delayMinutes,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );

  /// Convenience: is weather grounded?
  bool get isGrounded =>
      weatherStatus == 'grounded' || !dispatchEnabled;

  /// Convenience: is weather in caution?
  bool get isCaution => weatherStatus == 'caution';

  /// Convenience: is weather safe?
  bool get isSafe => weatherStatus == 'safe' && dispatchEnabled;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class WeatherNotifier extends StateNotifier<WeatherState> {
  WeatherNotifier() : super(const WeatherState()) {
    loadWeatherSafety();
  }

  // ---------------------------------------------------------------------------
  // DB mappings per status
  // ---------------------------------------------------------------------------
  static const _safePayload = {
    'weather_status': 'safe',
    'dispatch_enabled': true,
    'delay_minutes': 0,
    'advisory_message':
        'Weather conditions are safe for campus drone dispatch.',
  };
  static const _cautionPayload = {
    'weather_status': 'caution',
    'dispatch_enabled': true,
    'delay_minutes': 5,
    'advisory_message':
        'Delivery may be delayed due to caution-level weather conditions.',
  };
  static const _groundedPayload = {
    'weather_status': 'grounded',
    'dispatch_enabled': false,
    'delay_minutes': 0,
    'advisory_message':
        'Weather is currently unsafe for drone delivery. Please try again later.',
  };

  static Map<String, Object> _payloadFor(String status) => switch (status) {
        'caution' => _cautionPayload,
        'grounded' => _groundedPayload,
        _ => _safePayload, // default → safe
      };

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  Future<void> loadWeatherSafety() async {
    if (!SupabaseService.isConfigured) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final row = await SupabaseService.client
          .from('weather_safety')
          .select()
          .eq('id', 1)
          .maybeSingle();

      if (row != null) {
        state = state.copyWith(
          weatherStatus: row['weather_status']?.toString() ?? 'safe',
          advisoryMessage: row['advisory_message']?.toString() ??
              'Weather conditions are safe for campus drone dispatch.',
          dispatchEnabled: row['dispatch_enabled'] == true,
          delayMinutes:
              int.tryParse(row['delay_minutes']?.toString() ?? '0') ?? 0,
          isLoading: false,
        );
      } else {
        // Row not found — use safe defaults
        state = const WeatherState();
      }
    } catch (e) {
      debugPrint('WeatherNotifier.loadWeatherSafety failed: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  /// Returns null on success, error string on failure. Never throws.
  Future<String?> updateWeatherStatus(String status) async {
    if (!{'safe', 'caution', 'grounded'}.contains(status)) {
      return 'Invalid weather status: $status';
    }
    if (!SupabaseService.isConfigured) return 'Supabase not configured.';

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final payload = _payloadFor(status);
      await SupabaseService.client
          .from('weather_safety')
          .update(payload)
          .eq('id', 1);

      // Optimistically apply immediately so UI rebuilds right away
      state = state.copyWith(
        weatherStatus: status,
        advisoryMessage: payload['advisory_message'] as String,
        dispatchEnabled: payload['dispatch_enabled'] as bool,
        delayMinutes: payload['delay_minutes'] as int,
        isLoading: false,
      );

      // Then reload from DB to confirm
      await loadWeatherSafety();
      return null;
    } catch (e) {
      debugPrint('WeatherNotifier.updateWeatherStatus failed: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return 'Failed to update weather: $e';
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final weatherProvider =
    StateNotifierProvider<WeatherNotifier, WeatherState>(
        (_) => WeatherNotifier());

// ---------------------------------------------------------------------------
// Legacy enum kept for any existing switch() in widget layer
// ---------------------------------------------------------------------------

enum WeatherStatus { safe, caution, grounded }

extension WeatherStateExt on WeatherState {
  WeatherStatus get status => switch (weatherStatus) {
        'caution' => WeatherStatus.caution,
        'grounded' => WeatherStatus.grounded,
        _ => WeatherStatus.safe,
      };
}
