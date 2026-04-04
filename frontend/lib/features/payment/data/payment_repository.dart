import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/secure_storage.dart';

class PaymentRepository {
  PaymentRepository({
    required ApiClient apiClient,
    SecureStorage? secureStorage,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage ?? SecureStorage();

  final ApiClient _apiClient;
  final SecureStorage _secureStorage;

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
  Future<double> getTokenBalance() async {
    final response = await _apiClient.get('$_patientBasePath/tokens/balance');
    final balance = response['balance'];
    if (balance is num) {
      return balance.toDouble();
    }
    throw Exception('Invalid balance response: expected num, got ${balance.runtimeType}');
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
