/// Authentication constants for AeroDrop.
class AuthConstants {
  /// The length of OTP verification codes used across registration, login 2FA, and password recovery.
  /// This must match the "Email OTP length" setting in the Supabase Dashboard
  /// (Authentication -> Email -> OTP length).
  static const int otpLength = 6;

  /// Canonical administrator email address.
  static const String adminEmail = 'admin.portal@uclm.edu';

  /// Legacy administrator email addresses supported for backward compatibility with mock tests.
  static const String legacyAdminEmail = 'admin@aerodrop.com';
  static const String alternateAdminEmail = 'aerodrop.uclm+admin@gmail.com';

  /// Returns true if the provided email matches any administrator email address.
  static bool isAdminEmail(String? email) {
    if (email == null) return false;
    final normalized = email.trim().toLowerCase();
    return normalized == adminEmail ||
        normalized == legacyAdminEmail ||
        normalized == alternateAdminEmail;
  }
}
