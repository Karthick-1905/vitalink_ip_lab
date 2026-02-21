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

  static String _readString(dynamic value) {
    if (value is String) return value;
    if (value is Map) {
      const nestedKeys = [
        '_id',
        'id',
        'name',
        'value',
        'type',
        'role',
        'user_type',
        'userType',
        'label',
      ];
      for (final key in nestedKeys) {
        final nested = _readString(value[key]);
        if (nested.isNotEmpty) return nested;
      }
    }
    return '';
  }

  static bool _readBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    return fallback;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profile_id'];
    final profileMap = profile is Map<String, dynamic> ? profile : null;
    final roleFromUser = _readString(json['user_type']);
    final roleFromModel = _readString(json['user_type_model']);
    final roleFromRole = _readString(json['role']);
    final roleFromProfile = _readString(profileMap?['user_type']);
    final roleModelFromProfile = _readString(profileMap?['user_type_model']);

    return UserModel(
      id: _readString(json['_id']).isNotEmpty
          ? _readString(json['_id'])
          : _readString(json['id']),
      loginId: _readString(json['login_id']),
      userType: roleFromUser.isNotEmpty
          ? roleFromUser
          : roleFromRole.isNotEmpty
          ? roleFromRole
          : roleFromProfile,
      isActive: _readBool(json['is_active'], fallback: true),
      profileId: _readString(profile).isNotEmpty ? _readString(profile) : null,
      userTypeModel: roleFromModel.isNotEmpty
          ? roleFromModel
          : roleModelFromProfile.isNotEmpty
          ? roleModelFromProfile
          : null,
    );
  }

  final String id;
  final String loginId;
  final String userType;
  final bool isActive;
  final String? profileId;
  final String? userTypeModel;

  String _normalize(String? raw) =>
      raw
          ?.trim()
          .toUpperCase()
          .replaceAll(' ', '_')
          .replaceAll('-', '_') ??
      '';

  String get _roleSource {
    if (userTypeModel != null && userTypeModel!.trim().isNotEmpty) {
      return _normalize(userTypeModel);
    }
    return _normalize(userType);
  }

  bool _matchesRole(String target) {
    final role = _roleSource;
    return role == target ||
        role.endsWith('_$target') ||
        role.contains(target);
  }

  bool get isDoctor => _matchesRole('DOCTOR');
  bool get isPatient => _matchesRole('PATIENT');
  bool get isAdmin => _matchesRole('ADMIN');
}

class LoginResponse {
  LoginResponse({required this.token, required this.user});

  final String token;
  final UserModel user;
}
