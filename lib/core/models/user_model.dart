enum UserRole { user, facultyStaff, admin }

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String avatarUrl;
  final String? phoneNumber;
  final String accountStatus; // 'active', 'suspended', 'deleted'
  final DateTime? suspendedAt;
  final String? suspensionReason;
  final DateTime? deletedAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.avatarUrl,
    this.phoneNumber,
    this.accountStatus = 'active',
    this.suspendedAt,
    this.suspensionReason,
    this.deletedAt,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? avatarUrl,
    String? phoneNumber,
    String? accountStatus,
    DateTime? suspendedAt,
    String? suspensionReason,
    DateTime? deletedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accountStatus: accountStatus ?? this.accountStatus,
      suspendedAt: suspendedAt ?? this.suspendedAt,
      suspensionReason: suspensionReason ?? this.suspensionReason,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {required UserRole role}) {
    return UserModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      role: role,
      avatarUrl: map['avatar_url']?.toString() ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      phoneNumber: map['phone_number']?.toString(),
      accountStatus: map['account_status']?.toString() ?? 'active',
      suspendedAt: map['suspended_at'] != null ? DateTime.tryParse(map['suspended_at'].toString()) : null,
      suspensionReason: map['suspension_reason']?.toString(),
      deletedAt: map['deleted_at'] != null ? DateTime.tryParse(map['deleted_at'].toString()) : null,
    );
  }
}
