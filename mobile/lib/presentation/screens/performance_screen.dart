import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/mock_visit_repository.dart';
import '../../data/repositories/real_visit_repository.dart';
import '../../data/repositories/visit_repository.dart';
import '../widgets/state_views.dart';

class PerformanceScreen extends StatefulWidget {
  final UserModel user;
  final VisitRepository? repository;

  const PerformanceScreen({
    Key? key,
    required this.user,
    this.repository,
  }) : super(key: key);

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  late final VisitRepository _repository;
  String _timeframe = 'DAILY'; // 'DAILY', 'WEEKLY', 'MONTHLY'
  bool _showTeamView = false; // Toggle for Manager / Owner

  bool _isLoading = true;
  String? _errorMessage;

  // Analytics State
  int _targetVisits = 6;
  int _submittedVisits = 0;
  int _verifiedVisits = 0;
  int _remainingVisits = 6;
  int _rejectedVisits = 0;
  int _pendingSyncCount = 0;
  int _flaggedVisitsCount = 0;
  double _completionPercentage = 0.0;
  List<Map<String, dynamic>> _trendPoints = [];
  List<Map<String, dynamic>> _recentReviews = [];

  // Team Comparison State
  List<Map<String, dynamic>> _teamMembers = [];
  int _teamTotalTarget = 0;
  int _teamTotalVerified = 0;
  double _teamAveragePct = 0.0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? RealVisitRepository();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = widget.user.accessToken ?? '';

      if (_showTeamView && (widget.user.isManager || widget.user.isOwner)) {
        // Fetch team comparison
        final teamData = await _repository.getTeamComparison(
          token: token,
          timeframe: _timeframe,
        );

        if (!mounted) return;
        setState(() {
          _teamMembers = (teamData['members'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
          _teamTotalTarget = teamData['team_total_target'] ?? 0;
          _teamTotalVerified = teamData['team_total_verified'] ?? 0;
          _teamAveragePct = (teamData['team_average_completion_pct'] as num?)?.toDouble() ?? 0.0;
          _isLoading = false;
        });
      } else {
        // Fetch personal employee analytics
        final data = await _repository.getPerformanceAnalytics(
          token: token,
          employeeId: widget.user.id,
          timeframe: _timeframe,
        );

        if (!mounted) return;
        setState(() {
          _targetVisits = data['target_visits'] ?? 6;
          _submittedVisits = data['submitted_visits'] ?? 0;
          _verifiedVisits = data['verified_visits'] ?? 0;
          _remainingVisits = data['remaining_visits'] ?? (_targetVisits - _verifiedVisits).clamp(0, 999);
          _rejectedVisits = data['rejected_visits'] ?? 0;
          _pendingSyncCount = data['pending_sync_count'] ?? 0;
          _flaggedVisitsCount = data['flagged_visits_count'] ?? 0;
          _completionPercentage = (data['completion_percentage'] as num?)?.toDouble() ?? 0.0;
          _trendPoints = (data['trend_points'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
          _recentReviews = (data['recent_reviews'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
          _isLoading = false;
        });
      }
    } catch (_) {
      // Fallback to MockVisitRepository if network is offline
      try {
        final mockRepo = MockVisitRepository();
        final mockData = await mockRepo.getPerformanceAnalytics(
          token: '',
          employeeId: widget.user.id,
          timeframe: _timeframe,
        );

        if (!mounted) return;
        setState(() {
          _targetVisits = mockData['target_visits'];
          _submittedVisits = mockData['submitted_visits'];
          _verifiedVisits = mockData['verified_visits'];
          _remainingVisits = mockData['remaining_visits'];
          _rejectedVisits = mockData['rejected_visits'];
          _pendingSyncCount = mockData['pending_sync_count'];
          _flaggedVisitsCount = mockData['flagged_visits_count'];
          _completionPercentage = (mockData['completion_percentage'] as num).toDouble();
          _trendPoints = (mockData['trend_points'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _recentReviews = (mockData['recent_reviews'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _isLoading = false;
        });
      } catch (err) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Could not load performance metrics. Please pull down to retry.';
          _isLoading = false;
        });
      }
    }
  }

  void _onTimeframeChanged(String tf) {
    if (_timeframe == tf) return;
    setState(() => _timeframe = tf);
    _loadAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    final canViewTeam = widget.user.isManager || widget.user.isOwner;
    final progress = (_targetVisits > 0 ? (_verifiedVisits / _targetVisits) : 0.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: const Text('Performance & Target Analytics'),
        actions: [
          if (canViewTeam)
            IconButton(
              icon: Icon(_showTeamView ? Icons.person : Icons.groups_outlined),
              tooltip: _showTeamView ? 'View My Metrics' : 'View Team Comparison',
              onPressed: () {
                setState(() => _showTeamView = !_showTeamView);
                _loadAnalytics();
              },
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAnalytics,
          color: AppTheme.botanicalPrimary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Timeframe Tabs: Daily, Weekly, Monthly
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                    border: Border.all(color: AppTheme.sageBorder),
                  ),
                  child: Row(
                    children: [
                      _PeriodTab(
                        title: 'Daily',
                        isSelected: _timeframe == 'DAILY',
                        onTap: () => _onTimeframeChanged('DAILY'),
                      ),
                      _PeriodTab(
                        title: 'Weekly',
                        isSelected: _timeframe == 'WEEKLY',
                        onTap: () => _onTimeframeChanged('WEEKLY'),
                      ),
                      _PeriodTab(
                        title: 'Monthly',
                        isSelected: _timeframe == 'MONTHLY',
                        onTap: () => _onTimeframeChanged('MONTHLY'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                if (_isLoading)
                  const SizedBox(height: 250, child: LoadingView(message: 'Aggregating verified metrics...'))
                else if (_errorMessage != null)
                  ErrorStateView(message: _errorMessage!, onRetry: _loadAnalytics)
                else if (_showTeamView)
                  _buildTeamComparisonView()
                else
                  _buildPersonalPerformanceView(progress),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Personal Agronomist Performance & Quality Charts View
  Widget _buildPersonalPerformanceView(double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Target Quota Progress Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
            border: Border.all(color: AppTheme.sageBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_timeframe Quota Completion',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain,
                    ),
                  ),
                  Text(
                    '${_completionPercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _completionPercentage >= 100.0 ? AppTheme.cropGreen : AppTheme.botanicalPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: AppTheme.sageLight,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _completionPercentage >= 100.0 ? AppTheme.cropGreen : AppTheme.botanicalPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_verifiedVisits of $_targetVisits Visits Verified',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain,
                    ),
                  ),
                  Text(
                    '$_remainingVisits Remaining',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.earthAmber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Business Rule: Only supervisor-verified on-site visits count toward quota completion.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 4 Key Performance Indicators (KPIs)
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'Submitted Visits',
                value: '$_submittedVisits',
                subtitle: 'Total Logged in Period',
                color: AppTheme.botanicalPrimary,
                icon: Icons.upload_file,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                title: 'Verified Visits',
                value: '$_verifiedVisits',
                subtitle: 'Eligible for Quota',
                color: AppTheme.cropGreen,
                icon: Icons.verified,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'Rejected / Audit',
                value: '$_rejectedVisits',
                subtitle: 'Excluded from Totals',
                color: _rejectedVisits > 0 ? AppTheme.alertCrimson : AppTheme.textMuted,
                icon: Icons.cancel_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                title: 'Pending Sync/Review',
                value: '$_pendingSyncCount',
                subtitle: 'In Verification Queue',
                color: AppTheme.earthAmber,
                icon: Icons.hourglass_top,
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Trend Breakdown Chart
        if (_trendPoints.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
              border: Border.all(color: AppTheme.sageBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Performance Breakdown by Date',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                    ),
                    Text(
                      'Verified / Target',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Column(
                  children: _trendPoints.map((point) {
                    final dateStr = (point['date'] as String?) ?? '';
                    final dayLabel = dateStr.length >= 10 ? dateStr.substring(5) : dateStr;
                    final target = point['target_count'] ?? 6;
                    final verified = point['verified_count'] ?? 0;
                    final pct = (point['completion_percentage'] as num?)?.toDouble() ?? 0.0;
                    final ratio = target > 0 ? (verified / target).clamp(0.0, 1.0) : 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 50,
                            child: Text(
                              dayLabel,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 8,
                                backgroundColor: AppTheme.sageLight,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  pct >= 100 ? AppTheme.cropGreen : AppTheme.botanicalPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 65,
                            child: Text(
                              '$verified / $target ($pct%)',
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // Supervisor Review History / Feedback
        if (_recentReviews.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
              border: Border.all(color: AppTheme.sageBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Audit Feedback & Review Reasons',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                ),
                const SizedBox(height: 10),
                Column(
                  children: _recentReviews.map((rev) {
                    final status = rev['status'] as String? ?? 'PENDING';
                    final isRejected = status == 'REJECTED';
                    final clientName = rev['client_name'] as String? ?? 'Field Visit';
                    final reason = rev['review_reason'] as String? ?? 'No specific feedback provided.';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isRejected ? const Color(0xFFFFEBEE) : AppTheme.sageLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isRejected ? AppTheme.alertCrimson.withOpacity(0.4) : AppTheme.sageBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                clientName,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isRejected ? AppTheme.alertCrimson : AppTheme.cropGreen,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status,
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reason,
                            style: TextStyle(
                              fontSize: 11,
                              color: isRejected ? AppTheme.alertCrimson : AppTheme.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  /// Team Comparison View for Managers & Owners
  Widget _buildTeamComparisonView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Team Overall Summary Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
            border: Border.all(color: AppTheme.sageBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Team Quota Completion',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                  ),
                  Text(
                    '${_teamAveragePct.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.botanicalPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$_teamTotalVerified of $_teamTotalTarget Verified Visits Across ${_teamMembers.length} Agronomists',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Agronomist Leaderboard Ranking
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
            border: Border.all(color: AppTheme.sageBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Agronomist Performance Ranking',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain),
              ),
              const SizedBox(height: 12),
              Column(
                children: _teamMembers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final member = entry.value;
                  final name = member['employee_name'] as String? ?? 'Agronomist';
                  final target = member['target_visits'] ?? 6;
                  final verified = member['verified_visits'] ?? 0;
                  final pct = (member['completion_percentage'] as num?)?.toDouble() ?? 0.0;
                  final flagged = member['flagged_visits'] ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: index == 0 ? AppTheme.sageLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.sageBorder),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: index == 0 ? AppTheme.botanicalPrimary : AppTheme.sageLight,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: index == 0 ? Colors.white : AppTheme.textMain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                              ),
                              Text(
                                '$verified of $target verified ($pct%) ${flagged > 0 ? "• $flagged flagged" : ""}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: pct >= 100 ? AppTheme.cropGreenLight : AppTheme.earthAmberLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: pct >= 100 ? AppTheme.cropGreen : AppTheme.earthAmber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodTab({
    Key? key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.botanicalPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _KpiCard({
    Key? key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
        border: Border.all(color: AppTheme.sageBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMain),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
