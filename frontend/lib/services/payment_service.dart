import 'package:frontend/core/network/api_client.dart';

class PaymentService {
  PaymentService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  static const String _paymentsBasePath = '/api/patients/payments';
  static const String _tokensBasePath = '/api/patients/tokens';

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
    final response = await _apiClient.get('$_tokensBasePath/balance');
    return response['data'] as Map<String, dynamic>;
  }

  /// Get feature costs
  Future<Map<String, dynamic>> getFeatureCosts() async {
    final response = await _apiClient.get('$_tokensBasePath/feature-costs');
    return response['data'] as Map<String, dynamic>;
  }

  /// Get paginated transaction history
  Future<Map<String, dynamic>> listTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '$_tokensBasePath/transactions',
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

  /// Get token cost for a specific feature (client-side reference)
  /// This matches backend costs from patient-token.service.ts
  static const Map<String, int> FEATURE_COSTS = {
    'DOCTOR_CONSULTATION': 100,
    'REPORT_UPLOAD': 25,
    'HEALTH_LOG_UPDATE': 10,
    'PROFILE_UPDATE': 15,
    'DOSAGE_LOG': 5,
    'VIDEO_CALL': 50,
  };

  /// Check if user has sufficient tokens for a feature
  bool hasSufficientTokens(int currentBalance, String feature) {
    final cost = FEATURE_COSTS[feature] ?? 0;
    return currentBalance >= cost;
  }
}
