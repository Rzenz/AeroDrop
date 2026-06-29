import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeEmail', () {
    test('trims, lowercases, and removes invisible whitespace', () {
      expect(normalizeEmail('  JaneDoe@Example.COM\u00A0'), 'janedoe@example.com');
    });

    test('rejects malformed emails', () {
      expect(() => normalizeEmail('not-an-email'), throwsA(isA<FormatException>()));
    });
  });
}
