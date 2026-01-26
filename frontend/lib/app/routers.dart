import 'package:flutter/material.dart';
import 'package:frontend/features/login/login_page.dart';
import 'package:frontend/features/patient/patient_page.dart';
import 'package:frontend/features/patient/patient_home_page.dart';
import 'package:frontend/features/doctor/doctor_dashboard_page.dart';

class AppRoutes {
	static const String login = '/login';
	static const String patient = '/patient';
	static const String patientHome = '/patient-home';
	static const String doctorDashboard = '/doctor-dashboard';
	// Add more route names here as needed, e.g.
	// static const String home = '/home';
}

class AppRouter {
	static const String initialRoute = AppRoutes.login;

	static final Map<String, WidgetBuilder> routes = {
		AppRoutes.login: (_) => const LoginPage(),
		AppRoutes.patient: (_) => const PatientPage(),
		AppRoutes.patientHome: (_) => const PatientHomePage(),
		AppRoutes.doctorDashboard: (_) => const DoctorDashboardPage(),
		// Add other routes here, e.g.
		// AppRoutes.home: (_) => const HomePage(),
	};
}

