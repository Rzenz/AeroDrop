import 'package:supabase_flutter/supabase_flutter.dart';

import 'desktop_oauth_stub.dart'
    if (dart.library.io) 'desktop_oauth_io.dart';

abstract class DesktopOAuth {
  /// Launches local HTTP server on port 3000, opens browser with redirect to http://localhost:3000,
  /// catches code, exchanges for session, and shuts down server.
  static Future<AuthSessionUrlResponse?> signInWithGoogleDesktop() =>
      signInWithGoogleDesktopImpl();
}
