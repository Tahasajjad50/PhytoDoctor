import 'visit_repository.dart';

/// Explicitly isolated mock repository used ONLY for UI preview
/// when running without backend server connectivity.
/// Never represented as live data in user interface.
class MockVisitRepository implements VisitRepository {
  @override
  bool get isMock => true;

  @override
  String get repositorySource => 'Local Offline Mock Repository (Not Live Data)';

  @override
  Future<Map<String, dynamic>> getDashboardSummary(String token) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return {
      'target_visits': 0,
      'completed_today': 0,
      'verified_visits': 0,
      'remaining_visits': 0,
      'pending_sync_count': 0,
      'progress_percentage': 0.0,
      'is_live_data': false,
      'data_notice': '[OFFLINE - NO RECORDED DATA]',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getVisitHistory(String token) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return [];
  }

  @override
  Future<bool> recordVisit({
    required String token,
    required Map<String, dynamic> visitData,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  @override
  Future<Map<String, dynamic>> getPerformanceAnalytics({
    required String token,
    required String employeeId,
    String timeframe = 'DAILY',
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return {
      'employee_id': employeeId,
      'employee_name': 'Field Agronomist',
      'timeframe': timeframe,
      'target_visits': 0,
      'submitted_visits': 0,
      'verified_visits': 0,
      'remaining_visits': 0,
      'rejected_visits': 0,
      'pending_sync_count': 0,
      'flagged_visits_count': 0,
      'completion_percentage': 0.0,
      'trend_points': [],
      'recent_reviews': [],
      'is_live_data': false,
    };
  }

  @override
  Future<Map<String, dynamic>> getTeamComparison({
    required String token,
    String timeframe = 'DAILY',
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return {
      'manager_name': 'Operations Team',
      'timeframe': timeframe,
      'team_size': 0,
      'team_total_target': 0,
      'team_total_verified': 0,
      'team_average_completion_pct': 0.0,
      'members': [],
    };
  }
}
