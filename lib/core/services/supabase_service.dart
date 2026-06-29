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
<<<<<<< HEAD
      publishableKey: anonKey,
=======
      anonKey: anonKey,
>>>>>>> 5b6b7b1e3cbcc6cfb4e7ffb4cce8b6e56b3d0c51
    );

    _initialized = true;
  }

  static bool get isConfigured => _initialized;

  static SupabaseClient get client {
    if (!_initialized) throw StateError('Supabase is not initialized');
    return Supabase.instance.client;
  }
}