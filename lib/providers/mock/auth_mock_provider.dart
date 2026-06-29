import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../mock_data/users_mock.dart';

class AuthMockNotifier extends StateNotifier<AuthState> {
  AuthMockNotifier() : super(AuthState());

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 500));

    // ponytail: accept any email/password, defaulting to admin/user based on domain or email prefix
    UserModel matchedUser;
    final lowerEmail = email.toLowerCase();
    if (lowerEmail.endsWith('@uclm.edu')) {
      matchedUser = mockUsers.firstWhere((u) => u.role == UserRole.admin);
    } else {
      matchedUser = mockUsers.firstWhere((u) => u.role == UserRole.user);
    }

    // Prefill input email if user typed a specific one
    final customUser = UserModel(
      id: matchedUser.id,
      name: matchedUser.name,
      email: email,
      role: matchedUser.role,
      avatarUrl: matchedUser.avatarUrl,
    );

    state = state.copyWith(user: customUser, isLoading: false);
    return true;
  }

  void switchRole(UserRole role) {
    if (state.user != null) {
      final updated = UserModel(
        id: state.user!.id,
        name: role == UserRole.admin ? 'Admin Commander' : 'John Doe',
        email: role == UserRole.admin ? 'admin.portal@uclm.edu' : 'john.doe@gmail.com',
        role: role,
        avatarUrl: state.user!.avatarUrl,
      );
      state = state.copyWith(user: updated);
    } else {
      final defaultUser = mockUsers.firstWhere((u) => u.role == role);
      state = state.copyWith(user: defaultUser);
    }
  }

  void logout() {
    state = AuthState();
  }
}

final authMockProvider = StateNotifierProvider<AuthMockNotifier, AuthState>((ref) {
  return AuthMockNotifier();
});
