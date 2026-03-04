import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/core/constants/strings.dart';

/// Thin wrapper around [FlutterSecureStorage] to centralize key names and
/// serialization.
class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static String? _cachedToken;
  static Map<String, dynamic>? _cachedUser;

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: AppStrings.tokenKey, value: token);
  }

  Future<String?> readToken() async {
    final token = await _storage.read(key: AppStrings.tokenKey);
    _cachedToken = token;
    return token;
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    await _storage.delete(key: AppStrings.tokenKey);
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    _cachedUser = Map<String, dynamic>.from(user);
    await _storage.write(key: AppStrings.userKey, value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> readUser() async {
    final raw = await _storage.read(key: AppStrings.userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _cachedUser = Map<String, dynamic>.from(decoded);
        return decoded;
      }
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        _cachedUser = map;
        return map;
      }
      await clearUser();
      return null;
    } catch (_) {
      await clearUser();
      return null;
    }
  }

  Future<void> clearUser() async {
    _cachedUser = null;
    await _storage.delete(key: AppStrings.userKey);
  }

  /// Onboarding completion flag ──────────────────────────────────────────────

  Future<void> markOnboardingCompleted() async {
    await _storage.write(
      key: AppStrings.onboardingCompletedKey,
      value: 'true',
    );
  }

  Future<bool> isOnboardingCompleted() async {
    final value = await _storage.read(key: AppStrings.onboardingCompletedKey);
    return value == 'true';
  }

  Future<void> clearAll() async {
    _cachedToken = null;
    _cachedUser = null;
    await _storage.delete(key: AppStrings.tokenKey);
    await _storage.delete(key: AppStrings.userKey);
    await _storage.delete(key: AppStrings.onboardingCompletedKey);
  }

  String get sessionScope => _buildSessionScope(_cachedToken, _cachedUser);

  Future<String> readSessionScope() async {
    final token = await readToken();
    final user = await readUser();
    return _buildSessionScope(token, user);
  }

  String _buildSessionScope(String? token, Map<String, dynamic>? user) {
    String readString(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      return '';
    }

    final role = readString(
      user?['user_type_model'] ?? user?['user_type'] ?? user?['role'],
    );
    final identifier = readString(
      user?['login_id'] ?? user?['_id'] ?? user?['id'],
    );

    if (role.isNotEmpty && identifier.isNotEmpty) {
      return '${role.toUpperCase()}:$identifier';
    }
    if (identifier.isNotEmpty) {
      return 'USER:$identifier';
    }
    if (token != null && token.isNotEmpty) {
      final shortToken = token.length > 12 ? token.substring(0, 12) : token;
      return 'TOKEN:$shortToken';
    }
    return 'ANON';
  }
}
