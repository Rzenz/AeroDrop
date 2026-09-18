import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

void main() {
  group('normalizeEmail', () {
    test('trims, lowercases, and removes invisible whitespace', () {
      expect(
        normalizeEmail('  JaneDoe@Example.COM\u00A0'),
        'janedoe@example.com',
      );
    });

    test('rejects malformed emails', () {
      expect(
        () => normalizeEmail('not-an-email'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('isValidEmail', () {
    test('accepts valid emails including plus addressing, subdomains, and new TLDs', () {
      expect(isValidEmail('aerodrop.uclm+user1@gmail.com'), isTrue);
      expect(isValidEmail('name.surname@uclm.edu.ph'), isTrue);
      expect(isValidEmail('test@site.online'), isTrue);
    });

    test('rejects invalid email formats', () {
      expect(isValidEmail('plainaddress'), isFalse);
      expect(isValidEmail('missing@domain'), isFalse);
      expect(isValidEmail('@gmail.com'), isFalse);
    });
  });

  group('normalizePhoneNumber', () {
    test('normalizes Philippine mobile starting with 09 to +639', () {
      expect(normalizePhoneNumber('09171234567'), '+639171234567');
    });

    test('normalizes Philippine mobile starting with 9 to +639', () {
      expect(normalizePhoneNumber('9171234567'), '+639171234567');
    });

    test('normalizes Philippine mobile starting with 639 to +639', () {
      expect(normalizePhoneNumber('639171234567'), '+639171234567');
    });

    test('retains international numbers with +', () {
      expect(normalizePhoneNumber('+14155552671'), '+14155552671');
    });

    test('rejects empty or invalid phone formats', () {
      expect(() => normalizePhoneNumber(''), throwsA(isA<FormatException>()));
      expect(() => normalizePhoneNumber('abc'), throwsA(isA<FormatException>()));
    });
  });

  group('formatAuthErrorMessage', () {
    test('handles phone_provider_disabled cleanly without fake SMS', () {
      final error = const AuthException('Phone provider is disabled', code: 'phone_provider_disabled');
      final msg = formatAuthErrorMessage(error);
      expect(msg, 'SMS verification is currently unavailable. Please use email.');
    });

    test('handles user_already_exists without account enumeration', () {
      final error = const AuthException('User already registered', code: 'user_already_exists');
      final msg = formatAuthErrorMessage(error);
      expect(msg, 'This email may already be registered. Try signing in or use a different email.');
    });

    test('handles otp_expired', () {
      final error = const AuthException('Token expired', code: 'otp_expired');
      final msg = formatAuthErrorMessage(error);
      expect(msg, 'That verification code has expired. Please request a new code.');
    });

    test('handles invalid_credentials or invalid otp', () {
      final error = const AuthException('Invalid login credentials', code: 'invalid_credentials');
      final msg = formatAuthErrorMessage(error);
      expect(msg, 'Incorrect credentials or invalid verification code.');
    });

    test('handles rate limiting', () {
      final error = const AuthException('Rate limit exceeded', code: 'rate_limit_exceeded');
      final msg = formatAuthErrorMessage(error);
      expect(msg, contains('Too many attempts'));
    });
  });

  group('AuthState registration context', () {
    test('stores and copies pending registration details', () {
      const state = AuthState(
        pendingEmail: 'test@aerodrop.app',
        pendingPhone: '+639171234567',
        pendingRole: 'vendor',
        requiresVerification: true,
      );

      expect(state.pendingEmail, 'test@aerodrop.app');
      expect(state.pendingPhone, '+639171234567');
      expect(state.pendingRole, 'vendor');
      expect(state.requiresVerification, isTrue);

      final updated = state.copyWith(
        isVerified: true,
        sessionUnlocked: true,
        requiresVerification: false,
      );

      expect(updated.isVerified, isTrue);
      expect(updated.sessionUnlocked, isTrue);
      expect(updated.requiresVerification, isFalse);
    });

    test('sets unconfirmed account state with custom verification message', () {
      const state = AuthState(
        pendingEmail: 'user@example.com',
        requiresVerification: true,
        errorMessage: "Your email isn't verified yet. We sent you a new code.",
      );

      expect(state.pendingEmail, 'user@example.com');
      expect(state.requiresVerification, isTrue);
      expect(state.user, isNull);
      expect(state.errorMessage, "Your email isn't verified yet. We sent you a new code.");
    });
  });
}
