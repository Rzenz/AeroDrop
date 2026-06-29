import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    final url = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    final anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

    if (url.isEmpty || anonKey.isEmpty) {
      _initialized = false;
      return;
    }

    await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
    );

    _initialized = true;
  }

  static bool get isConfigured => _initialized;

  static SupabaseClient get client {
    if (!_initialized) throw StateError('Supabase is not initialized');
    return Supabase.instance.client;
  }
}