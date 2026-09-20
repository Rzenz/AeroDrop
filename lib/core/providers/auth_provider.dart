import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../utils/image_utils.dart';

// ── Email & Phone helpers ───────────────────────────────────────────────────

String normalizeEmail(String email) {
  final normalized = email.trim().toLowerCase().replaceAll(
    RegExp(r'[\u200B-\u200D\uFEFF]'),
    '',
  );

  if (!RegExp(
    r'^[A-Za-z0-9.!#$%&*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$',
  ).hasMatch(normalized)) {
    throw const FormatException('Invalid email address');
  }

  return normalized;
}

bool isValidEmail(String email) {
  try {
    normalizeEmail(email);
    return true;
  } catch (_) {
    return false;
  }
}

String normalizePhoneNumber(String phone) {
  final clean = phone.replaceAll(RegExp(r'[\s\-()]'), '');
  if (clean.isEmpty) {
    throw const FormatException('Phone number cannot be empty.');
  }
  if (clean.startsWith('+')) {
    if (clean.length < 10 || clean.length > 16) {
      throw const FormatException('Invalid international phone number format');
    }
    return clean;
  }
  // Philippine mobile numbers
  if (clean.startsWith('09') && clean.length == 11) {
    return '+63${clean.substring(1)}';
  }
  if (clean.startsWith('9') && clean.length == 10) {
    return '+63$clean';
  }
  if (clean.startsWith('639') && clean.length == 12) {
    return '+$clean';
  }
  if (clean.length >= 7 && clean.length <= 15) {
    return '+$clean';
  }
  throw const FormatException('Invalid phone number format.');
}

String formatAuthErrorMessage(Object error) {
  if (error is AuthException) {
    final code = error.code?.toLowerCase() ?? '';
    final msg = error.message.toLowerCase();

    if (code == 'phone_provider_disabled' ||
        msg.contains('phone provider is disabled') ||
        msg.contains('sms not supported') ||
        msg.contains('provider is not enabled') ||
        msg.contains('signups not allowed for otp') ||
        msg.contains('user not found')) {
      return 'SMS verification is currently unavailable. Please use email.';
    }
    if (code == 'email_address_invalid') {
      return 'Please enter a valid email address.';
    }
    if (code == 'over_email_send_rate_limit' ||
        code == 'rate_limit_exceeded' ||
        code == 'over_sms_send_rate_limit' ||
        msg.contains('rate limit') ||
        msg.contains('too many requests')) {
      return 'Too many attempts. Please wait a few minutes before trying again.';
    }
    if (code == 'email_exists' ||
        code == 'user_already_exists' ||
        msg.contains('already registered') ||
        msg.contains('already exists')) {
      return 'This email may already be registered. Try signing in or use a different email.';
    }
    if (code == 'phone_exists' || msg.contains('phone number already')) {
      return 'This phone number may already be registered. Try signing in or use a different number.';
    }
    if (code == 'email_provider_disabled' || code == 'signup_disabled') {
      return 'Registration is currently unavailable.';
    }
    if (code == 'weak_password') {
      return error.message;
    }
    if (code == 'otp_expired' || msg.contains('expired')) {
      return 'That verification code has expired. Please request a new code.';
    }
    if (code == 'invalid_credentials' ||
        msg.contains('invalid login credentials') ||
        msg.contains('user not found') ||
        msg.contains('token has expired or is invalid') ||
        msg.contains('invalid otp') ||
        msg.contains('token is invalid')) {
      return 'Incorrect credentials or invalid verification code.';
    }
    return error.message;
  }

  final msg = error.toString().toLowerCase();
  if (msg.contains('phone provider is disabled') ||
      msg.contains('sms not supported') ||
      msg.contains('sms verification is not configured') ||
      msg.contains('signups not allowed for otp') ||
      msg.contains('user not found')) {
    return 'SMS verification is currently unavailable. Please use email.';
  }
  if (msg.contains('invalid email address') ||
      (msg.contains('email') && msg.contains('invalid'))) {
    return 'Please enter a valid email address.';
  }
  if (msg.contains('phone')) {
    return 'Please enter a valid phone number.';
  }

  return 'Authentication failed. Please try again.';
}

// ── State ─────────────────────────────────────────────────────────────────────

class AuthState {
  final AeroDropUser? user;
  final bool isLoading;
  final String? errorMessage;
  final bool requiresVerification;
  final bool isVerified;
  final bool sessionUnlocked;
  final String? otpDeliveryMethod; // 'email' | 'sms'
  final String? pendingEmail;
  final String? pendingPhone;
  final String? pendingRole;
  final XFile? pendingLogoFile;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.requiresVerification = false,
    this.isVerified = false,
    this.sessionUnlocked = false,
    this.otpDeliveryMethod,
    this.pendingEmail,
    this.pendingPhone,
    this.pendingRole,
    this.pendingLogoFile,
  });

  AuthState copyWith({
    AeroDropUser? user,
    bool? isLoading,
    String? errorMessage,
    bool? requiresVerification,
    bool? isVerified,
    bool? sessionUnlocked,
    String? otpDeliveryMethod,
    String? pendingEmail,
    String? pendingPhone,
    String? pendingRole,
    XFile? pendingLogoFile,
    bool clearPendingLogo = false,
    bool clearErrorMessage = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      requiresVerification: requiresVerification ?? this.requiresVerification,
      isVerified: isVerified ?? this.isVerified,
      sessionUnlocked: sessionUnlocked ?? this.sessionUnlocked,
      otpDeliveryMethod: otpDeliveryMethod ?? this.otpDeliveryMethod,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      pendingPhone: pendingPhone ?? this.pendingPhone,
      pendingRole: pendingRole ?? this.pendingRole,
      pendingLogoFile: clearPendingLogo ? null : (pendingLogoFile ?? this.pendingLogoFile),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref? ref;

  AuthNotifier([this.ref]) : super(const AuthState()) {
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    if (!SupabaseService.isConfigured) return;
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser != null) {
      state = state.copyWith(isLoading: true);
      try {
        final userRow = await SupabaseService.client
            .from('users')
            .select()
            .eq('id', authUser.id)
            .maybeSingle();
        if (userRow != null && mounted) {
          final aeroUser = AeroDropUser.fromMap(
            Map<String, dynamic>.from(userRow),
          );
          // Session restored in background for auth purposes, but user must
          // explicitly unlock/select role through the login flow.
          state = state.copyWith(
            user: aeroUser,
            sessionUnlocked: false,
            requiresVerification: false,
            isVerified: true,
            isLoading: false,
          );
        } else {
          if (mounted) {
            state = state.copyWith(isLoading: false);
          }
        }
      } catch (e) {
        debugPrint('Error restoring session: $e');
        if (mounted) {
          state = state.copyWith(isLoading: false);
        }
      }
    }
  }

  void completeVerification() {
    state = state.copyWith(
      requiresVerification: false,
      isVerified: true,
      sessionUnlocked: true,
    );
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<bool> login(
    String email,
    String password, {
    String? expectedRole,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final normalizedEmail = email.trim().toLowerCase();
      final response = await SupabaseService.client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );

      final authUser = response.user;
      if (authUser == null) throw Exception('Login failed');

      final userRow = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      if (userRow == null) {
        await SupabaseService.client.auth.signOut();
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Your account profile is not synchronized with the database.',
        );
        return false;
      }

      final aeroUser = AeroDropUser.fromMap(Map<String, dynamic>.from(userRow));

      if (aeroUser.accountStatus == 'suspended') {
        await SupabaseService.client.auth.signOut();
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Your account has been suspended. Please contact the administrator.',
        );
        return false;
      }

      if (aeroUser.accountStatus == 'deleted') {
        await SupabaseService.client.auth.signOut();
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'This account is no longer available. Please contact the administrator.',
        );
        return false;
      }

      // Role enforcement against the selected login mode
      if (expectedRole != null) {
        if (expectedRole == 'vendor') {
          final isPendingApplicant = aeroUser.vendorStatus == 'pending';
          if (!isPendingApplicant &&
              aeroUser.role != 'vendor' &&
              !aeroUser.isAdmin) {
            await SupabaseService.client.auth.signOut();
            state = state.copyWith(
              isLoading: false,
              errorMessage: 'This account is not registered as a vendor.',
            );
            return false;
          }

          if (aeroUser.role == 'vendor') {
            if (aeroUser.vendorStatus == 'suspended') {
              await SupabaseService.client.auth.signOut();
              state = state.copyWith(
                isLoading: false,
                errorMessage:
                    'Your vendor account has been suspended. Please contact the administrator.',
              );
              return false;
            }

            if (aeroUser.vendorStatus == 'rejected') {
              await SupabaseService.client.auth.signOut();
              state = state.copyWith(
                isLoading: false,
                errorMessage:
                    'Your vendor application was rejected. Please contact the administrator.',
              );
              return false;
            }
          }
        } else if (expectedRole == 'user') {
          if (aeroUser.role == 'vendor' && !aeroUser.isAdmin) {
            await SupabaseService.client.auth.signOut();
            state = state.copyWith(
              isLoading: false,
              errorMessage:
                  'This account is registered as a vendor. Please use Vendor Login.',
            );
            return false;
          }
        }
      }

      // Admin role is excluded from OTP verification
      if (aeroUser.isAdmin) {
        state = state.copyWith(
          user: aeroUser,
          sessionUnlocked: true,
          requiresVerification: false,
          isVerified: true,
          isLoading: false,
          errorMessage: null,
        );
        return true;
      }

      // Customer / Vendor requires OTP verification step
      state = state.copyWith(
        user: aeroUser,
        sessionUnlocked: false,
        requiresVerification: true,
        isVerified: false,
        isLoading: false,
        errorMessage: null,
      );

      return true;
    } catch (error) {
      debugPrint('Supabase login failed: $error');
      final normalizedEmail = email.trim().toLowerCase();

      if (error is AuthException) {
        final code = error.code?.toLowerCase() ?? '';
        final msg = error.message.toLowerCase();

        if (code == 'email_not_confirmed' ||
            msg.contains('email not confirmed')) {
          if (normalizedEmail != 'admin@aerodrop.com') {
            try {
              await SupabaseService.client.auth.resend(
                type: OtpType.signup,
                email: normalizedEmail,
              );
            } on AuthException catch (resendErr) {
              debugPrint(
                'Resend signup OTP on unconfirmed login error: $resendErr',
              );
            } catch (e) {
              debugPrint('Resend signup OTP error: $e');
            }
          }

          state = state.copyWith(
            user: null,
            sessionUnlocked: false,
            requiresVerification: true,
            isVerified: false,
            isLoading: false,
            pendingEmail: normalizedEmail,
            pendingRole: expectedRole ?? 'user',
            errorMessage:
                "Your email isn't verified yet. We sent you a new code.",
          );
          return false;
        }
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: formatAuthErrorMessage(error),
      );
      return false;
    }
  }

  // ── OTP Delivery & Verification ──────────────────────────────────────────

  Future<bool> sendLoginOtp({required bool viaSms}) async {
    final user = state.user;
    if (user == null) {
      state = state.copyWith(errorMessage: 'No active session found.');
      return false;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      if (viaSms) {
        final phone = user.phoneNumber;
        if (phone == null || phone.trim().isEmpty) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'No phone number is registered for this account.',
          );
          return false;
        }
        final normalizedPhone = normalizePhoneNumber(phone);
        await SupabaseService.client.auth.signInWithOtp(
          phone: normalizedPhone,
          shouldCreateUser: false,
        );
      } else {
        final normalizedEmail = normalizeEmail(user.email);
        await SupabaseService.client.auth.signInWithOtp(
          email: normalizedEmail,
          shouldCreateUser: false,
        );
      }
      state = state.copyWith(
        isLoading: false,
        requiresVerification: true,
        isVerified: false,
        otpDeliveryMethod: viaSms ? 'sms' : 'email',
        errorMessage: null,
      );
      return true;
    } catch (e) {
      debugPrint('Failed to send login OTP: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: formatAuthErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> verifyLoginOtp({
    required String token,
    required bool viaSms,
  }) async {
    final user = state.user;
    if (user == null) {
      state = state.copyWith(errorMessage: 'No active session found.');
      return false;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cleanToken = token.trim();
      AuthResponse response;
      if (viaSms) {
        final normalizedPhone = normalizePhoneNumber(user.phoneNumber ?? '');
        response = await SupabaseService.client.auth.verifyOTP(
          type: OtpType.sms,
          token: cleanToken,
          phone: normalizedPhone,
        );
      } else {
        final normalizedEmail = normalizeEmail(user.email);
        response = await SupabaseService.client.auth.verifyOTP(
          type: OtpType.email,
          token: cleanToken,
          email: normalizedEmail,
        );
      }

      if (response.user == null) {
        throw const AuthException('Invalid verification code.');
      }

      // Sync public.users record
      final userRow = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', response.user!.id)
          .maybeSingle();

      final updatedUser = userRow != null
          ? AeroDropUser.fromMap(Map<String, dynamic>.from(userRow))
          : user;

      state = state.copyWith(
        user: updatedUser,
        isLoading: false,
        requiresVerification: false,
        isVerified: true,
        sessionUnlocked: true,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      debugPrint('Supabase verifyOTP failed: $e');
      String msg = 'Invalid verification code.';
      if (e is AuthException) {
        final code = e.code?.toLowerCase() ?? '';
        final m = e.message.toLowerCase();
        if (code.contains('otp_expired') || m.contains('expired')) {
          msg = 'That code has expired. Request a new code.';
        } else if (code.contains('over_rate_limit') || m.contains('rate limit')) {
          msg = 'Please wait before requesting another code.';
        } else {
          msg = e.message;
        }
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
      );
      return false;
    }
  }

  void setOtpDeliveryMethod(String method) {
    state = state.copyWith(otpDeliveryMethod: method);
  }

  // ── Register ──────────────────────────────────────────────────────────────

  Future<bool> register(
    String name,
    String email,
    String password,
    String requestedRole, // 'user' | 'vendor'
    String phoneNumber, {
    String? businessName,
    String? businessCategory,
    String? businessDescription,
    String? campusLocationId,
    XFile? logoFile,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final normalizedEmail = normalizeEmail(email);
      final normalizedPhone = normalizePhoneNumber(phoneNumber);

      final response = await SupabaseService.client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'full_name': name.trim(),
          'phone_number': normalizedPhone,
          'requested_role': requestedRole,
          if (businessName != null) 'business_name': businessName.trim(),
          'business_category': ?businessCategory,
          if (businessDescription != null)
            'business_description': businessDescription.trim(),
          'campus_location_id': ?campusLocationId,
        },
      );

      final authUser = response.user;
      if (authUser == null) throw Exception('Registration failed');

      // Trigger handles public.users insertion — no client-side write needed.

      final sessionCreated = response.session != null;
      if (sessionCreated && logoFile != null) {
        try {
          final validation = await ImageUtils.validateImage(logoFile);
          if (validation.isValid) {
            final bytes = await logoFile.readAsBytes();
            final ext = validation.fileExtension ?? '.png';
            final storagePath = '${authUser.id}/business_logo$ext';

            await SupabaseService.client.storage
                .from('vendor-logos')
                .uploadBinary(
                  storagePath,
                  bytes,
                  fileOptions: FileOptions(
                    contentType: validation.mimeType,
                    upsert: true,
                  ),
                );

            final baseLogoUrl = SupabaseService.client.storage
                .from('vendor-logos')
                .getPublicUrl(storagePath);
            final logoUrl =
                '$baseLogoUrl?v=${DateTime.now().millisecondsSinceEpoch}';

            await SupabaseService.client
                .from('users')
                .update({'business_logo_url': logoUrl})
                .eq('id', authUser.id)
                .select();
          }
        } catch (storageError) {
          debugPrint(
            'Error uploading business logo during registration: $storageError',
          );
        }
      }

      state = state.copyWith(
        user: null,
        sessionUnlocked: false,
        requiresVerification: true,
        isVerified: false,
        isLoading: false,
        pendingEmail: normalizedEmail,
        pendingPhone: normalizedPhone,
        pendingRole: requestedRole,
        pendingLogoFile: logoFile,
        errorMessage: null,
      );

      return true;
    } catch (error) {
      debugPrint('Supabase register failed: $error');
      final normalizedEmail = normalizeEmail(email);

      if (error is AuthException) {
        final code = error.code?.toLowerCase() ?? '';
        final msg = error.message.toLowerCase();

        if (code == 'user_already_exists' ||
            code == 'email_exists' ||
            msg.contains('already registered') ||
            msg.contains('already exists')) {
          if (normalizedEmail != 'admin@aerodrop.com') {
            try {
              await SupabaseService.client.auth.resend(
                type: OtpType.signup,
                email: normalizedEmail,
              );
              state = state.copyWith(
                user: null,
                sessionUnlocked: false,
                requiresVerification: true,
                isVerified: false,
                isLoading: false,
                pendingEmail: normalizedEmail,
                pendingPhone: normalizePhoneNumber(phoneNumber),
                pendingRole: requestedRole,
                errorMessage:
                    "Your email isn't verified yet. We sent you a new code.",
              );
              return true;
            } on AuthException catch (resendErr) {
              final resendCode = resendErr.code?.toLowerCase() ?? '';
              final resendMsg = resendErr.message.toLowerCase();

              if (resendCode == 'over_email_send_rate_limit' ||
                  resendCode == 'rate_limit_exceeded' ||
                  resendMsg.contains('rate limit') ||
                  resendMsg.contains('security purposes') ||
                  resendMsg.contains('seconds')) {
                state = state.copyWith(
                  user: null,
                  sessionUnlocked: false,
                  requiresVerification: true,
                  isVerified: false,
                  isLoading: false,
                  pendingEmail: normalizedEmail,
                  pendingPhone: normalizePhoneNumber(phoneNumber),
                  pendingRole: requestedRole,
                  errorMessage:
                      "Your email isn't verified yet. Please enter the code sent to your email.",
                );
                return true;
              }
            } catch (_) {}
          }
        }
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: formatAuthErrorMessage(error),
      );
      return false;
    }
  }

  Future<bool> verifyRegistrationOtp({
    required String token,
    required String email,
    String? phone,
    bool viaSms = false,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cleanToken = token.trim();
      AuthResponse response;

      if (viaSms) {
        if (phone == null || phone.trim().isEmpty) {
          throw const FormatException('Phone number is required for SMS verification.');
        }
        final normalizedPhone = normalizePhoneNumber(phone);
        response = await SupabaseService.client.auth.verifyOTP(
          type: OtpType.sms,
          token: cleanToken,
          phone: normalizedPhone,
        );
      } else {
        final normalizedEmail = normalizeEmail(email);
        response = await SupabaseService.client.auth.verifyOTP(
          type: OtpType.signup,
          token: cleanToken,
          email: normalizedEmail,
        );
      }

      final authUser = response.user;
      if (authUser == null) {
        throw const AuthException('Invalid verification code.');
      }

      String? uploadedLogoUrl;
      String? logoUploadWarning;

      final pendingLogo = state.pendingLogoFile;
      if (pendingLogo != null) {
        try {
          final validation = await ImageUtils.validateImage(pendingLogo);
          if (validation.isValid) {
            final bytes = await pendingLogo.readAsBytes();
            final ext = validation.fileExtension ?? '.png';
            final storagePath = '${authUser.id}/business_logo$ext';

            await SupabaseService.client.storage
                .from('vendor-logos')
                .uploadBinary(
                  storagePath,
                  bytes,
                  fileOptions: FileOptions(
                    contentType: validation.mimeType,
                    upsert: true,
                  ),
                );

            final baseLogoUrl = SupabaseService.client.storage
                .from('vendor-logos')
                .getPublicUrl(storagePath);
            uploadedLogoUrl =
                '$baseLogoUrl?v=${DateTime.now().millisecondsSinceEpoch}';

            final updateRes = await SupabaseService.client
                .from('users')
                .update({'business_logo_url': uploadedLogoUrl})
                .eq('id', authUser.id)
                .select();

            if (updateRes.isEmpty) {
              debugPrint('Warning: business_logo_url update returned empty result');
            }
          } else {
            logoUploadWarning =
                "Account verified, but your store logo couldn't be uploaded. You can add it from your store profile.";
          }
        } catch (logoErr) {
          debugPrint('Error uploading pending registration business logo: $logoErr');
          logoUploadWarning =
              "Account verified, but your store logo couldn't be uploaded. You can add it from your store profile.";
        }
      }

      // Fetch public.users record
      final userRow = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      var aeroUser = userRow != null
          ? AeroDropUser.fromMap(Map<String, dynamic>.from(userRow))
          : AeroDropUser(
              id: authUser.id,
              email: authUser.email ?? email,
              phoneNumber: authUser.phone ?? phone,
              role: state.pendingRole ?? 'user',
            );

      if (uploadedLogoUrl != null) {
        aeroUser = aeroUser.copyWith(businessLogoUrl: uploadedLogoUrl);
      }

      state = state.copyWith(
        user: aeroUser,
        isLoading: false,
        requiresVerification: false,
        isVerified: true,
        sessionUnlocked: true,
        clearPendingLogo: true,
        errorMessage: logoUploadWarning,
      );

      return true;
    } catch (e) {
      debugPrint('Registration verifyOTP failed: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: formatAuthErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> resendRegistrationOtp({
    required String email,
    String? phone,
    bool viaSms = false,
  }) async {
    state = state.copyWith(errorMessage: null);
    try {
      if (viaSms) {
        if (phone == null || phone.trim().isEmpty) {
          throw const FormatException('Phone number is required for SMS verification.');
        }
        final normalizedPhone = normalizePhoneNumber(phone);
        await SupabaseService.client.auth.resend(
          type: OtpType.sms,
          phone: normalizedPhone,
        );
      } else {
        final normalizedEmail = normalizeEmail(email);
        if (normalizedEmail == 'admin@aerodrop.com') {
          state = state.copyWith(
            errorMessage: 'Admin accounts do not require verification emails.',
          );
          return false;
        }
        await SupabaseService.client.auth.resend(
          type: OtpType.signup,
          email: normalizedEmail,
        );
      }
      return true;
    } catch (e) {
      debugPrint('Failed to resend registration OTP: $e');
      state = state.copyWith(errorMessage: formatAuthErrorMessage(e));
      return false;
    }
  }

  Future<bool> resendEmailVerification() async {
    final email = state.user?.email ?? state.pendingEmail;
    if (email == null) return false;
    return resendRegistrationOtp(email: email, viaSms: false);
  }

  Future<bool> resendPhoneOtp() async {
    final email = state.user?.email ?? state.pendingEmail ?? '';
    final phone = state.user?.phoneNumber ?? state.pendingPhone;
    if (phone == null) return false;
    return resendRegistrationOtp(email: email, phone: phone, viaSms: true);
  }

  Future<bool> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final normalizedEmail = normalizeEmail(email);
      if (normalizedEmail == 'admin@aerodrop.com') {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Password reset is disabled for admin accounts.',
        );
        return false;
      }
      await SupabaseService.client.auth.resetPasswordForEmail(normalizedEmail);
      state = state.copyWith(isLoading: false, errorMessage: null);
      return true;
    } catch (e) {
      debugPrint('Password reset failed: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: formatAuthErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> verifyPasswordResetOtp({
    required String token,
    required String email,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cleanToken = token.trim();
      final normalizedEmail = normalizeEmail(email);
      final response = await SupabaseService.client.auth.verifyOTP(
        type: OtpType.recovery,
        token: cleanToken,
        email: normalizedEmail,
      );

      if (response.user == null) {
        throw const AuthException('Invalid password reset code.');
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      debugPrint('Password reset verifyOTP failed: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: formatAuthErrorMessage(e),
      );
      return false;
    }
  }

  // ── Update profile ────────────────────────────────────────────────────────

  Future<bool> updateProfile(
    String name,
    String email, {
    String? phoneNumber,
    String? businessName,
    String? businessCategory,
    String? businessDescription,
    String? campusLocationId,
  }) async {
    if (state.user == null) {
      state = state.copyWith(errorMessage: 'Not logged in.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final userId = state.user!.id;
      final trimmedName = name.trim();
      final trimmedPhone = phoneNumber?.trim();
      final currentEmail = state.user!.email;
      final normalizedEmail = email.trim().toLowerCase();
      bool emailChangePending = false;

      if (normalizedEmail != currentEmail) {
        if (!isValidEmail(email)) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Please enter a valid email address.',
          );
          return false;
        }

        final authRes = await SupabaseService.client.auth.updateUser(
          UserAttributes(email: normalizedEmail),
        );

        if (authRes.user != null) {
          final returnedEmail = authRes.user!.email;
          if (returnedEmail != null && returnedEmail != normalizedEmail) {
            emailChangePending = true;
          }
        }
      }

      await SupabaseService.client
          .from('users')
          .update({
            'full_name': trimmedName,
            'phone_number': ?trimmedPhone,
            if (businessName != null) 'business_name': businessName.trim(),
            if (businessCategory != null)
              'business_category': businessCategory.trim(),
            if (businessDescription != null)
              'business_description': businessDescription.trim(),
            'campus_location_id': ?campusLocationId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);

      final userRow = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (userRow != null) {
        state = state.copyWith(
          user: AeroDropUser.fromMap(Map<String, dynamic>.from(userRow)),
          isLoading: false,
          errorMessage: emailChangePending
              ? 'Please check your new email address to confirm the change.'
              : null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Profile updated, but failed to sync local state.',
        );
      }
      return true;
    } catch (error) {
      debugPrint('Profile update failed: $error');
      String msg = 'Profile update failed. Please try again.';
      if (error is AuthException) {
        msg = formatAuthErrorMessage(error);
      } else if (error is PostgrestException) {
        msg = error.message;
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> updateAvatar(XFile? logoFile) async {
    if (state.user == null) {
      state = state.copyWith(errorMessage: 'Not logged in.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final userId = state.user!.id;
      String? avatarUrl;

      if (logoFile != null) {
        final validation = await ImageUtils.validateImage(logoFile);
        if (!validation.isValid) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: validation.errorMessage ??
                'Unsupported image format. Please choose a JPG, PNG, or WebP image.',
          );
          return false;
        }

        final bytes = await logoFile.readAsBytes();
        final ext = validation.fileExtension ?? '.png';
        final storagePath = '$userId/avatar$ext';

        await SupabaseService.client.storage
            .from('avatars')
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                contentType: validation.mimeType,
                upsert: true,
              ),
            );

        final baseAvatarUrl = SupabaseService.client.storage
            .from('avatars')
            .getPublicUrl(storagePath);
        avatarUrl = '$baseAvatarUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      }

      final updateRes = await SupabaseService.client
          .from('users')
          .update({
            'avatar_url': avatarUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId)
          .select();

      if (updateRes.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Unable to update profile photo. Permission denied or account not found.',
        );
        return false;
      }

      state = state.copyWith(
        user: logoFile == null
            ? state.user!.copyWith(clearAvatar: true)
            : state.user!.copyWith(avatarUrl: avatarUrl),
        isLoading: false,
        errorMessage: null,
      );

      return true;
    } catch (error) {
      debugPrint('Avatar update failed: $error');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Avatar update failed. Please try again.',
      );
      return false;
    }
  }

  Future<bool> updateBusinessLogo(XFile? logoFile) async {
    if (state.user == null) {
      state = state.copyWith(errorMessage: 'Not logged in.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final userId = state.user!.id;
      String? logoUrl;

      if (logoFile != null) {
        final validation = await ImageUtils.validateImage(logoFile);
        if (!validation.isValid) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: validation.errorMessage ??
                'Unsupported image format. Please choose a JPG, PNG, or WebP image.',
          );
          return false;
        }

        final bytes = await logoFile.readAsBytes();
        final ext = validation.fileExtension ?? '.png';
        final storagePath = '$userId/logo$ext';

        await SupabaseService.client.storage
            .from('vendor-logos')
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                contentType: validation.mimeType,
                upsert: true,
              ),
            );

        final baseLogoUrl = SupabaseService.client.storage
            .from('vendor-logos')
            .getPublicUrl(storagePath);
        logoUrl = '$baseLogoUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      }

      final updateRes = await SupabaseService.client
          .from('users')
          .update({
            'business_logo_url': logoUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId)
          .select();

      if (updateRes.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Unable to update store logo. Permission denied or account not found.',
        );
        return false;
      }

      state = state.copyWith(
        user: logoFile == null
            ? state.user!.copyWith(clearBusinessLogo: true)
            : state.user!.copyWith(businessLogoUrl: logoUrl),
        isLoading: false,
        errorMessage: null,
      );

      return true;
    } catch (error) {
      debugPrint('Business logo update failed: $error');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Logo update failed. Please try again.',
      );
      return false;
    }
  }

  // ── Admin user management ─────────────────────────────────────────────────

  Future<String?> suspendUser(
    String userId, {
    String reason = 'Suspended by admin',
  }) async {
    if (!SupabaseService.isConfigured) return 'Supabase is not configured.';
    try {
      await SupabaseService.client
          .from('users')
          .update({
            'account_status': 'suspended',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);
      return null;
    } catch (e) {
      debugPrint('Suspend user failed: $e');
      return e.toString();
    }
  }

  Future<String?> activateUser(String userId) async {
    if (!SupabaseService.isConfigured) return 'Supabase is not configured.';
    try {
      await SupabaseService.client
          .from('users')
          .update({
            'account_status': 'active',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);
      return null;
    } catch (e) {
      debugPrint('Activate user failed: $e');
      return e.toString();
    }
  }

  Future<String?> deleteUserAccount(
    String userId, {
    String reason = 'Deleted by admin',
  }) async {
    if (!SupabaseService.isConfigured) return 'Supabase is not configured.';
    if (state.user?.id == userId) {
      return 'You cannot delete your own administrator account.';
    }
    try {
      await SupabaseService.client.rpc(
        'delete_user_account',
        params: {'p_target_user_id': userId},
      );
      return null;
    } catch (e) {
      debugPrint('Delete user account failed: $e');
      if (e is PostgrestException) {
        return e.message;
      }
      return e.toString();
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  bool _loggingOut = false;

  Future<bool> logout() async {
    if (_loggingOut) return true;
    _loggingOut = true;
    state = state.copyWith(isLoading: true);
    try {
      if (SupabaseService.isConfigured) {
        await SupabaseService.client.auth.signOut(scope: SignOutScope.local);
      }
    } catch (e) {
      debugPrint('Supabase signOut error (ignored for local logout): $e');
    } finally {
      state = const AuthState();
      _loggingOut = false;
    }
    return true;
  }

  // ponytail: switchRole kept as no-op stub — simulation mode removed,
  // but some screens still call it. Safe to delete once callers are cleaned up.
  void switchRole(dynamic role) {}
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
