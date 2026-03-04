import 'package:frontend/core/di/app_dependencies.dart';

class DoctorQueryKeys {
  DoctorQueryKeys._();

  static List<Object> all() => ['doctor', _scope];

  static List<Object> patients() => [...all(), 'patients'];
  static List<Object> profile() => [...all(), 'profile'];
  static List<Object> patientDetail(String opNumber) =>
      [...all(), 'patient', opNumber];
  static List<Object> patientReports(String opNumber) =>
      [...all(), 'patient', opNumber, 'reports'];

  static String get _scope => AppDependencies.secureStorage.sessionScope;
}
