import 'package:flutter/material.dart';
import 'package:frontend/features/login/login_page.dart';
import 'package:frontend/features/patient/patient_page.dart';
import 'package:frontend/features/patient/patient_home_page.dart';
import 'package:frontend/features/patient/patient_records_page.dart';
import 'package:frontend/features/patient/patient_profile_page.dart';
import 'package:frontend/features/patient/patient_update_inr_page.dart';
import 'package:frontend/features/patient/patient_take_dosage_page.dart';
import 'package:frontend/features/doctor/doctor_dashboard_page.dart';
import 'package:frontend/features/doctor/add_patient_page.dart';

class AppRoutes {
	static const String login = '/login';
	static const String patient = '/patient';
	static const String patientHome = '/patient-home';
	static const String patientRecords = '/patient-records';
	static const String patientProfile = '/patient-profile';
	static const String patientUpdateINR = '/patient-update-inr';
	static const String patientTakeDosage = '/patient-take-dosage';
	static const String doctorDashboard = '/doctor-dashboard';
	static const String doctorAddPatient = '/doctor-add-patient';
	// Add more route names here as needed, e.g.
	// static const String home = '/home';
}

class AppRouter {
	static const String initialRoute = AppRoutes.login;

	static final Map<String, WidgetBuilder> routes = {
		AppRoutes.login: (_) => const LoginPage(),
		AppRoutes.patient: (_) => const PatientPage(),
		AppRoutes.patientHome: (_) => const PatientHomePage(),
		AppRoutes.patientUpdateINR: (_) => const PatientUpdateINRPage(),
		AppRoutes.patientTakeDosage: (_) => const PatientTakeDosagePage(),
		AppRoutes.patientRecords: (_) => const PatientRecordsPage(),
		AppRoutes.patientProfile: (_) => const PatientProfilePage(),
		AppRoutes.doctorDashboard: (_) => const DoctorDashboardPage(),
		AppRoutes.doctorAddPatient: (_) => const AddPatientPage(),
		// Add other routes here, e.g.
		// AppRoutes.home: (_) => const HomePage(),
	};
}

