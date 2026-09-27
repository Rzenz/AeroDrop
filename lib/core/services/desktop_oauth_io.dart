import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'supabase_service.dart';

Future<AuthSessionUrlResponse?> signInWithGoogleDesktopImpl() async {
  if (!Platform.isWindows && !Platform.isLinux) {
    return null;
  }

  HttpServer? server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);
  } on SocketException catch (e) {
    debugPrint('Desktop OAuth server error: port 3000 is busy: $e');
    throw const AuthException(
      'Port 3000 is already in use. Please close any application using port 3000 and try again.',
    );
  } catch (e) {
    debugPrint('Desktop OAuth server bind failed: $e');
    throw AuthException('Failed to start local server on port 3000: $e');
  }

  try {
    final oAuthResponse = await SupabaseService.client.auth.getOAuthSignInUrl(
      provider: OAuthProvider.google,
      redirectTo: 'http://localhost:3000',
    );

    final uri = Uri.parse(oAuthResponse.url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw const AuthException(
        'Could not open the system browser for Google sign-in.',
      );
    }

    // Wait for the browser redirect callback on localhost:3000 with a 2-minute timeout
    HttpRequest request;
    try {
      request = await server.first.timeout(const Duration(seconds: 120));
    } on TimeoutException {
      throw const AuthException(
        'Google sign-in timed out or was closed in the browser.',
      );
    }

    final queryParams = request.uri.queryParameters;
    final code = queryParams['code'];
    final error = queryParams['error'];
    final errorDescription = queryParams['error_description'];

    request.response.headers.contentType = ContentType.html;

    if (code != null) {
      request.response.write('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>AeroDrop - Sign In Successful</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0A0D14; color: #FFFFFF; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
    .card { background: #131823; border: 1px solid #1E2638; border-radius: 16px; padding: 32px 40px; text-align: center; max-width: 400px; box-shadow: 0 12px 32px rgba(0,0,0,0.4); }
    h1 { font-size: 20px; font-weight: 700; color: #10B981; margin: 0 0 8px; }
    p { font-size: 14px; color: #94A3B8; margin: 0; }
  </style>
</head>
<body>
  <div class="card">
    <h1>✓ Signed in to AeroDrop</h1>
    <p>You can close this window and return to the application.</p>
  </div>
</body>
</html>
''');
      await request.response.close();

      // Exchange the authorization code for a real Supabase session
      final authResponse = await SupabaseService.client.auth.exchangeCodeForSession(
        code,
      );
      return authResponse;
    } else {
      request.response.write('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>AeroDrop - Sign In Failed</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0A0D14; color: #FFFFFF; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
    .card { background: #131823; border: 1px solid #1E2638; border-radius: 16px; padding: 32px 40px; text-align: center; max-width: 400px; box-shadow: 0 12px 32px rgba(0,0,0,0.4); }
    h1 { font-size: 20px; font-weight: 700; color: #EF4444; margin: 0 0 8px; }
    p { font-size: 14px; color: #94A3B8; margin: 0; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Sign In Failed</h1>
    <p>${errorDescription ?? error ?? 'Google sign-in was cancelled.'}</p>
  </div>
</body>
</html>
''');
      await request.response.close();

      if (error != null) {
        throw AuthException(errorDescription ?? error);
      }
      throw const AuthException('Google sign-in was cancelled.');
    }
  } finally {
    await server.close(force: true);
  }
}
