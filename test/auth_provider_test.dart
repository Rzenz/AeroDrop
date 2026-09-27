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

  group('isValidPhoneNumber', () {
    test('validates valid Philippine and international phone numbers', () {
      expect(isValidPhoneNumber('09171234567'), isTrue);
      expect(isValidPhoneNumber('+639171234567'), isTrue);
      expect(isValidPhoneNumber('639171234567'), isTrue);
      expect(isValidPhoneNumber('9171234567'), isTrue);
      expect(isValidPhoneNumber('+14155552671'), isTrue);
    });

    test('rejects invalid phone numbers', () {
      expect(isValidPhoneNumber(''), isFalse);
      expect(isValidPhoneNumber('123'), isFalse);
      expect(isValidPhoneNumber('0917'), isFalse);
      expect(isValidPhoneNumber('notaphonenumber'), isFalse);
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

    test('handles Google test user error', () {
      final error = const AuthException('Access blocked: AeroDrop is in testing mode and your account is not a test user', code: 'access_denied');
      final msg = formatAuthErrorMessage(error);
      expect(msg, "This Google account isn't a test user yet. Please contact the administrator.");
    });

    test('handles Google OAuth cancelled sign in', () {
      final error = const AuthException('User cancelled the sign in flow', code: 'user_cancelled');
      final msg = formatAuthErrorMessage(error);
      expect(msg, 'Google sign-in was cancelled.');
    });

    test('handles local server port 3000 busy error', () {
      final error = const AuthException('Port 3000 is already in use');
      final msg = formatAuthErrorMessage(error);
      expect(msg, 'Port 3000 is already in use. Please close any application using port 3000 and try again.');
    });

    test('handles network failure cleanly', () {
      final error = const AuthException('Failed host lookup: network error');
      final msg = formatAuthErrorMessage(error);
      expect(msg, 'Network connection failed. Please check your internet connection and try again.');
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
