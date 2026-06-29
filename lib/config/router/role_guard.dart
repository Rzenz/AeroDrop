import '../../core/models/user_model.dart';

class RoleGuard {
  static bool isAdmin(UserModel? user) {
    return user != null && user.role == UserRole.admin;
  }

  static bool isUser(UserModel? user) {
    return user != null && user.role != UserRole.admin;
  }
}