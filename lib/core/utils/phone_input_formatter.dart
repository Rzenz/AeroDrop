import 'package:flutter/services.dart';

/// A format-aware [TextInputFormatter] for Philippine and international phone numbers.
///
/// Rules:
/// - Digits and leading '+' only ('+' allowed only as the first character).
/// - If input starts with '0': max 11 characters (09XXXXXXXXX).
/// - If input starts with '+': max 13 characters (+639XXXXXXXXX).
/// - If input starts with '9': max 10 characters (9XXXXXXXXX).
/// - If input starts with '63': max 12 characters (639XXXXXXXXX).
class PhoneInputFormatter extends TextInputFormatter {
  const PhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }

    // Allow '+' only at index 0, and digits everywhere
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (i == 0 && char == '+') {
        buffer.write('+');
      } else if (RegExp(r'\d').hasMatch(char)) {
        buffer.write(char);
      }
    }

    String filtered = buffer.toString();
    if (filtered.isEmpty) {
      return const TextEditingValue();
    }

    // Determine max length based on prefix
    final int maxLength;
    if (filtered.startsWith('0')) {
      maxLength = 11; // 09XXXXXXXXX
    } else if (filtered.startsWith('+')) {
      maxLength = 13; // +639XXXXXXXXX
    } else if (filtered.startsWith('9')) {
      maxLength = 10; // 9XXXXXXXXX
    } else if (filtered.startsWith('63')) {
      maxLength = 12; // 639XXXXXXXXX
    } else {
      maxLength = 11;
    }

    if (filtered.length > maxLength) {
      filtered = filtered.substring(0, maxLength);
    }

    final selectionIndex = filtered.length < newValue.selection.end
        ? filtered.length
        : newValue.selection.end;

    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(
        offset: selectionIndex.clamp(0, filtered.length),
      ),
    );
  }
}
