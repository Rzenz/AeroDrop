enum UserRole { user, facultyStaff, admin }

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String avatarUrl;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.avatarUrl,
  });
}
