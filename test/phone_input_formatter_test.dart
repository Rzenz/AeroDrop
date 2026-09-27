import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:aerodrop/core/utils/phone_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const formatter = PhoneInputFormatter();

  TextEditingValue format(String text, {int? selectionOffset}) {
    final offset = selectionOffset ?? text.length;
    return formatter.formatEditUpdate(
      const TextEditingValue(),
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: offset),
      ),
    );
  }

  group('PhoneInputFormatter length limiting by prefix', () {
    test('Prefix 0 limits to exactly 11 characters (09XXXXXXXXX)', () {
      final val = format('0917123456789'); // 13 chars
      expect(val.text, '09171234567');
      expect(val.text.length, 11);
      expect(isValidPhoneNumber(val.text), isTrue);
    });

    test('Prefix + limits to exactly 13 characters (+639XXXXXXXXX)', () {
      final val = format('+63917123456789'); // 15 chars
      expect(val.text, '+639171234567');
      expect(val.text.length, 13);
      expect(isValidPhoneNumber(val.text), isTrue);
    });

    test('Prefix 9 limits to exactly 10 characters (9XXXXXXXXX)', () {
      final val = format('917123456789'); // 12 chars
      expect(val.text, '9171234567');
      expect(val.text.length, 10);
      expect(isValidPhoneNumber(val.text), isTrue);
    });

    test('Prefix 63 limits to exactly 12 characters (639XXXXXXXXX)', () {
      final val = format('63917123456789'); // 14 chars
      expect(val.text, '639171234567');
      expect(val.text.length, 12);
      expect(isValidPhoneNumber(val.text), isTrue);
    });
  });

  group('PhoneInputFormatter character filtering', () {
    test('filters out letters and special characters', () {
      final val = format('0917-abc-123-4567');
      expect(val.text, '09171234567');
    });

    test('keeps leading + but strips interior +', () {
      final val = format('+63+917+123+4567');
      expect(val.text, '+639171234567');
    });

    test('strips + if not at the beginning', () {
      final val = format('0917+1234567');
      expect(val.text, '09171234567');
    });

    test('handles empty input cleanly', () {
      final val = format('');
      expect(val.text, '');
    });

    test('handles input with only invalid characters cleanly', () {
      final val = format('hello world!@#\$%');
      expect(val.text, '');
    });
  });

  group('Phone validation across all supported formats', () {
    test('accepts valid formats', () {
      expect(isValidPhoneNumber('09171234567'), isTrue);
      expect(isValidPhoneNumber('+639171234567'), isTrue);
      expect(isValidPhoneNumber('9171234567'), isTrue);
      expect(isValidPhoneNumber('639171234567'), isTrue);
    });

    test('rejects incomplete numbers', () {
      expect(isValidPhoneNumber('0917123456'), isFalse); // 10 chars
      expect(isValidPhoneNumber('917123456'), isFalse); // 9 chars
      expect(isValidPhoneNumber('+63917123456'), isFalse); // 12 chars
      expect(isValidPhoneNumber('63917123456'), isFalse); // 11 chars
    });

    test('rejects numbers that exceeded allowed format lengths', () {
      expect(isValidPhoneNumber('091712345678'), isFalse); // 12 chars
      expect(isValidPhoneNumber('91712345678'), isFalse); // 11 chars
    });
  });
}
