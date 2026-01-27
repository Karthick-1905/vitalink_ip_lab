// import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:frontend/core/constants/strings.dart';
import 'package:frontend/core/storage/secure_storage.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Lightweight API client that attaches bearer tokens when available and
/// normalizes the backend's ApiResponse shape.
class ApiClient {
  ApiClient({
    Dio? dio,
    SecureStorage? secureStorage,
    String baseUrl = AppStrings.apiBaseUrl,
  })  : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl)),
        _secureStorage = secureStorage ?? SecureStorage();

  final Dio _dio;
  final SecureStorage _secureStorage;

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    bool authenticated = true,
  }) async {
    try {
      final headers = await _buildHeaders(includeAuth: authenticated);
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(headers: headers),
      );
      return _normalizeResponse(response);
    } on DioException catch (e) {
      throw ApiException(_extractMessage(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    try {
      final headers = await _buildHeaders(includeAuth: authenticated);
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return _normalizeResponse(response);
    } on DioException catch (e) {
      throw ApiException(_extractMessage(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, String>> _buildHeaders({required bool includeAuth}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await _secureStorage.readToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Map<String, dynamic> _normalizeResponse(Response<Map<String, dynamic>> response) {
    final statusCode = response.statusCode ?? 500;
    final body = response.data ?? <String, dynamic>{};

    if (statusCode >= 400 || body['success'] == false) {
      throw ApiException(body['message'] as String? ?? 'Request failed', statusCode: statusCode);
    }

    if (body.containsKey('data')) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is List) return {'items': data};
    }

    if (body.isNotEmpty) return body;
    return <String, dynamic>{};
  }

  String _extractMessage(DioException e) {
    final res = e.response;
    if (res?.data is Map<String, dynamic>) {
      final map = res?.data as Map<String, dynamic>;
      if (map['message'] is String) return map['message'] as String;
      if (map['error'] is String) return map['error'] as String;
    }
    return e.message ?? 'Network error';
  }
}
