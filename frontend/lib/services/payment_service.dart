import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/secure_storage.dart';

class PaymentService {
  PaymentService({
    required ApiClient apiClient,
    SecureStorage? secureStorage,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage ?? SecureStorage();

  final ApiClient _apiClient;
  final SecureStorage _secureStorage;

  static const String _paymentsBasePath = '/api/payments';

  /// Create a payment order for a specific plan
  Future<Map<String, dynamic>> createPaymentOrder({
    required String planId,
  }) async {
    final response = await _apiClient.post(
      '$_paymentsBasePath/order',
      data: {
        'plan_id': planId,
      },
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Get current token balance
  Future<Map<String, dynamic>> getTokenBalance() async {
    final response = await _apiClient.get('$_paymentsBasePath/balance');
    return response['data'] as Map<String, dynamic>;
  }

  /// Get paginated transaction history
  Future<Map<String, dynamic>> listTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '$_paymentsBasePath/transactions',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Handle payment verification (called from payment failure/success screen)
  Future<bool> verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    try {
      final response = await _apiClient.post(
        '$_paymentsBasePath/verify',
        data: {
          'razorpay_payment_id': paymentId,
          'razorpay_order_id': orderId,
          'razorpay_signature': signature,
        },
      );
      return (response['success'] as bool?) ?? false;
    } catch (e) {
      return false;
    }
  }
}
