import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

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
  AuthNotifier() : super(AuthState());

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 800));

    UserModel? loggedInUser;
    if (email.toLowerCase().contains('admin')) {
      loggedInUser = UserModel(
        id: 'admin_1',
        name: 'Admin Commander',
        email: email,
        role: UserRole.admin,
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      );
    } else {
      loggedInUser = UserModel(
        id: 'user_1',
        name: 'John Doe',
        email: email,
        role: UserRole.user,
        avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      );
    }

    state = state.copyWith(user: loggedInUser, isLoading: false);
    return true;
  }

  Future<bool> register(String name, String email, String password, UserRole role) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 800));

    final newUser = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      role: role,
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
    );

    state = state.copyWith(user: newUser, isLoading: false);
    return true;
  }

  void updateProfile(String name, String email) {
    if (state.user != null) {
      final updated = UserModel(
        id: state.user!.id,
        name: name,
        email: email,
        role: state.user!.role,
        avatarUrl: state.user!.avatarUrl,
      );
      state = state.copyWith(user: updated);
    }
  }

  void logout() {
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
