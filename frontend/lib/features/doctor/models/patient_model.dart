class PatientModel {
  final String id;
  final String name;
  final int? age;
  final String? gender;
  final String? opNumber;
  final String? condition;
  final Map<String, dynamic> attention;

  const PatientModel({
    required this.id,
    required this.name,
    this.age,
    this.gender,
    this.opNumber,
    this.condition,
    this.attention = const {},
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    final demographics = json['demographics'] as Map<String, dynamic>?;
    final dynamic ageVal = demographics?['age'];
    final attention = Map<String, dynamic>.from(
      json['attention'] as Map? ?? {},
    );
    final condition = attention['outside_target'] == true
        ? 'Outside patient target'
        : attention['outside_target'] == false
        ? 'Within patient target'
        : 'Target comparison unavailable';
    return PatientModel(
      id: (json['_id'] ?? '') as String,
      name: (demographics?['name'] ?? 'Unknown') as String,
      age: ageVal is int ? ageVal : null,
      gender: demographics?['gender'] as String?,
      opNumber: json['login_id'] as String?,
      condition: condition,
      attention: attention,
    );
  }

  List<String> get attentionReasons =>
      (attention['reasons'] as List? ?? []).map((e) => e.toString()).toList();

  static const reasonLabels = {
    'reports_pending': 'Reports awaiting review',
    'review_overdue': 'Review overdue',
    'review_today': 'Review due today',
    'inr_monitoring_gap': 'INR monitoring gap',
    'dose_recording_gap': 'Dose recording gaps',
    'no_inr': 'No INR recorded',
    'review_unknown': 'Review status unknown',
  };
}
