/// Authentication constants for AeroDrop.
class AuthConstants {
  /// The length of OTP verification codes used across registration, login 2FA, and password recovery.
  /// This must match the "Email OTP length" setting in the Supabase Dashboard
  /// (Authentication -> Email -> OTP length).
  static const int otpLength = 6;
}
