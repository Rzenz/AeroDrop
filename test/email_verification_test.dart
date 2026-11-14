import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/core/widgets/verify_email_banner.dart';

const _longEmail =
    'an.extraordinarily.long.student.address@student.uclm.edu.ph';

Map<String, dynamic> _row({
  String role = 'user',
  bool withColumn = true,
  String? verifiedAt,
}) => {
  'id': 'u1',
  'email': _longEmail,
  'full_name': 'Test Customer',
  'role': role,
  'vendor_status': role == 'vendor' ? 'active' : null,
  if (withColumn) 'email_verified_at': verifiedAt,
};

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth(AeroDropUser user)
    : super(AuthState(user: user, isVerified: true, sessionUnlocked: true));
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<bool>.value(false);
}

void main() {
  group('needsEmailVerification', () {
    test('an unverified customer or vendor needs it', () {
      expect(AeroDropUser.fromMap(_row()).needsEmailVerification, isTrue);
      expect(
        AeroDropUser.fromMap(_row(role: 'vendor')).needsEmailVerification,
        isTrue,
      );
    });

    test('a verified account does not', () {
      final u = AeroDropUser.fromMap(_row(verifiedAt: '2026-11-14T02:00:00Z'));
      expect(u.needsEmailVerification, isFalse);
      expect(u.emailVerifiedAt, isNotNull);
    });

    test('admins are exempt', () {
      expect(
        AeroDropUser.fromMap(_row(role: 'admin')).needsEmailVerification,
        isFalse,
      );
    });

    test('a missing column (migration 35 not applied) blocks nobody', () {
      final u = AeroDropUser.fromMap(_row(withColumn: false));
      expect(u.emailVerificationKnown, isFalse);
      expect(u.needsEmailVerification, isFalse);
    });

    test('copyWith keeps both fields', () {
      final u = AeroDropUser.fromMap(_row()).copyWith(fullName: 'Renamed');
      expect(u.emailVerificationKnown, isTrue);
      expect(u.needsEmailVerification, isTrue);
    });
  });

  const sizes = {'360dp': Size(360, 740), 'desktop': Size(1366, 768)};

  Future<void> pump(WidgetTester tester, Size size, AeroDropUser user) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    AppTheme.isDarkMode = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith((ref) => _Auth(user))],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: VerifyEmailBannerFrame(
              child: Column(
                children: [
                  EmailVerificationTile(),
                  Expanded(child: Center(child: Text('Page'))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final entry in sizes.entries) {
    group('banner and profile row — ${entry.key}', () {
      testWidgets('unverified: banner, wrapped email, verify row', (
        tester,
      ) async {
        await pump(tester, entry.value, AeroDropUser.fromMap(_row()));
        expect(tester.takeException(), isNull);
        expect(
          find.textContaining('Verify your email to start ordering.'),
          findsOneWidget,
        );
        expect(find.textContaining(_longEmail), findsOneWidget);
        expect(find.text('Email not verified'), findsOneWidget);
        expect(find.text('Verify email'), findsNWidgets(2));
        expect(find.text('Page'), findsOneWidget);
      });

      testWidgets('verified: no banner, verified row', (tester) async {
        await pump(
          tester,
          entry.value,
          AeroDropUser.fromMap(_row(verifiedAt: '2026-11-14T02:00:00Z')),
        );
        expect(find.textContaining('Verify your email'), findsNothing);
        expect(find.text('Email verified'), findsOneWidget);
      });

      testWidgets('admin: nothing at all', (tester) async {
        await pump(
          tester,
          entry.value,
          AeroDropUser.fromMap(_row(role: 'admin')),
        );
        expect(find.textContaining('Verify'), findsNothing);
        expect(find.textContaining('Email'), findsNothing);
      });

      testWidgets('before migration 35: nothing at all', (tester) async {
        await pump(
          tester,
          entry.value,
          AeroDropUser.fromMap(_row(withColumn: false)),
        );
        expect(find.textContaining('Verify'), findsNothing);
        expect(find.textContaining('Email'), findsNothing);
      });
    });
  }
}
