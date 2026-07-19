import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'delivery_provider.dart';
import 'notification_provider.dart';
import 'drone_provider.dart';
import 'order_provider.dart';
import 'product_provider.dart';
import 'vendor_provider.dart';
import 'weather_provider.dart';

import '../models/user_model.dart';
import '../services/supabase_service.dart';

// ── Email helpers ─────────────────────────────────────────────────────────────

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

String formatAuthErrorMessage(Object error) {
  if (error is AuthException) {
    final code = error.code?.toLowerCase() ?? '';
    final msg = error.message.toLowerCase();

    if (code == 'email_address_invalid') {
      return 'Please enter a valid email address.';
    }
    if (code == 'over_email_send_rate_limit' ||
        code == 'rate_limit_exceeded' ||
        msg.contains('rate limit')) {
      return 'Too many attempts. Please wait before trying again.';
    }
    if (code == 'email_exists' ||
        code == 'user_already_exists' ||
        msg.contains('already registered') ||
        msg.contains('already exists')) {
      return 'An account with this email already exists.';
    }
    if (code == 'email_provider_disabled' || code == 'signup_disabled') {
      return 'Registration is currently unavailable.';
    }
    if (code == 'weak_password') {
      return error.message;
    }
    if (code == 'invalid_credentials' ||
        msg.contains('invalid login credentials') ||
        msg.contains('user not found') ||
        msg.contains('email not confirmed')) {
      return 'Incorrect email or password.';
    }
    return error.message;
  }

  final msg = error.toString().toLowerCase();
  if (msg.contains('invalid email address') ||
      (msg.contains('email') && msg.contains('invalid'))) {
    return 'Please enter a valid email address.';
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

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.requiresVerification = false,
    this.isVerified = false,
  });

  AuthState copyWith({
    AeroDropUser? user,
    bool? isLoading,
    String? errorMessage,
    bool? requiresVerification,
    bool? isVerified,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      requiresVerification: requiresVerification ?? this.requiresVerification,
      isVerified: isVerified ?? this.isVerified,
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
          state = state.copyWith(
            user: aeroUser,
            requiresVerification:
                false, // Automatically restored session doesn't require OTP
            isVerified: true,
            isLoading: false,
          );
          ref?.read(notificationProvider.notifier).loadNotifications();
          ref?.read(deliveryProvider.notifier).loadDeliveriesFromSupabase();
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
    state = state.copyWith(requiresVerification: false, isVerified: true);
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
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

      // Manual login: set requiresVerification = true, isVerified = false
      state = state.copyWith(
        user: aeroUser,
        requiresVerification: true,
        isVerified: false,
        isLoading: false,
        errorMessage: null,
      );

      ref?.read(notificationProvider.notifier).loadNotifications();
      ref?.read(deliveryProvider.notifier).loadDeliveriesFromSupabase();

      return true;
    } catch (error) {
      debugPrint('Supabase login failed: $error');
      state = state.copyWith(
        isLoading: false,
        errorMessage: formatAuthErrorMessage(error),
      );
      return false;
    }
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

      final response = await SupabaseService.client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'full_name': name.trim(),
          'phone_number': phoneNumber.trim(),
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
          final bytes = await logoFile.readAsBytes();
          final ext = logoFile.name.split('.').last.toLowerCase();
          final storagePath = '${authUser.id}/business_logo.$ext';

          await SupabaseService.client.storage
              .from('vendor-logos')
              .uploadBinary(
                storagePath,
                bytes,
                fileOptions: const FileOptions(upsert: true),
              );

          final logoUrl = SupabaseService.client.storage
              .from('vendor-logos')
              .getPublicUrl(storagePath);

          await SupabaseService.client
              .from('users')
              .update({'business_logo_url': logoUrl})
              .eq('id', authUser.id);
        } catch (storageError) {
          debugPrint(
            'Error uploading business logo during registration: $storageError',
          );
        }
      }

      if (sessionCreated) {
        // Read back the newly created public.users row
        final userRow = await SupabaseService.client
            .from('users')
            .select()
            .eq('id', authUser.id)
            .maybeSingle();

        if (userRow != null) {
          state = state.copyWith(
            user: AeroDropUser.fromMap(Map<String, dynamic>.from(userRow)),
            isLoading: false,
            errorMessage: null,
          );
        } else {
          state = state.copyWith(
            user: null,
            isLoading: false,
            errorMessage: null,
          );
        }
      } else {
        state = state.copyWith(
          user: null,
          isLoading: false,
          errorMessage: null,
        );
      }

      return true;
    } catch (error) {
      debugPrint('Supabase register failed: $error');
      state = state.copyWith(
        isLoading: false,
        errorMessage: formatAuthErrorMessage(error),
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
        if (normalizedEmail.contains(' ') ||
            !RegExp(
              r'^[A-Za-z0-9.!#$%&*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$',
            ).hasMatch(normalizedEmail)) {
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
        final bytes = await logoFile.readAsBytes();
        final ext = logoFile.name.split('.').last.toLowerCase();
        final storagePath = '$userId/avatar.$ext';

        await SupabaseService.client.storage
            .from('avatars')
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );

        avatarUrl = SupabaseService.client.storage
            .from('avatars')
            .getPublicUrl(storagePath);
      }

      await SupabaseService.client
          .from('users')
          .update({
            'avatar_url': avatarUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);

      state = state.copyWith(
        user: state.user!.copyWith(avatarUrl: avatarUrl),
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
    try {
      await SupabaseService.client
          .from('users')
          .update({
            'account_status': 'deleted',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);
      return null;
    } catch (e) {
      debugPrint('Delete user account failed: $e');
      return e.toString();
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<bool> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      if (SupabaseService.isConfigured) {
        await SupabaseService.client.auth.signOut();
      }
      if (ref != null) {
        ref!.invalidate(deliveryProvider);
        ref!.invalidate(notificationProvider);
        ref!.invalidate(droneProvider);
        ref!.invalidate(orderProvider);
        ref!.invalidate(productProvider);
        ref!.invalidate(vendorProvider);
        ref!.invalidate(weatherProvider);
      }
      state = const AuthState();
      return true;
    } catch (e) {
      debugPrint('Logout failed: $e');
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  // ponytail: switchRole kept as no-op stub — simulation mode removed,
  // but some screens still call it. Safe to delete once callers are cleaned up.
  void switchRole(dynamic role) {}
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
