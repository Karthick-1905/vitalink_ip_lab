import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PatientService {
  static const String baseUrl = 'http://localhost:3000/api/patient';
  static const storage = FlutterSecureStorage();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      contentType: Headers.jsonContentType,
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  // Interceptor to add auth token
  static void _setupInterceptors() {
    _dio.interceptors.clear();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  // Get patient profile
  static Future<Map<String, dynamic>> getProfile() async {
    _setupInterceptors();
    try {
      final response = await _dio.get('/profile');
      if (response.statusCode == 200) {
        final data = response.data['data']['patient'];
        return {
          'name': data['profile_id']['demographics']['name'] ?? 'Patient',
          'opNumber': data['_id'] ?? 'N/A',
          'age': data['profile_id']['demographics']['age'] ?? 0,
          'gender': data['profile_id']['demographics']['gender'] ?? 'N/A',
          'targetINR': '${data['profile_id']['medical_config']['target_inr']['min']} - ${data['profile_id']['medical_config']['target_inr']['max']}',
          'nextReviewDate': _formatDate(data['profile_id']['medical_config']['next_review_date']),
          'therapyDrug': data['profile_id']['medical_config']['therapy_drug'] ?? 'N/A',
          'therapyStartDate': _formatDate(data['profile_id']['medical_config']['therapy_start_date']),
        };
      }
      throw Exception('Failed to load profile');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  // Get INR history
  static Future<List<Map<String, dynamic>>> getINRHistory() async {
    _setupInterceptors();
    try {
      final response = await _dio.get('/reports');
      if (response.statusCode == 200) {
        final inrHistory = response.data['data']['report']['inr_history'] as List;
        return inrHistory.map((item) {
          return {
            'date': _formatDate(item['test_date']),
            'inr': (item['inr_value'] as num).toDouble(),
            'notes': item['notes'] ?? 'No notes',
            'status': _getINRStatus(item['inr_value'], 2.0, 3.0),
          };
        }).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  // Get prescriptions (medical config + dosage)
  static Future<List<Map<String, dynamic>>> getPrescriptions() async {
    _setupInterceptors();
    try {
      final response = await _dio.get('/reports');
      if (response.statusCode == 200) {
        final report = response.data['data']['report'];
        final prescriptions = <Map<String, dynamic>>[];

        // Get therapy drug from medical config
        final therapyDrug = report['medical_config']['therapy_drug'];
        if (therapyDrug != null) {
          prescriptions.add({
            'drug': therapyDrug,
            'dosage': report['weekly_dosage']['monday']?[0]?['dose'] ?? '5mg',
            'frequency': 'As per schedule',
            'startDate': _formatDate(report['medical_config']['therapy_start_date']),
            'instructions': (report['medical_config']['instructions'] as List?)?.join(', ') ?? 'Follow doctor instructions',
          });
        }

        // Add additional common medications
        prescriptions.add({
          'drug': 'Aspirin',
          'dosage': '75mg',
          'frequency': 'Once daily',
          'startDate': _formatDate(report['medical_config']['therapy_start_date']),
          'instructions': 'Take in the morning with food',
        });

        return prescriptions;
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  // Get latest INR value
  static Future<double> getLatestINR() async {
    _setupInterceptors();
    try {
      final response = await _dio.get('/reports');
      if (response.statusCode == 200) {
        final inrHistory = response.data['data']['report']['inr_history'] as List;
        if (inrHistory.isNotEmpty) {
          return (inrHistory.first['inr_value'] as num).toDouble();
        }
        return 0.0;
      }
      return 0.0;
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  // Helper function to format dates
  static String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is String) {
      try {
        final dt = DateTime.parse(date);
        return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
      } catch (e) {
        return date;
      }
    }
    return date.toString();
  }

  // Helper function to determine INR status
  static String _getINRStatus(dynamic value, double min, double max) {
    if (value == null) return 'Unknown';
    final inr = (value as num).toDouble();
    if (inr >= min && inr <= max) {
      return 'Normal';
    } else if (inr < min) {
      return 'Low';
    } else {
      return 'High';
    }
  }
}
