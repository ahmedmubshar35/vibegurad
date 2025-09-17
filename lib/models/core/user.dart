import 'package:json_annotation/json_annotation.dart';
import 'base_model.dart';
import '../../enums/user_role.dart';

part 'user.g.dart';

@JsonSerializable()
class User extends BaseModel {
  @JsonKey(name: 'email')
  final String email;
  
  @JsonKey(name: 'firstName')
  final String firstName;
  
  @JsonKey(name: 'lastName')
  final String lastName;
  
  @JsonKey(name: 'phoneNumber')
  final String? phoneNumber;
  
  @JsonKey(name: 'role')
  final UserRole role;
  
  @JsonKey(name: 'companyId')
  final String? companyId;
  
  @JsonKey(name: 'companyName')
  final String? companyName;
  
  @JsonKey(name: 'profileImageUrl')
  final String? profileImageUrl;
  
  @JsonKey(name: 'isEmailVerified')
  final bool isEmailVerified;
  
  @JsonKey(name: 'lastLoginAt')
  final DateTime? lastLoginAt;
  
  @JsonKey(name: 'preferences')
  final Map<String, dynamic>? preferences;

  const User({
    super.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    required this.role,
    this.companyId,
    this.companyName,
    this.profileImageUrl,
    this.isEmailVerified = false,
    this.lastLoginAt,
    this.preferences,
    super.createdAt,
    super.updatedAt,
    super.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  
  @override
  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  User copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    UserRole? role,
    String? companyId,
    String? companyName,
    String? profileImageUrl,
    bool? isEmailVerified,
    DateTime? lastLoginAt,
    Map<String, dynamic>? preferences,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // Computed properties
  String get fullName => '$firstName $lastName';
  
  String get displayName => lastName.isNotEmpty ? '$firstName ${lastName[0]}.' : firstName;
  
  String get initials => '${firstName[0]}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();
  
  bool get isWorker => role == UserRole.worker;
  
  bool get isManager => role == UserRole.manager;
  
  bool get isAdmin => role == UserRole.admin;
  
  bool get hasCompany => companyId != null && companyId!.isNotEmpty;
  
  String get formattedPhoneNumber {
    if (phoneNumber == null || phoneNumber!.isEmpty) return 'Not provided';
    return phoneNumber!;
  }
  
  String get formattedLastLogin {
    if (lastLoginAt == null) return 'Never';
    final now = DateTime.now();
    final difference = now.difference(lastLoginAt!);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  // Helper methods
  bool hasPermission(String permission) {
    switch (role) {
      case UserRole.admin:
        return true; // Admins have all permissions
      case UserRole.manager:
        return permission != 'admin_only'; // Managers have most permissions
      case UserRole.worker:
        return permission == 'worker' || permission == 'read_only';
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'role': role.name,
      'companyId': companyId,
      'companyName': companyName,
      'profileImageUrl': profileImageUrl,
      'isEmailVerified': isEmailVerified,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'preferences': preferences,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory User.fromFirestore(Map<String, dynamic> data, String id) {
    return User(
      id: id,
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      phoneNumber: data['phoneNumber'],
      role: UserRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => UserRole.worker,
      ),
      companyId: data['companyId'],
      companyName: data['companyName'],
      profileImageUrl: data['profileImageUrl'],
      isEmailVerified: data['isEmailVerified'] ?? false,
      lastLoginAt: data['lastLoginAt'] != null 
          ? DateTime.parse(data['lastLoginAt']) 
          : null,
      preferences: data['preferences'],
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null 
          ? DateTime.parse(data['createdAt']) 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? DateTime.parse(data['updatedAt']) 
          : null,
    );
  }
}
