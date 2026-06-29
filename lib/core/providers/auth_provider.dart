import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../config/simulation_config.dart';
import '../../providers/mock/auth_mock_provider.dart';
import '../services/supabase_service.dart';

String normalizeEmail(String email) {
  final normalized = email.trim().toLowerCase().replaceAll(
        RegExp(r'[\s\u00A0\u200B-\u200D\u2060]'),
        '',
      );

  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
    throw FormatException('Invalid email address');
  }

  return normalized;
}

String formatAuthErrorMessage(Object error) {
  final message = error.toString().toLowerCase();

  if (message.contains('faculty/staff')) {
    return 'Faculty/Staff must use a @uclm.edu email address.';
  }

  if (message.contains('rate limit') ||
      message.contains('over_email_send_rate_limit')) {
    return 'Too many sign-up attempts. Please wait a few minutes and try again with a different email address.';
  }

  if (message.contains('invalid_credentials')) {
    return 'The email or password is incorrect.';
  }

  if (message.contains('email address') && message.contains('invalid')) {
    return 'Please enter a valid email address.';
  }

  if (message.contains('weak_password')) {
    return 'Please choose a stronger password.';
  }

  return 'Authentication failed. Please try again.';
}

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;

  AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref? ref;

  static const String _adminEmail = 'admin.portal@uclm.edu';

  AuthNotifier([this.ref]) : super(AuthState()) {
    if (kSimulationMode && ref != null) {
      ref!.listen<AuthState>(
        authMockProvider,
        (previous, next) {
          state = next;
        },
        fireImmediately: true,
      );
    }
  }

  String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.facultyStaff:
        return 'faculty_staff';
      case UserRole.user:
        return 'student';
    }
  }

  UserRole _roleFromString(String? role, String email) {
    final normalizedEmail = normalizeEmail(email);
    final normalizedRole = (role ?? '').trim().toLowerCase();

    // Admin only if the email is the official admin email
    // AND the database role is admin.
    if (normalizedEmail == _adminEmail && normalizedRole == 'admin') {
      return UserRole.admin;
    }

    if (normalizedRole == 'faculty_staff' ||
        normalizedRole == 'faculty' ||
        normalizedRole == 'staff' ||
        normalizedRole == 'faculty/staff') {
      return UserRole.facultyStaff;
    }

    // Old database mistake: if non-admin account was saved as admin before,
    // treat it as faculty/staff if it is @uclm.edu.
    if (normalizedRole == 'admin' &&
        normalizedEmail != _adminEmail &&
        normalizedEmail.endsWith('@uclm.edu')) {
      return UserRole.facultyStaff;
    }

    return UserRole.user;
  }

  Future<void> _syncUserProfile({
    required String userId,
    required String email,
    required String name,
    required UserRole role,
  }) async {
    if (!SupabaseService.isConfigured) return;

    try {
      await SupabaseService.client.from('users').upsert(
        {
          'id': userId,
          'email': email,
          'name': name.trim(),
          'role': _roleToString(role),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'id',
      );
    } catch (error) {
      print('Supabase user sync failed: $error');
    }
  }

  Future<bool> login(String email, String password) async {
    if ((kSimulationMode || !SupabaseService.isConfigured) && ref != null) {
      return ref!.read(authMockProvider.notifier).login(email, password);
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final normalizedEmail = normalizeEmail(email);

      final response = await SupabaseService.client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );

      final authUser = response.user;
      if (authUser == null) {
        throw Exception('Login failed');
      }

      final authEmail = authUser.email ?? normalizedEmail;

      final profile = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      final metadata = authUser.userMetadata ?? {};

      final profileName = profile?['name']?.toString();
      final profileRole = profile?['role']?.toString();

      final name = profileName ??
          metadata['name']?.toString() ??
          authEmail.split('@').first;

      final role = _roleFromString(
        profileRole ?? metadata['role']?.toString(),
        authEmail,
      );

      // Keep public.users synced with auth email and correct role.
      await _syncUserProfile(
        userId: authUser.id,
        email: authEmail,
        name: name,
        role: role,
      );

      final loggedInUser = UserModel(
        id: authUser.id,
        name: name,
        email: authEmail,
        role: role,
        avatarUrl:
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      );

      state = state.copyWith(
        user: loggedInUser,
        isLoading: false,
        errorMessage: null,
      );

      return true;
    } catch (error) {
      print('Supabase login failed: $error');

      state = state.copyWith(
        isLoading: false,
        errorMessage: formatAuthErrorMessage(error),
      );

      return false;
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password,
    UserRole role,
  ) async {
    if ((kSimulationMode || !SupabaseService.isConfigured) && ref != null) {
      return ref!.read(authMockProvider.notifier).login(email, password);
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final normalizedEmail = normalizeEmail(email);

      UserRole effectiveRole = role;

      // Prevent normal users from becoming admin accidentally.
      if (effectiveRole == UserRole.admin && normalizedEmail != _adminEmail) {
        effectiveRole = UserRole.facultyStaff;
      }

      // Faculty/Staff must use @uclm.edu.
      if (effectiveRole == UserRole.facultyStaff &&
          !normalizedEmail.endsWith('@uclm.edu')) {
        throw FormatException(
          'Faculty/Staff must use a @uclm.edu email address.',
        );
      }

      final response = await SupabaseService.client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'name': name.trim(),
          'role': _roleToString(effectiveRole),
        },
      );

      final authUser = response.user;
      if (authUser == null) {
        throw Exception('Registration failed');
      }

      final authEmail = authUser.email ?? normalizedEmail;

      await _syncUserProfile(
        userId: authUser.id,
        email: authEmail,
        name: name,
        role: effectiveRole,
      );

      final newUser = UserModel(
        id: authUser.id,
        name: name.trim(),
        email: authEmail,
        role: effectiveRole,
        avatarUrl:
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      );

      state = state.copyWith(
        user: newUser,
        isLoading: false,
        errorMessage: null,
      );

      return true;
    } catch (error) {
      print('Supabase register failed: $error');

      state = state.copyWith(
        isLoading: false,
        errorMessage: formatAuthErrorMessage(error),
      );

      return false;
    }
  }

  Future<bool> updateProfile(String name, String email) async {
    final trimmedName = name.trim();

    if ((kSimulationMode || !SupabaseService.isConfigured) && ref != null) {
      if (state.user != null) {
        final updated = UserModel(
          id: state.user!.id,
          name: trimmedName,
          email: state.user!.email,
          role: state.user!.role,
          avatarUrl: state.user!.avatarUrl,
        );

        state = state.copyWith(user: updated);
      }

      return true;
    }

    if (state.user == null) {
      state = state.copyWith(errorMessage: 'No logged in user found.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final currentUser = SupabaseService.client.auth.currentUser;
      final userId = currentUser?.id ?? state.user!.id;
      final currentEmail = currentUser?.email ?? state.user!.email;

      // Update only user metadata, NOT auth email.
      await SupabaseService.client.auth.updateUser(
        UserAttributes(
          data: {
            'name': trimmedName,
            'role': _roleToString(state.user!.role),
          },
        ),
      );

      // Update public.users table.
      await SupabaseService.client.from('users').update({
        'name': trimmedName,
        'email': currentEmail,
        'role': _roleToString(state.user!.role),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);

      final updated = UserModel(
        id: userId,
        name: trimmedName,
        email: currentEmail,
        role: state.user!.role,
        avatarUrl: state.user!.avatarUrl,
      );

      state = state.copyWith(
        user: updated,
        isLoading: false,
        errorMessage: null,
      );

      return true;
    } catch (error) {
      print('Supabase profile update failed: $error');

      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Profile update failed. Please try again.',
      );

      return false;
    }
  }

  void switchRole(UserRole role) {
    if (kSimulationMode && ref != null) {
      ref!.read(authMockProvider.notifier).switchRole(role);
      return;
    }
  }

  void logout() {
    if (kSimulationMode && ref != null) {
      ref!.read(authMockProvider.notifier).logout();
      return;
    }

    if (SupabaseService.isConfigured) {
      SupabaseService.client.auth.signOut();
    }

    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});