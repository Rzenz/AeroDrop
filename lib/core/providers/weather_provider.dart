import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class WeatherState {
  final String? id;
  final String? condition;
  final double? temperature;
  final double? windSpeed;
  final String safetyStatus; // 'safe' | 'caution' | 'grounded'
  final String? message;
  final DateTime? updatedAt;
  final bool isLoading;
  final String? errorMessage;

  const WeatherState({
    this.id,
    this.condition,
    this.temperature,
    this.windSpeed,
    this.safetyStatus = 'grounded',
    this.message,
    this.updatedAt,
    this.isLoading = false,
    this.errorMessage,
  });

  WeatherState copyWith({
    String? id,
    String? condition,
    double? temperature,
    double? windSpeed,
    String? safetyStatus,
    String? message,
    DateTime? updatedAt,
    bool? isLoading,
    String? errorMessage,
  }) => WeatherState(
    id: id ?? this.id,
    condition: condition ?? this.condition,
    temperature: temperature ?? this.temperature,
    windSpeed: windSpeed ?? this.windSpeed,
    safetyStatus: safetyStatus ?? this.safetyStatus,
    message: message ?? this.message,
    updatedAt: updatedAt ?? this.updatedAt,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: errorMessage,
  );

  // Getters for backward compatibility with screens using old fields
  String get weatherStatus => safetyStatus;
  String get advisoryMessage => message ?? 'No weather record configured.';
  bool get dispatchEnabled => safetyStatus != 'grounded';
  int get delayMinutes => safetyStatus == 'caution' ? 5 : 0;

  bool get isGrounded => safetyStatus == 'grounded';
  bool get isCaution => safetyStatus == 'caution';
  bool get isSafe => safetyStatus == 'safe';
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class WeatherNotifier extends StateNotifier<WeatherState> {
  final Ref ref;
  WeatherNotifier(this.ref) : super(const WeatherState()) {
    loadWeatherSafety();
  }

  Future<void> loadWeatherSafety() async {
    if (!SupabaseService.isConfigured) return;
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser == null) {
      state = const WeatherState(
        safetyStatus: 'grounded',
        message: 'No authenticated user session.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final row = await SupabaseService.client
          .from('weather_safety')
          .select()
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;
      if (row == null) {
        state = const WeatherState(
          id: null,
          condition: null,
          temperature: null,
          windSpeed: null,
          safetyStatus: 'grounded',
          message: 'No weather record configured.',
          updatedAt: null,
          isLoading: false,
        );
        return;
      }

      state = WeatherState(
        id: row['id'] as String?,
        condition: row['condition'] as String?,
        temperature: row['temperature'] != null
            ? (row['temperature'] as num).toDouble()
            : null,
        windSpeed: row['wind_speed'] != null
            ? (row['wind_speed'] as num).toDouble()
            : null,
        safetyStatus: row['safety_status']?.toString() ?? 'grounded',
        message: row['message'] as String?,
        updatedAt: row['updated_at'] != null
            ? DateTime.parse(row['updated_at'] as String)
            : null,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('WeatherNotifier.loadWeatherSafety failed: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
          safetyStatus: 'grounded',
          message: 'Unable to load campus weather.',
        );
      }
    }
  }

  Future<String?> updateWeatherStatus(String status) async {
    // Legacy helper to support basic triggers
    return updateFullWeather(
      safetyStatus: status,
      condition: status == 'safe'
          ? 'Clear Skies'
          : (status == 'caution' ? 'High Winds' : 'Heavy Rain'),
      temperature: status == 'safe'
          ? 30.0
          : (status == 'caution' ? 32.0 : 22.0),
      windSpeed: status == 'safe' ? 10.0 : (status == 'caution' ? 28.0 : 40.0),
      message: status == 'safe'
          ? 'Weather conditions are safe for campus drone dispatch.'
          : (status == 'caution'
                ? 'Delivery may be delayed due to caution-level weather conditions.'
                : 'Weather is currently unsafe for drone delivery. Please try again later.'),
    );
  }

  Future<String?> updateFullWeather({
    required String safetyStatus,
    String? condition,
    double? temperature,
    double? windSpeed,
    String? message,
  }) async {
    if (!{'safe', 'caution', 'grounded'}.contains(safetyStatus)) {
      return 'Invalid weather status: $safetyStatus';
    }
    if (!SupabaseService.isConfigured) return 'Supabase not configured.';

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final latest = await SupabaseService.client
          .from('weather_safety')
          .select('id')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final payload = {
        'safety_status': safetyStatus,
        'condition': condition,
        'temperature': temperature,
        'wind_speed': windSpeed,
        'message': message,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      Map<String, dynamic> returnedRow;

      if (latest == null) {
        final res = await SupabaseService.client
            .from('weather_safety')
            .insert(payload)
            .select()
            .single();
        returnedRow = res;
      } else {
        final res = await SupabaseService.client
            .from('weather_safety')
            .update(payload)
            .eq('id', latest['id'])
            .select()
            .single();
        returnedRow = res;
      }

      // Verify returned status
      final returnedStatus = returnedRow['safety_status']?.toString();
      if (returnedStatus != safetyStatus) {
        throw Exception('safety_status mismatch in returned database row.');
      }

      await loadWeatherSafety();
      return null;
    } catch (e) {
      debugPrint('WeatherNotifier.updateFullWeather failed: $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
      return 'Failed to update weather: $e';
    }
  }

  Future<bool> setSimulatedWeather(String selectedStatus) async {
    if (!{'safe', 'caution', 'grounded'}.contains(selectedStatus)) {
      if (mounted) {
        state = state.copyWith(
          errorMessage: 'Invalid weather status: $selectedStatus',
        );
      }
      return false;
    }
    if (!SupabaseService.isConfigured) {
      if (mounted) {
        state = state.copyWith(errorMessage: 'Supabase not configured.');
      }
      return false;
    }

    if (mounted) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }
    try {
      final response = await Supabase.instance.client.rpc(
        'set_simulated_weather',
        params: {'p_safety_status': selectedStatus},
      );

      if (!mounted) return false;

      final Map<String, dynamic> row;
      if (response is List && response.isNotEmpty) {
        row = Map<String, dynamic>.from(response.first as Map);
      } else if (response is Map) {
        row = Map<String, dynamic>.from(response);
      } else {
        throw Exception('Weather RPC returned an invalid response.');
      }

      final returnedStatus = row['safety_status']?.toString();
      if (returnedStatus != selectedStatus) {
        throw Exception('Returned weather status does not match.');
      }

      state = WeatherState(
        id: row['id'] as String?,
        condition: row['condition'] as String?,
        temperature: row['temperature'] != null
            ? (row['temperature'] as num).toDouble()
            : null,
        windSpeed: row['wind_speed'] != null
            ? (row['wind_speed'] as num).toDouble()
            : null,
        safetyStatus: returnedStatus ?? 'grounded',
        message: row['message'] as String?,
        updatedAt: row['updated_at'] != null
            ? DateTime.parse(row['updated_at'] as String)
            : null,
        isLoading: false,
      );

      return true;
    } on PostgrestException catch (e) {
      debugPrint('WeatherNotifier.setSimulatedWeather PostgrestException: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to update weather.',
        );
      }
      rethrow;
    } catch (e) {
      debugPrint('WeatherNotifier.setSimulatedWeather failed: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to update weather.',
        );
      }
      rethrow;
    }
  }
}

final weatherProvider = StateNotifierProvider<WeatherNotifier, WeatherState>(
  (ref) => WeatherNotifier(ref),
);

enum WeatherStatus { safe, caution, grounded }

extension WeatherStateExt on WeatherState {
  WeatherStatus get status => switch (safetyStatus) {
    'caution' => WeatherStatus.caution,
    'grounded' => WeatherStatus.grounded,
    _ => WeatherStatus.safe,
  };
}
