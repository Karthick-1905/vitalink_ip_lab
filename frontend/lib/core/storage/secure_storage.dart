import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/core/constants/strings.dart';

/// Thin wrapper around [FlutterSecureStorage] to centralize key names and
/// serialization.
class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) async {
    await _storage.write(key: AppStrings.tokenKey, value: token);
  }

  Future<String?> readToken() {
    return _storage.read(key: AppStrings.tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: AppStrings.tokenKey);
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(key: AppStrings.userKey, value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> readUser() async {
    final raw = await _storage.read(key: AppStrings.userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      await clearUser();
      return null;
    } catch (_) {
      await clearUser();
      return null;
    }
  }

  Future<void> clearUser() async {
    await _storage.delete(key: AppStrings.userKey);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: AppStrings.tokenKey);
    await _storage.delete(key: AppStrings.userKey);
  }
}
