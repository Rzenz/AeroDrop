// Screenshot harness: boots the real AeroDrop app, unmodified, against a local
// mock of the Supabase API. Signs in through the app's own AuthNotifier so the
// session is unlocked exactly as after a real login + emailed code.
//
// URL: http://localhost:PORT/?as=user|vendor|admin#/user/shop

import 'package:aerodrop/app.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _accounts = {
  'user': 'maria.santos@uclm.edu.ph',
  'vendor': 'kapekanto@uclm.edu.ph',
  'admin': 'admin.portal@uclm.edu',
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

  final container = ProviderContainer();
  final role = Uri.base.queryParameters['as'] ?? 'user';
  final signedOut = role == 'none';
  // 'otp' stops after the password step, so the app shows its real
  // emailed-code screen.
  final stopAtCode = role == 'otp';

  if (!signedOut) {
    final auth = container.read(authProvider.notifier);
    final ok = await auth.login(_accounts[stopAtCode ? 'user' : role]!, 'demo1234');
    if (ok && stopAtCode) {
      await auth.sendLoginOtp(viaSms: false);
    } else if (ok && role != 'admin') {
      await auth.verifyLoginOtp(token: '123456', viaSms: false);
    }
    debugPrint('HARNESS auth: ${container.read(authProvider).user?.email} unlocked=${container.read(authProvider).sessionUnlocked} err=${container.read(authProvider).errorMessage}');
  }

  // ?inset=1 gives the app an iPhone 14's safe areas (status bar + home
  // indicator). WidgetsApp only builds its own MediaQuery when none exists
  // above it, so this one is what the app's SafeAreas see.
  final inset = Uri.base.queryParameters['inset'] == '1';
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: inset
          ? Builder(
              builder: (context) {
                const pad = EdgeInsets.only(top: 47, bottom: 34);
                final mq = MediaQueryData.fromView(View.of(context));
                return MediaQuery(
                  data: mq.copyWith(padding: pad, viewPadding: pad),
                  child: const AeroDropApp(),
                );
              },
            )
          : const AeroDropApp(),
    ),
  );
}
