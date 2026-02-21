import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/secure_storage.dart';
import 'package:frontend/features/login/data/auth_repository.dart';
import 'package:frontend/features/doctor/data/doctor_repository.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';

/// Simple service locator for app-wide singletons. Replace with a proper DI
/// solution (Provider/riverpod/get_it) if the project grows.
class AppDependencies {
  AppDependencies._();

  static final SecureStorage secureStorage = SecureStorage();
  static final ApiClient apiClient = ApiClient(secureStorage: secureStorage);
  static final AuthRepository authRepository = AuthRepository(
    apiClient: apiClient,
    secureStorage: secureStorage,
  );
  static final DoctorRepository doctorRepository = DoctorRepository(
    apiClient: apiClient,
  );
  static final AdminRepository adminRepository = AdminRepository(
    apiClient: apiClient,
  );

  static QueryClient createQueryClient({
    void Function(String error)? onError,
    void Function()? onSuccess,
  }) {
    return QueryClient(
      cache: QueryCache.instance,
      networkPolicy: NetworkPolicy.instance,
      onError: onError,
      onSuccess: onSuccess,
    );
  }
}
