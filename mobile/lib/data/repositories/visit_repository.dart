abstract class VisitRepository {
  bool get isMock;
  String get repositorySource;

  Future<Map<String, dynamic>> getDashboardSummary(String token);
  Future<List<Map<String, dynamic>>> getVisitHistory(String token);
  Future<bool> recordVisit({
    required String token,
    required Map<String, dynamic> visitData,
  });

  /// Fetches rich performance analytics for daily, weekly, or monthly timeframes
  Future<Map<String, dynamic>> getPerformanceAnalytics({
    required String token,
    required String employeeId,
    String timeframe = 'DAILY',
  });

  /// Fetches team comparison data for authorized managers and owners
  Future<Map<String, dynamic>> getTeamComparison({
    required String token,
    String timeframe = 'DAILY',
  });
}
