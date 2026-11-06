import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/services/auth_service.dart';
import 'visit_repository.dart';

class RealVisitRepository implements VisitRepository {
  final String? _customBaseUrl;
  final http.Client client;

  RealVisitRepository({
    String? baseUrl,
    http.Client? client,
  })  : _customBaseUrl = baseUrl,
        client = client ?? http.Client();

  String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    if (AuthService.defaultBaseUrl.isNotEmpty) {
      return AuthService.defaultBaseUrl;
    }
    return AppConfig.apiBaseUrl;
  }

  @override
  bool get isMock => false;

  @override
  String get repositorySource => 'Live FastAPI Backend';

  @override
  Future<Map<String, dynamic>> getDashboardSummary(String token) async {
    final url = Uri.parse('$baseUrl/api/v1/employee/dashboard-summary');
    final response = await client.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final target = data['daily_target_visits'] ?? data['target_visits'] ?? 6;
      final completed = data['completed_today'] ?? 0;
      final verified = data['verified_visits'] ?? 0;
      final remaining = (target is int && verified is int)
          ? (target - verified).clamp(0, 99)
          : (data['remaining_visits'] ?? 0);
      final rawTodayVisits = data['today_visits'];
      List<Map<String, dynamic>> todayVisits = [];
      if (rawTodayVisits is List) {
        todayVisits = rawTodayVisits.map((e) => e as Map<String, dynamic>).toList();
      }

      return {
        'target_visits': target,
        'completed_today': completed,
        'verified_visits': verified,
        'pending_visits': data['pending_visits'] ?? 0,
        'rejected_visits': data['rejected_visits'] ?? 0,
        'remaining_visits': remaining,
        'pending_sync_count': data['pending_sync'] ?? 0,
        'progress_percentage': (data['target_progress_percentage'] as num?)?.toDouble() ?? 0.0,
        'designation': data['designation'] as String?,
        'supervisor_name': data['supervisor_name'] as String?,
        'today_visits': todayVisits,
        'is_live_data': true,
      };
    } else {
      throw Exception('Server returned ${response.statusCode}: ${response.body}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getVisitHistory(String token) async {
    // Queries visits API
    final url = Uri.parse('$baseUrl/api/v1/visits');
    try {
      final response = await client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map((e) => e as Map<String, dynamic>).toList();
        } else if (decoded is Map<String, dynamic> && decoded['items'] is List) {
          return (decoded['items'] as List).map((e) => e as Map<String, dynamic>).toList();
        }
        return [];
      }
    } catch (_) {
      // If endpoint is unreachable or offline, rethrow to trigger proper offline fallback
      rethrow;
    }
    return [];
  }

  @override
  Future<bool> recordVisit({
    required String token,
    required Map<String, dynamic> visitData,
  }) async {
    final url = Uri.parse('$baseUrl/api/v1/visits');
    final response = await client.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(visitData),
    ).timeout(const Duration(seconds: 3));
    return response.statusCode == 200 || response.statusCode == 201;
  }

  @override
  Future<Map<String, dynamic>> getPerformanceAnalytics({
    required String token,
    required String employeeId,
    String timeframe = 'DAILY',
  }) async {
    final url = Uri.parse('$baseUrl/api/v1/performance/employee/$employeeId/analytics?timeframe=$timeframe');
    final response = await client.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Server returned ${response.statusCode}: ${response.body}');
    }
  }

  @override
  Future<Map<String, dynamic>> getTeamComparison({
    required String token,
    String timeframe = 'DAILY',
  }) async {
    final url = Uri.parse('$baseUrl/api/v1/performance/team-comparison?timeframe=$timeframe');
    final response = await client.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Server returned ${response.statusCode}: ${response.body}');
    }
  }
}
