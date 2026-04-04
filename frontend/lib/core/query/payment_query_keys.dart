import 'package:frontend/core/di/app_dependencies.dart';

class PaymentQueryKeys {
  PaymentQueryKeys._();

  static List<Object> all() => ['payment', _scope];

  static List<Object> tokenBalance() => [...all(), 'token_balance'];
  static List<Object> transactions() => [...all(), 'transactions'];
  static List<Object> transactionsPaginated(int page, int limit) =>
      [...all(), 'transactions', page, limit];

  static String get _scope => AppDependencies.secureStorage.sessionScope;
}
