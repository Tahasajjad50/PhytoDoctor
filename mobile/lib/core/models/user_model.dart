class UserModel {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String role;
  final bool isActive;
  final String? accessToken;
  final String? phone;
  final String? designation;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.accessToken,
    this.phone,
    this.designation,
  });

  bool get isEmployee => role.toUpperCase() == 'EMPLOYEE';
  bool get isManager => role.toUpperCase() == 'MANAGER';
  bool get isOwner => role.toUpperCase() == 'OWNER';
  bool get isAdmin => isOwner || isManager;

  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? 'EMPLOYEE',
      isActive: json['is_active'] as bool? ?? true,
      accessToken: token ?? json['access_token'] as String?,
      phone: json['phone'] as String?,
      designation: json['designation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'role': role,
      'is_active': isActive,
      'access_token': accessToken,
      'phone': phone,
      'designation': designation,
    };
  }
}

class CreatedAccountModel {
  final String id;
  final String fullName;
  final String email;
  final String username;
  final String role;
  final bool isActive;
  final String? phone;
  final String? designation;
  final String? managerId;
  final DateTime createdAt;
  final String? createdById;
  final String? createdByName;
  final String? loginPassword;

  CreatedAccountModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.username,
    required this.role,
    required this.isActive,
    this.phone,
    this.designation,
    this.managerId,
    required this.createdAt,
    this.createdById,
    this.createdByName,
    this.loginPassword,
  });

  bool get isEmployee => role.toUpperCase() == 'EMPLOYEE';
  bool get isManager => role.toUpperCase() == 'MANAGER';
  bool get isOwner => role.toUpperCase() == 'OWNER';

  factory CreatedAccountModel.fromJson(Map<String, dynamic> json) {
    return CreatedAccountModel(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? 'EMPLOYEE',
      isActive: json['is_active'] as bool? ?? true,
      phone: json['phone'] as String?,
      designation: json['designation'] as String?,
      managerId: json['manager_id'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? DateTime.now() : DateTime.now(),
      createdById: json['created_by_id'] as String?,
      createdByName: json['created_by_name'] as String?,
      loginPassword: json['login_password'] as String?,
    );
  }
}

