import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/attendance_model.dart';
import 'auth_service.dart';

class AttendanceService {
  final http.Client _client;
  final String _baseUrl;

  AttendanceService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AuthService.defaultBaseUrl;

  /// Mark employee as active (Clock In)
  Future<AttendanceStatusModel> clockIn(String token) async {
    final url = Uri.parse('$_baseUrl/api/v1/attendance/clock-in');
    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode == 200) {
      return AttendanceStatusModel.fromJson(jsonDecode(response.body));
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Failed to clock in');
    }
  }

  /// Mark employee as inactive (Clock Out)
  Future<AttendanceStatusModel> clockOut(String token) async {
    final url = Uri.parse('$_baseUrl/api/v1/attendance/clock-out');
    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode == 200) {
      return AttendanceStatusModel.fromJson(jsonDecode(response.body));
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Failed to clock out');
    }
  }

  /// Fetch current employee's attendance status today
  Future<AttendanceStatusModel> getStatus(String token) async {
    final url = Uri.parse('$_baseUrl/api/v1/attendance/status');
    final response = await _client.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode == 200) {
      return AttendanceStatusModel.fromJson(jsonDecode(response.body));
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Failed to fetch attendance status');
    }
  }

  /// Fetch full roster of employees with live active status & in/out times for Admin
  Future<AdminAttendanceRosterModel> getAdminRoster(String token) async {
    final url = Uri.parse('$_baseUrl/api/v1/attendance/admin/roster');
    final response = await _client.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode == 200) {
      return AdminAttendanceRosterModel.fromJson(jsonDecode(response.body));
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Failed to fetch attendance roster');
    }
  }
}
