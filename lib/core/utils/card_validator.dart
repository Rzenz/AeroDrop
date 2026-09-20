class CardValidator {
  /// Standard Luhn algorithm checksum check
  static bool isValidLuhn(String cardNumber) {
    final sanitized = cardNumber.replaceAll(RegExp(r'\s+|-'), '');
    if (sanitized.length < 13 || sanitized.length > 19) return false;
    if (!RegExp(r'^\d+$').hasMatch(sanitized)) return false;

    int sum = 0;
    bool alternate = false;
    for (int i = sanitized.length - 1; i >= 0; i--) {
      int digit = int.parse(sanitized[i]);
      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  /// Expiry in future check (MM/YY or MM/YYYY)
  static bool isValidExpiry(String expiry) {
    final clean = expiry.replaceAll(' ', '');
    final parts = clean.split('/');
    if (parts.length != 2) return false;

    final month = int.tryParse(parts[0]);
    final yearPart = int.tryParse(parts[1]);
    if (month == null || yearPart == null) return false;
    if (month < 1 || month > 12) return false;

    final now = DateTime.now();
    final year = yearPart < 100 ? 2000 + yearPart : yearPart;

    if (year < now.year) return false;
    if (year == now.year && month < now.month) return false;
    return true;
  }

  /// 3 or 4 digit CVV
  static bool isValidCvv(String cvv) {
    final clean = cvv.trim();
    return RegExp(r'^\d{3,4}$').hasMatch(clean);
  }

  /// Card brand detection
  static String detectBrand(String cardNumber) {
    final sanitized = cardNumber.replaceAll(RegExp(r'\s+|-'), '');
    if (sanitized.startsWith('4')) return 'Visa';
    if (RegExp(r'^5[1-5]').hasMatch(sanitized) ||
        RegExp(r'^2(22[1-9]|2[3-9]\d|[3-6]\d{2}|7[0-1]\d|720)').hasMatch(sanitized)) {
      return 'Mastercard';
    }
    if (sanitized.startsWith('34') || sanitized.startsWith('37')) return 'Amex';
    if (sanitized.startsWith('6011') || sanitized.startsWith('65')) return 'Discover';
    if (sanitized.startsWith('35')) return 'JCB';
    return 'Card';
  }
}
