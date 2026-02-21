import 'package:frontend/core/constants/strings.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/doctor/models/doctor_profile_model.dart';
import 'package:frontend/features/doctor/models/patient_detail_model.dart';
import 'package:frontend/features/doctor/models/patient_model.dart';

class DoctorRepository {
  DoctorRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<PatientModel>> getPatients() async {
    final response = await _apiClient.get(AppStrings.doctorPatientsPath);
    final patients = response['patients'];
    if (patients is List) {
      return patients.map((e) => PatientModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<void> addPatient(Map<String, dynamic> payload) async {
    await _apiClient.post(AppStrings.doctorPatientsPath, data: payload);
  }

  Future<DoctorProfileModel> getDoctorProfile() async {
    final response = await _apiClient.get(AppStrings.doctorProfilePath);
    return DoctorProfileModel.fromJson(response);
  }

  Future<PatientDetailModel> getPatientDetail(String opNumber) async {
    final response = await _apiClient.get('${AppStrings.doctorPatientsPath}/$opNumber');
    final patient = response['patient'];
    return PatientDetailModel.fromJson(patient as Map<String, dynamic>);
  }

  Future<void> updatePatientDosage(String opNumber, Map<String, dynamic> prescription) async {
    await _apiClient.put('${AppStrings.doctorPatientsPath}/$opNumber/dosage', data: { 'prescription': prescription });
  }

  Future<void> updateNextReview(String opNumber, String date) async {
    await _apiClient.put('${AppStrings.doctorPatientsPath}/$opNumber/config', data: { 'date': date });
  }

  Future<void> updateInstructions(String opNumber, List<String> instructions) async {
    await _apiClient.put('${AppStrings.doctorPatientsPath}/$opNumber/config', data: { 'instructions': instructions });
  }

  Future<List<dynamic>> getPatientReports(String opNumber) async {
    final response = await _apiClient.get('${AppStrings.doctorPatientsPath}/$opNumber/reports');
    final inrHistory = response['inr_history'];
    return inrHistory is List ? inrHistory : [];
  }

  Future<void> updateReport(String opNumber, String reportId, Map<String, dynamic> data) async {
    await _apiClient.put('${AppStrings.doctorPatientsPath}/$opNumber/reports/$reportId', data: data);
  }

  Future<void> reassignPatient(String opNumber, String newDoctorId) async {
    await _apiClient.patch('${AppStrings.doctorPatientsPath}/$opNumber/reassign', data: { 'new_doctor_id': newDoctorId });
  }

  Future<List<dynamic>> getDoctors() async {
    final response = await _apiClient.get(AppStrings.doctorGetDoctorsPath);
    final doctors = response['doctors'];
    return doctors is List ? doctors : [];
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    await _apiClient.put(AppStrings.doctorProfilePath, data: data);
  }

  Future<Map<String, dynamic>> getReport(String opNumber, String reportId) async {
    final response = await _apiClient.get('${AppStrings.doctorPatientsPath}/$opNumber/reports/$reportId');
    // Response is already unwrapped by ApiClient, check if it has 'report' key
    if (response.containsKey('report')) {
      return response['report'] as Map<String, dynamic>;
    }
    // Otherwise return the entire response
    return response;
  }

  Future<void> updateReportInstructions(
    String opNumber,
    String reportId, {
    required String notes,
    required bool isCritical,
  }) async {
    await _apiClient.put(
      '${AppStrings.doctorPatientsPath}/$opNumber/reports/$reportId',
      data: {
        'notes': notes,
        'is_critical': isCritical,
      },
    );
  }
}
