class PatientModel {
  final String id;
  final String name;
  final int? age;
  final String? gender;
  final String? opNumber;
  final String? condition;
  final String? accountStatus;

  const PatientModel({
    required this.id,
    required this.name,
    this.age,
    this.gender,
    this.opNumber,
    this.condition,
    this.accountStatus,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    final demographics = json['demographics'] as Map<String, dynamic>?;
    final medicalConfig = json['medical_config'] as Map<String, dynamic>?;
    final dynamic ageVal = demographics?['age'];
    final diagnosis = medicalConfig?['diagnosis']?.toString().trim();
    final accountStatus = json['account_status']?.toString().trim();
    return PatientModel(
      id: (json['_id'] ?? '') as String,
      name: (demographics?['name'] ?? 'Unknown') as String,
      age: ageVal is int ? ageVal : null,
      gender: demographics?['gender'] as String?,
      opNumber: json['login_id'] as String?,
      condition:
          diagnosis != null && diagnosis.isNotEmpty ? diagnosis : null,
      accountStatus:
          accountStatus != null && accountStatus.isNotEmpty ? accountStatus : null,
    );
  }
}
