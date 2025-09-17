// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: json['id'] as String?,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      role: $enumDecode(_$UserRoleEnumMap, json['role']),
      companyId: json['companyId'] as String?,
      companyName: json['companyName'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      lastLoginAt: json['lastLoginAt'] == null
          ? null
          : DateTime.parse(json['lastLoginAt'] as String),
      preferences: json['preferences'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'isActive': instance.isActive,
      'email': instance.email,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'phoneNumber': instance.phoneNumber,
      'role': _$UserRoleEnumMap[instance.role]!,
      'companyId': instance.companyId,
      'companyName': instance.companyName,
      'profileImageUrl': instance.profileImageUrl,
      'isEmailVerified': instance.isEmailVerified,
      'lastLoginAt': instance.lastLoginAt?.toIso8601String(),
      'preferences': instance.preferences,
    };

const _$UserRoleEnumMap = {
  UserRole.worker: 'worker',
  UserRole.manager: 'manager',
  UserRole.admin: 'admin',
};
