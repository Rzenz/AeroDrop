import '../../core/models/user_model.dart';

class RoleGuard {
  static bool isAdmin(UserModel? user) {
    return user != null && user.isAdmin;
  }

  static bool isUser(UserModel? user) {
    return user != null && !user.isAdmin;
  }
}
