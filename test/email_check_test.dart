import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/services/email_check_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('EmailCheckResult.fromResponse', () {
    test('a real address is allowed', () {
      final r = EmailCheckResult.fromResponse({'ok': true});
      expect(r.ok, isTrue);
      expect(r.unchecked, isFalse);
    });

    test('a refused address carries its message', () {
      final r = EmailCheckResult.fromResponse({
        'ok': false,
        'reason': 'no_domain',
        'message':
            "fakedomain.com doesn't exist. Check the spelling of your email.",
      });
      expect(r.ok, isFalse);
      expect(r.reason, 'no_domain');
      expect(r.errorText, contains("doesn't exist"));
    });

    test('a typo carries the likely address', () {
      final r = EmailCheckResult.fromResponse({
        'ok': false,
        'reason': 'typo',
        'suggestion': 'juan@gmail.com',
        'message': 'Did you mean juan@gmail.com?',
      });
      expect(r.ok, isFalse);
      expect(r.suggestion, 'juan@gmail.com');
    });

    test('an unexpected answer never blocks sign-up', () {
      for (final data in <Object?>[
        null,
        'oops',
        <String, Object?>{},
        {'ok': 'yes'},
      ]) {
        final r = EmailCheckResult.fromResponse(data);
        expect(r.ok, isTrue, reason: 'data: $data');
        expect(r.unchecked, isTrue);
      }
    });

    test('a refusal without a message still explains itself', () {
      final r = EmailCheckResult.fromResponse({'ok': false});
      expect(r.errorText, isNotEmpty);
    });
  });

  group('email delivery failures', () {
    test("Supabase's built-in sender refusing an address is explained", () {
      const e = AuthException(
        'Email address "juan@gmail.com" cannot be used as it is not authorized',
        statusCode: '400',
        code: 'email_address_not_authorized',
      );
      expect(isEmailDeliveryFailure(e), isTrue);
      expect(formatAuthErrorMessage(e), emailNotSentMessage);
    });

    test('a broken SMTP server is explained', () {
      const e = AuthException(
        'Error sending confirmation email',
        statusCode: '500',
      );
      expect(isEmailDeliveryFailure(e), isTrue);
      expect(formatAuthErrorMessage(e), emailNotSentMessage);
    });

    test('other errors are left alone', () {
      const e = AuthException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      );
      expect(isEmailDeliveryFailure(e), isFalse);
    });
  });
}
