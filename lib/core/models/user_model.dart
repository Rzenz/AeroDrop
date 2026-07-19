/// Flat user model matching the simplified public.users table.
class AeroDropUser {
  final String id;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String role; // 'user' | 'vendor' | 'admin'
  final String accountStatus; // 'active' | 'suspended' | 'deleted'
  final String? avatarUrl;
  final String? businessName;
  final String? businessCategory;
  final String? businessDescription;
  final String? campusLocationId;
  final String?
  vendorStatus; // null | 'pending' | 'active' | 'suspended' | 'rejected'
  final String? businessLogoUrl; // business logo URL field
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AeroDropUser._internal({
    required this.id,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    required this.role,
    this.accountStatus = 'active',
    this.avatarUrl,
    this.businessName,
    this.businessCategory,
    this.businessDescription,
    this.campusLocationId,
    this.vendorStatus,
    this.businessLogoUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory AeroDropUser({
    required String id,
    String? name,
    required String email,
    String? phoneNumber,
    dynamic role,
    String accountStatus = 'active',
    String? avatarUrl,
    String? businessName,
    String? businessCategory,
    String? businessDescription,
    String? campusLocationId,
    String? vendorStatus,
    String? businessLogoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    String roleStr = 'user';
    if (role is UserRole) {
      if (role == UserRole.admin) {
        roleStr = 'admin';
      } else if (role == UserRole.vendor) {
        roleStr = 'vendor';
      } else {
        roleStr = 'user';
      }
    } else if (role is String) {
      roleStr = role;
    }
    return AeroDropUser._internal(
      id: id,
      fullName: name ?? '',
      email: email,
      phoneNumber: phoneNumber,
      role: roleStr,
      accountStatus: accountStatus,
      avatarUrl: avatarUrl,
      businessName: businessName,
      businessCategory: businessCategory,
      businessDescription: businessDescription,
      campusLocationId: campusLocationId,
      vendorStatus: vendorStatus,
      businessLogoUrl: businessLogoUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @Deprecated('Use fullName instead')
  String get name => fullName;

  // ── Computed getters ──────────────────────────────────────────────────────

  bool get isUser => role == 'user';

  bool get isVendor =>
      role == 'vendor' && vendorStatus == 'active' && accountStatus == 'active';

  bool get isPendingVendor => role == 'user' && vendorStatus == 'pending';

  bool get isAdmin => role == 'admin' && accountStatus == 'active';

  bool get isActive => accountStatus == 'active';

  /// Display name: business name for vendors, full name otherwise.
  String get displayName =>
      (role == 'vendor' && businessName != null && businessName!.isNotEmpty)
      ? businessName!
      : fullName;

  // ── Factory ───────────────────────────────────────────────────────────────

  factory AeroDropUser.fromMap(Map<String, dynamic> map) {
    return AeroDropUser._internal(
      id: map['id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phoneNumber: map['phone_number']?.toString(),
      role: map['role']?.toString() ?? 'user',
      accountStatus: map['account_status']?.toString() ?? 'active',
      avatarUrl: map['avatar_url']?.toString(),
      businessName: map['business_name']?.toString(),
      businessCategory: map['business_category']?.toString(),
      businessDescription: map['business_description']?.toString(),
      campusLocationId: map['campus_location_id']?.toString(),
      vendorStatus: map['vendor_status']?.toString(),
      businessLogoUrl: map['business_logo_url']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  AeroDropUser copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? role,
    String? accountStatus,
    String? avatarUrl,
    String? businessName,
    String? businessCategory,
    String? businessDescription,
    String? campusLocationId,
    String? vendorStatus,
    String? businessLogoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AeroDropUser._internal(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      accountStatus: accountStatus ?? this.accountStatus,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      businessName: businessName ?? this.businessName,
      businessCategory: businessCategory ?? this.businessCategory,
      businessDescription: businessDescription ?? this.businessDescription,
      campusLocationId: campusLocationId ?? this.campusLocationId,
      vendorStatus: vendorStatus ?? this.vendorStatus,
      businessLogoUrl: businessLogoUrl ?? this.businessLogoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ponytail: kept for legacy screens that still reference UserRole.
// Remove once all callers are migrated to AeroDropUser getters.
@Deprecated('Use AeroDropUser.role string or AeroDropUser getters instead')
enum UserRole { user, vendor, admin }

typedef UserModel = AeroDropUser;
