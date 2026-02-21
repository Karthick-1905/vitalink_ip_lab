class AppStrings {
  AppStrings._();


	/// Base URL for the backend API.
	/// Note: Use http for local dev to avoid TLS/host issues in Flutter web.
	static const String apiBaseUrl = 'https://vitalink-ip-lab-1.onrender.com';

  /// Auth endpoints.
  static const String loginPath = '/api/auth/login';

  /// Doctor endpoints.
  static const String doctorPatientsPath = '/api/doctors/patients';
  static const String doctorProfilePath = '/api/doctors/profile';
  static const String doctorGetDoctorsPath = '/api/doctors/doctors';

  /// Admin endpoints.
  static const String adminBasePath = '/api/admin';
  static const String adminDoctorsPath = '/api/admin/doctors';
  static const String adminPatientsPath = '/api/admin/patients';
  static const String adminReassignPath = '/api/admin/reassign';
  static const String adminAuditLogsPath = '/api/admin/audit-logs';
  static const String adminConfigPath = '/api/admin/config';
  static const String adminNotificationsPath =
      '/api/admin/notifications/broadcast';
  static const String adminBatchPath = '/api/admin/users/batch';
  static const String adminHealthPath = '/api/admin/system/health';
  static const String adminResetPasswordPath = '/api/admin/users';

  /// Statistics endpoints.
  static const String statisticsAdminPath = '/api/statistics/admin';
  static const String statisticsTrendsPath = '/api/statistics/trends';
  static const String statisticsCompliancePath = '/api/statistics/compliance';
  static const String statisticsWorkloadPath = '/api/statistics/workload';

  /// Secure storage keys.
  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
}
