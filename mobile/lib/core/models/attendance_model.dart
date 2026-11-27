DateTime? parsePakistanTime(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return null;
  final hasOffset = s.endsWith('Z') ||
      s.endsWith('z') ||
      RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
  final utcDt = (parsed.isUtc || hasOffset)
      ? parsed.toUtc()
      : DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
  // Convert explicitly to Pakistan Standard Time (UTC+5)
  return utcDt.add(const Duration(hours: 5));
}

class AttendanceStatusModel {
  final bool isActive;
  final DateTime? clockInTime;
  final DateTime? clockOutTime;
  final String date;
  final String message;

  AttendanceStatusModel({
    required this.isActive,
    this.clockInTime,
    this.clockOutTime,
    required this.date,
    required this.message,
  });

  factory AttendanceStatusModel.fromJson(Map<String, dynamic> json) {
    return AttendanceStatusModel(
      isActive: json['is_active'] == true,
      clockInTime: parsePakistanTime(json['clock_in_time']),
      clockOutTime: parsePakistanTime(json['clock_out_time']),
      date: json['date']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}

class EmployeeAttendanceItemModel {
  final String id;
  final String fullName;
  final String username;
  final String? phone;
  final String? designation;
  final bool isActiveNow;
  final DateTime? clockInTime;
  final DateTime? clockOutTime;

  EmployeeAttendanceItemModel({
    required this.id,
    required this.fullName,
    required this.username,
    this.phone,
    this.designation,
    required this.isActiveNow,
    this.clockInTime,
    this.clockOutTime,
  });

  factory EmployeeAttendanceItemModel.fromJson(Map<String, dynamic> json) {
    return EmployeeAttendanceItemModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      phone: json['phone']?.toString(),
      designation: json['designation']?.toString(),
      isActiveNow: json['is_active_now'] == true,
      clockInTime: parsePakistanTime(json['clock_in_time']),
      clockOutTime: parsePakistanTime(json['clock_out_time']),
    );
  }
}

class AdminAttendanceRosterModel {
  final String date;
  final int totalEmployees;
  final int activeCount;
  final int inactiveCount;
  final List<EmployeeAttendanceItemModel> employees;

  AdminAttendanceRosterModel({
    required this.date,
    required this.totalEmployees,
    required this.activeCount,
    required this.inactiveCount,
    required this.employees,
  });

  factory AdminAttendanceRosterModel.fromJson(Map<String, dynamic> json) {
    final list = json['employees'] as List<dynamic>? ?? [];
    return AdminAttendanceRosterModel(
      date: json['date']?.toString() ?? '',
      totalEmployees: (json['total_employees'] as num?)?.toInt() ?? 0,
      activeCount: (json['active_count'] as num?)?.toInt() ?? 0,
      inactiveCount: (json['inactive_count'] as num?)?.toInt() ?? 0,
      employees: list.map((e) => EmployeeAttendanceItemModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
