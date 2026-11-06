import 'package:flutter/material.dart';
import '../../core/models/attendance_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/attendance_service.dart';
import '../../core/services/native_platform_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/mock_visit_repository.dart';
import '../../data/repositories/real_visit_repository.dart';
import '../../data/repositories/visit_repository.dart';
import '../widgets/custom_button.dart';
import '../widgets/phyto_logo.dart';
import '../widgets/state_views.dart';
import '../../core/sync/offline_sync_manager.dart';
import '../../core/storage/sqlite_visit_database.dart';
import '../../core/models/visit_state.dart';
import 'chat_list_screen.dart';
import 'performance_screen.dart';
import 'profile_settings_screen.dart';
import 'record_visit_screen.dart';
import 'visit_history_screen.dart';
import 'employee_target_detail_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  final UserModel user;
  final VisitRepository? repository;

  const EmployeeDashboardScreen({
    Key? key,
    required this.user,
    this.repository,
  }) : super(key: key);

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  late final VisitRepository _repository;
  final OfflineSyncManager _syncManager = OfflineSyncManager();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isOffline = false;

  int _todayTarget = 6;
  int _completedToday = 0;
  int _verifiedVisits = 0;
  int _remainingVisits = 6;
  int _pendingSyncCount = 0;
  double _progressPercentage = 0.0;
  bool _isLiveData = false;
  String? _designation;
  String? _supervisorName;
  List<Map<String, dynamic>> _todayVisits = [];

  // Employee Daily Attendance State
  final AttendanceService _attendanceService = AttendanceService();
  bool _isAttendanceActive = false;
  DateTime? _clockInTime;
  DateTime? _clockOutTime;
  bool _isTogglingAttendance = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? RealVisitRepository();
    _pendingSyncCount = _syncManager.pendingCount;
    _syncManager.addListener(_onSyncManagerUpdated);
    _syncManager.initialize();
    // Auto-prompt runtime permissions (Camera & GPS Location) and check mandatory updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NativePlatformService.requestPermissions();
      AppUpdateService.checkAndPromptUpdate(context);
    });
    // Non-blocking background fetch
    _loadDashboardData();
    _loadAttendanceStatus();
  }

  Future<void> _loadAttendanceStatus() async {
    final token = widget.user.accessToken;
    if (token == null || token.isEmpty) return;
    try {
      final status = await _attendanceService.getStatus(token);
      if (mounted) {
        setState(() {
          _isAttendanceActive = status.isActive;
          _clockInTime = status.clockInTime;
          _clockOutTime = status.clockOutTime;
        });
      }
    } catch (_) {
      // Offline fallback: keep default
    }
  }

  Future<void> _toggleAttendance() async {
    final token = widget.user.accessToken;
    if (token == null || token.isEmpty) return;

    setState(() => _isTogglingAttendance = true);
    try {
      AttendanceStatusModel res;
      if (_isAttendanceActive) {
        res = await _attendanceService.clockOut(token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marked as Inactive (Clocked Out)'),
              backgroundColor: AppTheme.adminSlate,
            ),
          );
        }
      } else {
        res = await _attendanceService.clockIn(token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marked as Active (Clocked In). Active status broadcasted to Admin.'),
              backgroundColor: AppTheme.cropGreen,
            ),
          );
        }
      }
      if (mounted) {
        setState(() {
          _isAttendanceActive = res.isActive;
          _clockInTime = res.clockInTime;
          _clockOutTime = res.clockOutTime;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance error: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppTheme.alertCrimson,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTogglingAttendance = false);
      }
    }
  }

  @override
  void dispose() {
    _syncManager.removeListener(_onSyncManagerUpdated);
    super.dispose();
  }

  void _onSyncManagerUpdated() {
    if (mounted) {
      setState(() {
        _pendingSyncCount = _syncManager.pendingCount;
      });
    }
  }

  Future<void> _triggerManualSync() async {
    final token = widget.user.accessToken ?? '';
    final synced = await _syncManager.syncNow(
      repository: _repository,
      token: token,
      forceRetryAll: true,
    );
    if (!mounted) return;
    if (synced > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully synchronized $synced field visit(s)!'),
          backgroundColor: AppTheme.cropGreen,
        ),
      );
      _loadDashboardData();
    } else if (_syncManager.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_syncManager.lastError!),
          backgroundColor: AppTheme.alertCrimson,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _loadDashboardData() async {
    // Non-blocking: background sync
    try {
      final token = widget.user.accessToken ?? '';
      final data = await _repository.getDashboardSummary(token);

      if (!mounted) return;
      setState(() {
        _todayTarget = data['target_visits'] ?? data['daily_target_visits'] ?? 6;
        _completedToday = data['completed_today'] ?? 0;
        _verifiedVisits = data['verified_visits'] ?? 0;
        _remainingVisits = data['remaining_visits'] ?? (_todayTarget - _verifiedVisits).clamp(0, 99);
        final rawVisits = data['today_visits'];
        if (rawVisits is List) {
          _todayVisits = rawVisits.map((e) => e as Map<String, dynamic>).toList();
        }
        _pendingSyncCount = data['pending_sync_count'] ?? _syncManager.pendingCount;
        _progressPercentage = (data['target_progress_percentage'] as num?)?.toDouble() ?? 
            (_todayTarget > 0 ? (_verifiedVisits / _todayTarget * 100) : 0.0);
        _designation = data['designation'] as String?;
        _supervisorName = data['supervisor_name'] as String?;
        _isLiveData = data['is_live_data'] ?? true;
        _isLoading = false;
        _isOffline = false;
        _errorMessage = null;
      });
    } catch (e) {
      // Instant graceful offline fallback: keep cached metrics & update sync count from SQLite
      if (!mounted) return;
      setState(() {
        _pendingSyncCount = _syncManager.pendingCount;
        _isLiveData = false;
        _isOffline = true;
        _isLoading = false;
      });
    }
  }

  void _navigateToTargetDetail() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeTargetDetailScreen(
          user: widget.user,
          repository: _repository,
          initialTarget: _todayTarget,
          initialCompleted: _completedToday,
          initialVerified: _verifiedVisits,
          initialRemaining: _remainingVisits,
          initialTodayVisits: _todayVisits,
        ),
      ),
    );
    _loadDashboardData();
  }

  void _navigateToRecordVisit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecordVisitScreen(user: widget.user),
      ),
    );

    if (result == true) {
      _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    double progressRatio = (_todayTarget > 0 ? (_verifiedVisits / _todayTarget) : 0.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: Row(
          children: const [
            PhytoDoctorLogo(compactIconOnly: true, width: 28, height: 28),
            SizedBox(width: 10),
            Text('Field Agronomist Hub'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Chatrooms & Announcements',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatListScreen(currentUser: widget.user),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Metrics',
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile & Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileSettingsScreen(user: widget.user),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Offline Notice if server unreachable
            if (_isOffline)
              OfflineBanner(
                pendingCount: _pendingSyncCount,
                onSyncTap: _loadDashboardData,
              ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadDashboardData,
                color: AppTheme.botanicalPrimary,
                child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(18.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Officer Header Banner
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
                                      Text(
                                        widget.user.fullName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim().isNotEmpty
                                            ? widget.user.fullName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim()
                                            : widget.user.username,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textMain,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.sageLight,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              (_designation != null && _designation!.isNotEmpty)
                                                  ? _designation!
                                                  : (widget.user.designation?.isNotEmpty == true
                                                      ? widget.user.designation!
                                                      : 'Field Agronomist'),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.botanicalPrimary,
                                              ),
                                            ),
                                          ),
                                          if (_supervisorName != null && _supervisorName!.isNotEmpty)
                                            Text(
                                              'Reporting to: $_supervisorName',
                                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // Field Agronomist Attendance & Portal Active Status
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _isAttendanceActive ? AppTheme.cropGreenLight.withOpacity(0.4) : AppTheme.surfaceCard,
                                    borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                                    border: Border.all(
                                      color: _isAttendanceActive ? AppTheme.cropGreen : AppTheme.sageBorder,
                                      width: _isAttendanceActive ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: _isAttendanceActive ? AppTheme.cropGreen : AppTheme.textMuted,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _isAttendanceActive ? 'PORTAL STATUS: ACTIVE ON DUTY' : 'PORTAL STATUS: OFF DUTY',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: _isAttendanceActive ? AppTheme.cropGreen : AppTheme.textMuted,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.sageLight,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'FIELD ONLY',
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.botanicalPrimary),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Mark In Time', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _clockInTime != null
                                                      ? '${_clockInTime!.hour.toString().padLeft(2, '0')}:${_clockInTime!.minute.toString().padLeft(2, '0')} ${_clockInTime!.hour >= 12 ? 'PM' : 'AM'}'
                                                      : '--:--',
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Mark Out Time', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _clockOutTime != null
                                                      ? '${_clockOutTime!.hour.toString().padLeft(2, '0')}:${_clockOutTime!.minute.toString().padLeft(2, '0')} ${_clockOutTime!.hour >= 12 ? 'PM' : 'AM'}'
                                                      : (_isAttendanceActive ? 'On Duty' : '--:--'),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: _isAttendanceActive ? AppTheme.cropGreen : AppTheme.textMain,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        onPressed: _isTogglingAttendance ? null : _toggleAttendance,
                                        icon: _isTogglingAttendance
                                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : Icon(_isAttendanceActive ? Icons.logout : Icons.how_to_reg, size: 18),
                                        label: Text(_isAttendanceActive ? 'Mark as Inactive (Clock Out)' : 'Mark as Active (Clock In)'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _isAttendanceActive ? AppTheme.adminSlate : AppTheme.botanicalPrimary,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(double.infinity, 44),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // PRIMARY ACTION: Upload Details
                                CustomButton(
                                  text: 'Upload Details',
                                  icon: Icons.camera_alt,
                                  height: 54,
                                  onPressed: _navigateToRecordVisit,
                                ),

                                const SizedBox(height: 16),

                                // Reliable Offline Synchronization Panel
                                _OfflineSyncPanel(
                                  syncManager: _syncManager,
                                  onSyncNowTap: _triggerManualSync,
                                ),

                                const SizedBox(height: 18),

                                // Today's Quota Breakdown Card (Clickable to open Target & Admin Updates breakdown)
                                InkWell(
                                  onTap: _navigateToTargetDetail,
                                  borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                                  child: Container(
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
                                            Row(
                                              children: const [
                                                Text(
                                                  "Today's Visit Target Progress",
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.textMain,
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                Icon(Icons.chevron_right, size: 18, color: AppTheme.botanicalPrimary),
                                              ],
                                            ),
                                            Text(
                                              '$_verifiedVisits / $_todayTarget Visits',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.botanicalPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: progressRatio,
                                            minHeight: 10,
                                            backgroundColor: AppTheme.sageLight,
                                            valueColor:
                                                const AlwaysStoppedAnimation<Color>(AppTheme.botanicalPrimary),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${(progressRatio * 100).toStringAsFixed(0)}% Target Achieved',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textMuted,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '$_remainingVisits Visits Remaining',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.earthAmber,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // 4 Required Metric Tiles: Today's Target, Verified Visits, Remaining Visits, Pending Sync
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DashboardMetricCard(
                                        title: "Today's Target",
                                        value: '$_todayTarget Visits',
                                        subtitle: 'Daily Assigned Quota',
                                        accentColor: AppTheme.botanicalPrimary,
                                        icon: Icons.flag_outlined,
                                        onTap: _navigateToTargetDetail,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _DashboardMetricCard(
                                        title: 'Verified Visits',
                                        value: '$_verifiedVisits Visits',
                                        subtitle: 'Confirmed On-Site',
                                        accentColor: AppTheme.cropGreen,
                                        icon: Icons.verified,
                                        onTap: _navigateToTargetDetail,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _DashboardMetricCard(
                                        title: 'Remaining Visits',
                                        value: '$_remainingVisits Visits',
                                        subtitle: 'To Complete Daily Quota',
                                        accentColor: AppTheme.earthAmber,
                                        icon: Icons.hourglass_top,
                                        onTap: _navigateToTargetDetail,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _DashboardMetricCard(
                                        title: 'Pending Sync',
                                        value: '$_pendingSyncCount Drafts',
                                        subtitle: _pendingSyncCount == 0 ? 'Queue Up to Date' : 'In SQLite Cache',
                                        accentColor: _pendingSyncCount == 0 ? AppTheme.cropGreen : AppTheme.alertCrimson,
                                        icon: Icons.sync,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // Secondary Navigation Grid
                                Row(
                                  children: [
                                    Expanded(
                                      child: _HubTile(
                                        icon: Icons.history,
                                        title: 'Visit History',
                                        subtitle: 'Inspection log',
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => VisitHistoryScreen(user: widget.user),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _HubTile(
                                        icon: Icons.trending_up,
                                        title: 'Performance',
                                        subtitle: 'Weekly & monthly',
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PerformanceScreen(user: widget.user),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;
  final IconData icon;
  final VoidCallback? onTap;

  const _DashboardMetricCard({
    Key? key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
    required this.icon,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, color: accentColor, size: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onTap != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.textMuted.withOpacity(0.6)),
                    ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
        child: cardContent,
      );
    }
    return cardContent;
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubTile({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
          border: Border.all(color: AppTheme.sageBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.botanicalPrimary, size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMain),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _OfflineSyncPanel extends StatelessWidget {
  final OfflineSyncManager syncManager;
  final VoidCallback onSyncNowTap;

  const _OfflineSyncPanel({
    Key? key,
    required this.syncManager,
    required this.onSyncNowTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pending = syncManager.pendingCount;
    final isSyncing = syncManager.isSyncing;
    final progress = syncManager.syncProgress;
    final stepMsg = syncManager.currentStepMessage;
    final lastError = syncManager.lastError;
    final isLowStorage = syncManager.isLowStorage;
    final lastSyncTime = syncManager.lastSyncTime;

    String lastSyncStr = 'Not synced yet';
    if (lastSyncTime != null) {
      final hour = lastSyncTime.hour.toString().padLeft(2, '0');
      final minute = lastSyncTime.minute.toString().padLeft(2, '0');
      lastSyncStr = 'Today at $hour:$minute';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
        border: Border.all(
          color: lastError != null
              ? AppTheme.alertCrimson.withOpacity(0.5)
              : (pending > 0 ? AppTheme.earthAmber : AppTheme.sageBorder),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    pending > 0 ? Icons.cloud_queue : Icons.cloud_done,
                    color: pending > 0 ? AppTheme.earthAmber : AppTheme.cropGreen,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pending > 0
                        ? '$pending Visit(s) Queued in SQLite'
                        : 'Offline Cache Up to Date',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: pending > 0 ? AppTheme.textMain : AppTheme.cropGreen,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: isSyncing ? null : onSyncNowTap,
                icon: isSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync, size: 16),
                label: Text(isSyncing ? 'Syncing...' : 'Sync Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.botanicalPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(100, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Last Sync: $lastSyncStr',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(width: 8),
              const Text('•', style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(width: 8),
              const Text(
                'Auto-retries with backoff',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
          if (isSyncing) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              backgroundColor: AppTheme.sageLight,
              color: AppTheme.botanicalPrimary,
              minHeight: 4,
            ),
            const SizedBox(height: 6),
            Text(
              stepMsg,
              style: const TextStyle(fontSize: 11, color: AppTheme.botanicalDark, fontWeight: FontWeight.w600),
            ),
          ],
          if (isLowStorage) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.earthAmber, width: 0.8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.disc_full, size: 16, color: AppTheme.earthAmber),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Warning: Low device storage (<50MB). Please clean up device files to prevent photo capture failures.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF795548)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (lastError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.alertCrimson, width: 0.8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.alertCrimson),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lastError,
                      style: const TextStyle(fontSize: 11, color: AppTheme.alertCrimson, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

