class AdminStatsModel {
  final DoctorStats doctors;
  final PatientStats patients;
  final int auditLogs;

  AdminStatsModel({
    required this.doctors,
    required this.patients,
    this.auditLogs = 0,
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> json) {
    return AdminStatsModel(
      doctors: DoctorStats.fromJson(
        json['doctors'] as Map<String, dynamic>? ?? {},
      ),
      patients: PatientStats.fromJson(
        json['patients'] as Map<String, dynamic>? ?? {},
      ),
      auditLogs: json['audit_logs'] as int? ?? 0,
    );
  }
}

class DoctorStats {
  final int total;
  final int active;
  final int inactive;
  final int recent;

  DoctorStats({
    this.total = 0,
    this.active = 0,
    this.inactive = 0,
    this.recent = 0,
  });

  factory DoctorStats.fromJson(Map<String, dynamic> json) {
    return DoctorStats(
      total: json['total'] as int? ?? 0,
      active: json['active'] as int? ?? 0,
      inactive: json['inactive'] as int? ?? 0,
      recent: json['recent'] as int? ?? 0,
    );
  }
}

class PatientStats {
  final int total;
  final int active;
  final int inactive;
  final int recent;

  PatientStats({
    this.total = 0,
    this.active = 0,
    this.inactive = 0,
    this.recent = 0,
  });

  factory PatientStats.fromJson(Map<String, dynamic> json) {
    return PatientStats(
      total: json['total'] as int? ?? 0,
      active: json['active'] as int? ?? 0,
      inactive: json['inactive'] as int? ?? 0,
      recent: json['recent'] as int? ?? 0,
    );
  }
}

class TrendDataPoint {
  final String date;
  final int count;

  TrendDataPoint({required this.date, required this.count});

  factory TrendDataPoint.fromJson(Map<String, dynamic> json) {
    return TrendDataPoint(
      date: json['date'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

class RegistrationTrends {
  final String period;
  final List<TrendDataPoint> doctors;
  final List<TrendDataPoint> patients;

  RegistrationTrends({
    required this.period,
    required this.doctors,
    required this.patients,
  });

  factory RegistrationTrends.fromJson(Map<String, dynamic> json) {
    return RegistrationTrends(
      period: json['period'] as String? ?? '30d',
      doctors: (json['doctors'] as List? ?? [])
          .map((e) => TrendDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      patients: (json['patients'] as List? ?? [])
          .map((e) => TrendDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class InrComplianceStats {
  final int totalPatients;
  final int inRange;
  final int belowRange;
  final int aboveRange;
  final int noData;

  InrComplianceStats({
    this.totalPatients = 0,
    this.inRange = 0,
    this.belowRange = 0,
    this.aboveRange = 0,
    this.noData = 0,
  });

  factory InrComplianceStats.fromJson(Map<String, dynamic> json) {
    return InrComplianceStats(
      totalPatients: json['total_patients'] as int? ?? 0,
      inRange: json['in_range'] as int? ?? 0,
      belowRange: json['below_range'] as int? ?? 0,
      aboveRange: json['above_range'] as int? ?? 0,
      noData: json['no_data'] as int? ?? 0,
    );
  }
}

class DoctorWorkload {
  final String? doctorId;
  final String? doctorName;
  final String? department;
  final int patientCount;

  DoctorWorkload({
    this.doctorId,
    this.doctorName,
    this.department,
    this.patientCount = 0,
  });

  factory DoctorWorkload.fromJson(Map<String, dynamic> json) {
    return DoctorWorkload(
      doctorId: json['doctor_id'] as String?,
      doctorName: json['doctor_name'] as String?,
      department: json['department'] as String?,
      patientCount: json['patient_count'] as int? ?? 0,
    );
  }
}

class SystemHealthModel {
  final String status;
  final double uptime;
  final DatabaseHealth database;
  final MemoryUsage memory;
  final String timestamp;

  SystemHealthModel({
    required this.status,
    required this.uptime,
    required this.database,
    required this.memory,
    required this.timestamp,
  });

  factory SystemHealthModel.fromJson(Map<String, dynamic> json) {
    return SystemHealthModel(
      status: json['status'] as String? ?? 'unknown',
      uptime: (json['uptime'] as num?)?.toDouble() ?? 0,
      database: DatabaseHealth.fromJson(
        json['database'] as Map<String, dynamic>? ?? {},
      ),
      memory: MemoryUsage.fromJson(
        json['memory'] as Map<String, dynamic>? ?? {},
      ),
      timestamp: json['timestamp'] as String? ?? '',
    );
  }
}

class DatabaseHealth {
  final String state;
  final String? host;
  final String? name;

  DatabaseHealth({required this.state, this.host, this.name});

  factory DatabaseHealth.fromJson(Map<String, dynamic> json) {
    return DatabaseHealth(
      state: json['state'] as String? ?? 'unknown',
      host: json['host'] as String?,
      name: json['name'] as String?,
    );
  }
}

class MemoryUsage {
  final String rss;
  final String heapTotal;
  final String heapUsed;

  MemoryUsage({
    required this.rss,
    required this.heapTotal,
    required this.heapUsed,
  });

  factory MemoryUsage.fromJson(Map<String, dynamic> json) {
    return MemoryUsage(
      rss: json['rss'] as String? ?? '0 MB',
      heapTotal: json['heapTotal'] as String? ?? '0 MB',
      heapUsed: json['heapUsed'] as String? ?? '0 MB',
    );
  }
}
