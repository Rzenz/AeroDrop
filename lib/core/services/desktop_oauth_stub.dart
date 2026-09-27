import 'package:supabase_flutter/supabase_flutter.dart';

Future<AuthSessionUrlResponse?> signInWithGoogleDesktopImpl() async {
  throw UnsupportedError(
    'Desktop OAuth is only supported on Desktop platforms.',
  );
}
