import 'package:frontend/core/constants/strings.dart';

class LoginRequest {
  LoginRequest({required this.loginId, required this.password});

  final String loginId;
  final String password;

  String get path => AppStrings.loginPath;

  Map<String, dynamic> toJson() => {'login_id': loginId, 'password': password};
}

class UserModel {
  UserModel({
    required this.id,
    required this.loginId,
    required this.userType,
    required this.isActive,
    this.profileId,
    this.userTypeModel,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['_id'] ?? json['id'] ?? '') as String,
      loginId: (json['login_id'] ?? '') as String,
      userType: (json['user_type'] ?? '') as String,
      isActive: (json['is_active'] ?? true) as bool,
      profileId: json['profile_id'] as String?,
      userTypeModel: json['user_type_model'] as String?,
    );
  }

  final String id;
  final String loginId;
  final String userType;
  final bool isActive;
  final String? profileId;
  final String? userTypeModel;

  bool get isDoctor => userType.toUpperCase() == 'DOCTOR';
  bool get isPatient => userType.toUpperCase() == 'PATIENT';
  bool get isAdmin => userType.toUpperCase() == 'ADMIN';
}

class LoginResponse {
  LoginResponse({required this.token, required this.user});

  final String token;
  final UserModel user;
}
