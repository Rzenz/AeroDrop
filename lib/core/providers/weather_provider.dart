import 'dart:async';
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
  final double? windGusts;
  final double? precipitation;
  final int? weatherCode;
  final double? visibility;
  final String safetyStatus; // 'safe' | 'caution' | 'grounded'
  final String? message;
  final DateTime? updatedAt;
  final DateTime? lastFetchedAt;
  final String? lastFetchError;
  final String? realSafetyStatus;
  final String? realCondition;
  final String? realMessage;
  final double? simulatedTemperature;
  final double? simulatedWindSpeed;
  final String? simulatedCondition;
  final String? simulatedMessage;
  final String? overrideStatus;
  final DateTime? overrideUntil;
  final String? overrideBy;
  final bool isLoading;
  final String? errorMessage;

  const WeatherState({
    this.id,
    this.condition,
    this.temperature,
    this.windSpeed,
    this.windGusts,
    this.precipitation,
    this.weatherCode,
    this.visibility,
    this.safetyStatus = 'grounded',
    this.message,
    this.updatedAt,
    this.lastFetchedAt,
    this.lastFetchError,
    this.realSafetyStatus,
    this.realCondition,
    this.realMessage,
    this.simulatedTemperature,
    this.simulatedWindSpeed,
    this.simulatedCondition,
    this.simulatedMessage,
    this.overrideStatus,
    this.overrideUntil,
    this.overrideBy,
    this.isLoading = false,
    this.errorMessage,
  });

  WeatherState copyWith({
    String? id,
    String? condition,
    double? temperature,
    double? windSpeed,
    double? windGusts,
    double? precipitation,
    int? weatherCode,
    double? visibility,
    String? safetyStatus,
    String? message,
    DateTime? updatedAt,
    DateTime? lastFetchedAt,
    String? lastFetchError,
    String? realSafetyStatus,
    String? realCondition,
    String? realMessage,
    double? simulatedTemperature,
    double? simulatedWindSpeed,
    String? simulatedCondition,
    String? simulatedMessage,
    String? overrideStatus,
    DateTime? overrideUntil,
    String? overrideBy,
    bool? isLoading,
    String? errorMessage,
  }) => WeatherState(
    id: id ?? this.id,
    condition: condition ?? this.condition,
    temperature: temperature ?? this.temperature,
    windSpeed: windSpeed ?? this.windSpeed,
    windGusts: windGusts ?? this.windGusts,
    precipitation: precipitation ?? this.precipitation,
    weatherCode: weatherCode ?? this.weatherCode,
    visibility: visibility ?? this.visibility,
    safetyStatus: safetyStatus ?? this.safetyStatus,
    message: message ?? this.message,
    updatedAt: updatedAt ?? this.updatedAt,
    lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
    lastFetchError: lastFetchError ?? this.lastFetchError,
    realSafetyStatus: realSafetyStatus ?? this.realSafetyStatus,
    realCondition: realCondition ?? this.realCondition,
    realMessage: realMessage ?? this.realMessage,
    simulatedTemperature: simulatedTemperature ?? this.simulatedTemperature,
    simulatedWindSpeed: simulatedWindSpeed ?? this.simulatedWindSpeed,
    simulatedCondition: simulatedCondition ?? this.simulatedCondition,
    simulatedMessage: simulatedMessage ?? this.simulatedMessage,
    overrideStatus: overrideStatus ?? this.overrideStatus,
    overrideUntil: overrideUntil ?? this.overrideUntil,
    overrideBy: overrideBy ?? this.overrideBy,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: errorMessage,
  );

  factory WeatherState.fromMap(Map<String, dynamic> row) {
    return WeatherState(
      id: row['id'] as String?,
      condition: row['condition'] as String?,
      temperature: (row['temperature'] as num?)?.toDouble(),
      windSpeed: (row['wind_speed'] as num?)?.toDouble(),
      windGusts: (row['wind_gusts'] as num?)?.toDouble(),
      precipitation: (row['precipitation'] as num?)?.toDouble(),
      weatherCode: (row['weather_code'] as num?)?.toInt(),
      visibility: (row['visibility'] as num?)?.toDouble(),
      safetyStatus: row['safety_status']?.toString() ?? 'grounded',
      message: row['message'] as String?,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'].toString())
          : null,
      lastFetchedAt: row['last_fetched_at'] != null
          ? DateTime.tryParse(row['last_fetched_at'].toString())
          : null,
      lastFetchError: row['last_fetch_error'] as String?,
      realSafetyStatus: row['real_safety_status'] as String?,
      realCondition: row['real_condition'] as String?,
      realMessage: row['real_message'] as String?,
      simulatedTemperature: (row['simulated_temperature'] as num?)?.toDouble(),
      simulatedWindSpeed: (row['simulated_wind_speed'] as num?)?.toDouble(),
      simulatedCondition: row['simulated_condition'] as String?,
      simulatedMessage: row['simulated_message'] as String?,
      overrideStatus: row['override_status'] as String?,
      overrideUntil: row['override_until'] != null
          ? DateTime.tryParse(row['override_until'].toString())
          : null,
      overrideBy: row['override_by'] as String?,
      isLoading: false,
      errorMessage: null,
    );
  }

  // Getters for backward compatibility with screens using old fields
  String get weatherStatus => safetyStatus;
  String get advisoryMessage => message ?? 'No weather record configured.';
  bool get dispatchEnabled => safetyStatus != 'grounded';
  int get delayMinutes => safetyStatus == 'caution' ? 5 : 0;

  bool get isGrounded => safetyStatus == 'grounded';
  bool get isCaution => safetyStatus == 'caution';
  bool get isSafe => safetyStatus == 'safe';

  // Live weather & Override helpers
  bool get isOverrideActive =>
      overrideUntil != null && overrideUntil!.toUtc().isAfter(DateTime.now().toUtc());

  String get overrideRemainingText {
    if (!isOverrideActive) return '';
    final diff = overrideUntil!.toUtc().difference(DateTime.now().toUtc());
    if (diff.isNegative) return 'expiring now';
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m left';
    }
    return '${mins}m left';
  }

  String get temperatureDisplay =>
      temperature != null ? "${temperature!.toStringAsFixed(1)}°C" : 'N/A';

  String get windDisplay {
    if (windSpeed == null) return 'N/A';
    final speed = "${windSpeed!.toStringAsFixed(1)} km/h";
    if (windGusts != null && windGusts! > windSpeed!) {
      return "$speed (gusts ${windGusts!.toStringAsFixed(1)} km/h)";
    }
    return speed;
  }

  String get lastUpdatedText {
    final dt = lastFetchedAt ?? updatedAt;
    if (dt == null) return 'Awaiting sync';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return 'Updated $m ${m == 1 ? 'minute' : 'minutes'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return 'Updated $h ${h == 1 ? 'hour' : 'hours'} ago';
    }
    return 'Updated ${diff.inDays}d ago';
  }

  bool get isDataStale {
    if (lastFetchError != null && lastFetchError!.trim().isNotEmpty) {
      return true;
    }
    if (lastFetchedAt == null) return false;
    final diff = DateTime.now().toUtc().difference(lastFetchedAt!.toUtc());
    return diff.inMinutes >= 45;
  }

  String? get staleWarningMessage {
    if (lastFetchError != null && lastFetchError!.trim().isNotEmpty) {
      return 'Weather sync warning: $lastFetchError';
    }
    if (lastFetchedAt != null) {
      final diff = DateTime.now().toUtc().difference(lastFetchedAt!.toUtc());
      if (diff.inMinutes >= 45) {
        return 'Weather data may be out of date (last fetched ${diff.inMinutes} minutes ago)';
      }
    }
    return null;
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class WeatherNotifier extends StateNotifier<WeatherState> {
  final Ref ref;
  RealtimeChannel? _realtimeChannel;
  Timer? _pollTimer;

  WeatherNotifier(this.ref) : super(const WeatherState()) {
    loadWeatherSafety();
    _initLiveSync();
  }

  void _initLiveSync() {
    if (!SupabaseService.isConfigured) return;

    try {
      _realtimeChannel = SupabaseService.client
          .channel('public:weather_safety')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'weather_safety',
            callback: (payload) {
              if (mounted) {
                loadWeatherSafety(isSilent: true);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('WeatherNotifier realtime subscription error: $e');
    }

    // Polling fallback every 30 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        loadWeatherSafety(isSilent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_realtimeChannel != null && SupabaseService.isConfigured) {
      SupabaseService.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  Future<void> loadWeatherSafety({bool isSilent = false}) async {
    if (!SupabaseService.isConfigured) return;
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser == null) {
      if (!mounted) return;
      state = const WeatherState(
        safetyStatus: 'grounded',
        message: 'No authenticated user session.',
      );
      return;
    }
    if (!mounted) return;
    if (!isSilent) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

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

      state = WeatherState.fromMap(row);
    } catch (e) {
      debugPrint('WeatherNotifier.loadWeatherSafety failed: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
          safetyStatus: state.id != null ? state.safetyStatus : 'grounded',
          message: state.id != null ? state.message : 'Unable to load campus weather.',
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

  Future<bool> setSimulatedWeather(
    String selectedStatus, {
    double durationHours = 2.0,
  }) async {
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
        params: {
          'p_safety_status': selectedStatus,
          'p_duration_hours': durationHours,
        },
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

      state = WeatherState.fromMap(row);
      return true;
    } on PostgrestException catch (e) {
      debugPrint('WeatherNotifier.setSimulatedWeather PostgrestException: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to update weather: ${e.message}',
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

  Future<bool> clearWeatherOverride() async {
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
      final response = await Supabase.instance.client.rpc('clear_weather_override');
      if (!mounted) return false;

      final Map<String, dynamic> row;
      if (response is List && response.isNotEmpty) {
        row = Map<String, dynamic>.from(response.first as Map);
      } else if (response is Map) {
        row = Map<String, dynamic>.from(response);
      } else {
        throw Exception('clear_weather_override returned an invalid response.');
      }

      state = WeatherState.fromMap(row);
      return true;
    } on PostgrestException catch (e) {
      debugPrint('WeatherNotifier.clearWeatherOverride PostgrestException: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to clear override: ${e.message}',
        );
      }
      rethrow;
    } catch (e) {
      debugPrint('WeatherNotifier.clearWeatherOverride failed: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to clear weather override.',
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
