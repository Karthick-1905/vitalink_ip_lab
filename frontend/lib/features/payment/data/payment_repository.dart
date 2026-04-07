import 'package:frontend/core/network/api_client.dart';

class PaymentRepository {
  PaymentRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  static const String _patientBasePath = '/api/patient';

  /// Create a payment order for a specific plan
  Future<Map<String, dynamic>> createPaymentOrder({
    required String planId,
  }) async {
    final response = await _apiClient.post(
      '$_patientBasePath/payments/order',
      data: {
        'plan_id': planId,
      },
    );
    if (response is! Map<String, dynamic>) {
      throw Exception('Invalid payment response');
    }
    return response;
  }

  /// Get current token balance
  Future<Map<String, dynamic>> getTokenBalance() async {
    final response = await _apiClient.get('$_patientBasePath/tokens/balance');
    if (response is! Map<String, dynamic>) {
      throw Exception('Invalid balance response');
    }
    return {
      'balance': (response['balance'] as num?)?.toDouble() ?? 0.0,
      'max_tokens': (response['max_tokens'] as num?)?.toInt() ?? 200,
      'currency': response['currency'] as String? ?? 'INR',
    };
  }

  /// Get paginated transaction history
  Future<Map<String, dynamic>> listTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '$_patientBasePath/tokens/transactions',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );
    if (response.isEmpty) {
      return {
        'transactions': [],
        'pagination': {'page': page, 'limit': limit, 'total': 0}
      };
    }
    return response;
  }
}
