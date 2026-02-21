import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
    String? baseUrl,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? AppStrings.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 20),
              ),
            ),
       _secureStorage = secureStorage ?? SecureStorage();

  final Dio _dio;
  final SecureStorage _secureStorage;
  static const int _maxGetRetries = 2;
  static const Duration _retryBaseDelay = Duration(milliseconds: 300);

  void _logDebug(String message) {
    if (kDebugMode) debugPrint(message);
  }

  Future<Response<Map<String, dynamic>>> _sendWithRetry(
    Future<Response<Map<String, dynamic>>> Function() send, {
    bool retryOnFailure = false,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        return await send();
      } on DioException catch (e) {
        final shouldRetry =
            retryOnFailure &&
            attempt < _maxGetRetries &&
            _isTransientFailure(e);
        if (!shouldRetry) rethrow;

        attempt++;
        final wait = Duration(
          milliseconds: _retryBaseDelay.inMilliseconds * (1 << (attempt - 1)),
        );
        _logDebug(
          'Transient API failure. Retrying in ${wait.inMilliseconds}ms (attempt $attempt/$_maxGetRetries)',
        );
        await Future.delayed(wait);
      }
    }
  }

  bool _isTransientFailure(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        return code == 429 || code >= 500;
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return false;
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    bool authenticated = true,
  }) async {
    try {
      final headers = await _buildHeaders(includeAuth: authenticated);
      final response = await _sendWithRetry(
        () => _dio.post<Map<String, dynamic>>(
          path,
          data: data,
          options: Options(headers: headers),
        ),
      );
      return _normalizeResponse(response);
    } on DioException catch (e) {
      throw ApiException(
        _extractMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    try {
      final headers = await _buildHeaders(includeAuth: authenticated);
      _logDebug('GET Request to: $path');
      final response = await _sendWithRetry(
        () => _dio.get<Map<String, dynamic>>(
          path,
          queryParameters: queryParameters,
          options: Options(headers: headers),
        ),
        retryOnFailure: true,
      );
      _logDebug('GET Response status: ${response.statusCode}');
      return _normalizeResponse(response);
    } on DioException catch (e) {
      throw ApiException(
        _extractMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
    bool authenticated = true,
  }) async {
    try {
      final headers = await _buildHeaders(includeAuth: authenticated);
      _logDebug('PUT Request to: $path');
      final response = await _sendWithRetry(
        () => _dio.put<Map<String, dynamic>>(
          path,
          data: data,
          options: Options(headers: headers),
        ),
      );
      _logDebug('PUT Response status: ${response.statusCode}');
      return _normalizeResponse(response);
    } on DioException catch (e) {
      throw ApiException(
        _extractMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? data,
    bool authenticated = true,
  }) async {
    try {
      final headers = await _buildHeaders(includeAuth: authenticated);
      final response = await _sendWithRetry(
        () => _dio.patch<Map<String, dynamic>>(
          path,
          data: data,
          options: Options(headers: headers),
        ),
      );
      return _normalizeResponse(response);
    } on DioException catch (e) {
      throw ApiException(
        _extractMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? data,
    bool authenticated = true,
  }) async {
    try {
      final headers = await _buildHeaders(includeAuth: authenticated);
      _logDebug('DELETE Request to: $path');
      final response = await _sendWithRetry(
        () => _dio.delete<Map<String, dynamic>>(
          path,
          data: data,
          options: Options(headers: headers),
        ),
      );
      _logDebug('DELETE Response status: ${response.statusCode}');
      return _normalizeResponse(response);
    } on DioException catch (e) {
      throw ApiException(
        _extractMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Returns the full response body without stripping the `data` wrapper.
  /// Useful for paginated responses that include `pagination` alongside `data`.
  Future<Map<String, dynamic>> getRaw(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    try {
      final headers = await _buildHeaders(includeAuth: authenticated);
      final response = await _sendWithRetry(
        () => _dio.get<Map<String, dynamic>>(
          path,
          queryParameters: queryParameters,
          options: Options(headers: headers),
        ),
        retryOnFailure: true,
      );
      final statusCode = response.statusCode ?? 500;
      final body = response.data ?? <String, dynamic>{};
      if (statusCode >= 400 || body['success'] == false) {
        throw ApiException(
          body['message'] as String? ?? 'Request failed',
          statusCode: statusCode,
        );
      }
      return body;
    } on DioException catch (e) {
      throw ApiException(
        _extractMessage(e),
        statusCode: e.response?.statusCode,
      );
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
        _logDebug('Authorization header attached');
      }
    }
    return headers;
  }

  Map<String, dynamic> _normalizeResponse(
    Response<Map<String, dynamic>> response,
  ) {
    final statusCode = response.statusCode ?? 500;
    final body = response.data ?? <String, dynamic>{};

    if (statusCode >= 400 || body['success'] == false) {
      throw ApiException(
        body['message'] as String? ?? 'Request failed',
        statusCode: statusCode,
      );
    }

    // Handle the backend's ApiResponse format with 'data' wrapper
    if (body.containsKey('data')) {
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is List) {
        return {'items': data};
      }
      // If data is null or empty, return it as is
      return data ?? <String, dynamic>{};
    }

    if (body.isNotEmpty) return body;
    return <String, dynamic>{};
  }

  String _extractMessage(DioException e) {
    final res = e.response;
    _logDebug('API Error - Status Code: ${res?.statusCode}');
    _logDebug('API Error - Response: ${res?.data}');

    if (res?.statusCode == 401) {
      _logDebug('Authentication failed - token may be invalid or expired');
    }

    if (res?.data is Map<String, dynamic>) {
      final map = res?.data as Map<String, dynamic>;
      if (map['message'] is String) return map['message'] as String;
      if (map['error'] is String) return map['error'] as String;
    }
    return e.message ?? 'Network error';
  }
}
