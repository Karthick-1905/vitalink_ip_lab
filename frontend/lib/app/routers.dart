import 'package:flutter/material.dart';
import 'package:frontend/features/login/login_page.dart';
import 'package:frontend/features/patient/patient_page.dart';
import 'package:frontend/features/patient/patient_records_page.dart';
import 'package:frontend/features/patient/patient_profile_page.dart';
import 'package:frontend/features/patient/patient_update_inr_page.dart';
import 'package:frontend/features/patient/patient_take_dosage_page.dart';
import 'package:frontend/features/patient/patient_health_reports_page.dart';
import 'package:frontend/features/doctor/doctor_dashboard_page.dart';
import 'package:frontend/features/doctor/add_patient_page.dart';
import 'package:frontend/features/onboarding/onboarding_page.dart';

class AppRoutes {
	static const String login = '/login';
	static const String onboarding = '/onboarding';
	static const String patient = '/patient';
	static const String patientRecords = '/patient-records';
	static const String patientProfile = '/patient-profile';
	static const String patientUpdateINR = '/patient-update-inr';
	static const String patientTakeDosage = '/patient-take-dosage';
	static const String patientHealthReports = '/patient-health-reports';
	static const String doctorDashboard = '/doctor-dashboard';
	static const String doctorAddPatient = '/doctor-add-patient';
}

class AppRouter {
	static const String initialRoute = AppRoutes.login;

	static final Map<String, WidgetBuilder> routes = {
		'/': (_) => const LoginPage(),
		'/patient-home': (_) => const PatientPage(),
		AppRoutes.login: (_) => const LoginPage(),
		AppRoutes.onboarding: (_) => const OnboardingPage(),
		AppRoutes.patient: (_) => const PatientPage(),
		AppRoutes.patientUpdateINR: (_) => const PatientUpdateINRPage(),
		AppRoutes.patientTakeDosage: (_) => const PatientTakeDosagePage(),
		AppRoutes.patientHealthReports: (_) => const PatientHealthReportsPage(),
		AppRoutes.patientRecords: (_) => const PatientRecordsPage(),
		AppRoutes.patientProfile: (_) => const PatientProfilePage(),
		AppRoutes.doctorDashboard: (_) => const DoctorDashboardPage(),
		AppRoutes.doctorAddPatient: (_) => const AddPatientPage(),
	};
}

