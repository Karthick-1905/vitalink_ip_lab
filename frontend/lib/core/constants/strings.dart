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

	/// Secure storage keys.
	static const String tokenKey = 'auth_token';
	static const String userKey = 'auth_user';
}
