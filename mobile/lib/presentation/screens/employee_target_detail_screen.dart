import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/real_visit_repository.dart';
import '../../data/repositories/visit_repository.dart';
import '../widgets/phyto_logo.dart';
import 'record_visit_screen.dart';
import 'visit_detail_screen.dart';

class EmployeeTargetDetailScreen extends StatefulWidget {
  final UserModel user;
  final VisitRepository? repository;
  final int initialTarget;
  final int initialCompleted;
  final int initialVerified;
  final int initialRemaining;
  final List<Map<String, dynamic>>? initialTodayVisits;

  const EmployeeTargetDetailScreen({
    Key? key,
    required this.user,
    this.repository,
    this.initialTarget = 6,
    this.initialCompleted = 0,
    this.initialVerified = 0,
    this.initialRemaining = 6,
    this.initialTodayVisits,
  }) : super(key: key);

  @override
  State<EmployeeTargetDetailScreen> createState() => _EmployeeTargetDetailScreenState();
}

class _EmployeeTargetDetailScreenState extends State<EmployeeTargetDetailScreen> {
  late final VisitRepository _repository;
  bool _isLoading = false;
  String? _errorMessage;

  late int _target;
  late int _completed;
  late int _verified;
  late int _remaining;
  List<Map<String, dynamic>> _todayVisits = [];
  String _selectedFilter = 'ALL'; // 'ALL', 'ADMIN_UPDATED', 'PENDING', 'REMAINING'

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? RealVisitRepository();
    _target = widget.initialTarget;
    _completed = widget.initialCompleted;
    _verified = widget.initialVerified;
    _remaining = widget.initialRemaining;
    if (widget.initialTodayVisits != null && widget.initialTodayVisits!.isNotEmpty) {
      _todayVisits = List.from(widget.initialTodayVisits!);
    } else {
      _fetchLatestSummary();
    }
  }

  Future<void> _fetchLatestSummary() async {
    final token = widget.user.accessToken ?? '';
    if (token.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final data = await _repository.getDashboardSummary(token);
      if (!mounted) return;
      setState(() {
        _target = data['target_visits'] ?? _target;
        _completed = data['completed_today'] ?? _completed;
        _verified = data['verified_visits'] ?? _verified;
        _remaining = data['remaining_visits'] ?? (_target - _verified).clamp(0, 99);
        final rawVisits = data['today_visits'];
        if (rawVisits is List) {
          _todayVisits = rawVisits.map((e) => e as Map<String, dynamic>).toList();
        }
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not sync live target breakdown. Showing local cached values.';
      });
    }
  }

  List<Map<String, dynamic>> get _filteredVisits {
    switch (_selectedFilter) {
      case 'ADMIN_UPDATED':
        return _todayVisits.where((v) {
          final isUpdated = v['is_updated_by_admin'] == true ||
              (v['status'] != null && v['status'].toString().toUpperCase() != 'PENDING') ||
              v['review_reason'] != null;
          return isUpdated;
        }).toList();
      case 'PENDING':
        return _todayVisits.where((v) {
          final status = (v['status'] ?? 'PENDING').toString().toUpperCase();
          return status == 'PENDING';
        }).toList();
      case 'ALL':
      default:
        return _todayVisits;
    }
  }

  int get _adminUpdatedCount {
    return _todayVisits.where((v) {
      return v['is_updated_by_admin'] == true ||
          (v['status'] != null && v['status'].toString().toUpperCase() != 'PENDING') ||
          v['review_reason'] != null;
    }).length;
  }

  int get _pendingCount {
    return _todayVisits.where((v) {
      final status = (v['status'] ?? 'PENDING').toString().toUpperCase();
      return status == 'PENDING';
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final double progressRatio = (_target > 0 ? (_verified / _target) : 0.0).clamp(0.0, 1.0);
    final int progressPercent = (progressRatio * 100).toInt();

    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: const Text('Daily Visit Target & Status'),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh Target Progress',
            onPressed: _isLoading ? null : _fetchLatestSummary,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLatestSummary,
        color: AppTheme.botanicalPrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Target Quota Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.botanicalPrimary,
                      AppTheme.botanicalDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.botanicalPrimary.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.track_changes, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Today's Visit Quota Progress",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$progressPercent% Done',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$_verified',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          ' / $_target Visits Verified',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progressRatio,
                        minHeight: 10,
                        backgroundColor: Colors.white.withOpacity(0.25),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cropGreen),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _remaining == 0
                              ? '🎯 Daily Quota Achieved!'
                              : '$_remaining Visits Remaining to Complete Quota',
                          style: TextStyle(
                            color: _remaining == 0 ? Colors.white : const Color(0xFFFFD54F),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Target: $_target/day',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 4 Detailed Status Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: _StatusMetricTile(
                      icon: Icons.flag,
                      title: "Today's Target",
                      value: '$_target Visits',
                      subtitle: 'Set by Administration',
                      color: AppTheme.botanicalPrimary,
                      badge: 'Quota',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatusMetricTile(
                      icon: Icons.done_all,
                      title: 'Visits Done',
                      value: '$_completed Visits',
                      subtitle: 'Submitted in Field',
                      color: AppTheme.adminSlate,
                      badge: 'Logged',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _StatusMetricTile(
                      icon: Icons.hourglass_top,
                      title: 'Visits Remaining',
                      value: '$_remaining Visits',
                      subtitle: _remaining == 0 ? 'Goal completed!' : 'To reach today\'s target',
                      color: AppTheme.earthAmber,
                      badge: _remaining == 0 ? 'Completed' : 'Remaining',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatusMetricTile(
                      icon: Icons.verified_user,
                      title: 'Admin Verified',
                      value: '$_verified Visits',
                      subtitle: 'Audited by Supervisor',
                      color: AppTheme.cropGreen,
                      badge: 'Confirmed',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // Notice on Quota Assignment Rule
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.sageLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.sageBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppTheme.botanicalPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Target of $_target visits/day is set by your Admin. Only supervisor-verified on-site audits qualify for quota completion.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.botanicalDark,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Breakdown Header & Filter Tabs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Today's Visit Breakdown",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMain,
                    ),
                  ),
                  Text(
                    '${_todayVisits.length} Logged Today',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChipButton(
                      label: 'All Visits (${_todayVisits.length})',
                      isSelected: _selectedFilter == 'ALL',
                      onTap: () => setState(() => _selectedFilter = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipButton(
                      label: 'Admin Updated ($_adminUpdatedCount)',
                      isSelected: _selectedFilter == 'ADMIN_UPDATED',
                      onTap: () => setState(() => _selectedFilter = 'ADMIN_UPDATED'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipButton(
                      label: 'Pending Review ($_pendingCount)',
                      isSelected: _selectedFilter == 'PENDING',
                      onTap: () => setState(() => _selectedFilter = 'PENDING'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipButton(
                      label: 'Remaining Slots ($_remaining)',
                      isSelected: _selectedFilter == 'REMAINING',
                      onTap: () => setState(() => _selectedFilter = 'REMAINING'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Render Filtered Visit List or Remaining Quota Slots
              if (_selectedFilter == 'REMAINING') ...[
                _buildRemainingQuotaView(),
              ] else if (_filteredVisits.isEmpty) ...[
                _buildEmptyState(),
              ] else ...[
                ..._filteredVisits.map((visit) => _buildVisitCard(visit)),
              ],

              const SizedBox(height: 24),

              // Quick Action Button
              ElevatedButton.icon(
                onPressed: () async {
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecordVisitScreen(user: widget.user),
                    ),
                  );
                  if (res == true) {
                    _fetchLatestSummary();
                  }
                },
                icon: const Icon(Icons.add_a_photo, size: 20),
                label: const Text('Record New Visit Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.botanicalPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemainingQuotaView() {
    if (_remaining == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cropGreenLight.withOpacity(0.4),
          borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
          border: Border.all(color: AppTheme.cropGreen),
        ),
        child: Column(
          children: const [
            Icon(Icons.check_circle_outline, color: AppTheme.cropGreen, size: 44),
            SizedBox(height: 12),
            Text(
              'All Daily Visits Completed!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.botanicalDark,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'You have met and fulfilled your assigned visit target for today.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(_remaining, (index) {
        final slotNumber = _completed + index + 1;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
            border: Border.all(color: AppTheme.earthAmber.withOpacity(0.6), style: BorderStyle.solid),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.earthAmber.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$slotNumber',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.earthAmber,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remaining Quota Slot #$slotNumber',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target $_target visits today • ${index + 1} of $_remaining remaining',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.earthAmber),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
        border: Border.all(color: AppTheme.sageBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.textMuted.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(
            _selectedFilter == 'ADMIN_UPDATED'
                ? 'No Admin Updates Yet Today'
                : 'No Field Visits Logged Today',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedFilter == 'ADMIN_UPDATED'
                ? 'Visits submitted today will appear here as soon as reviewed or updated by your branch manager or CEO.'
                : 'You have not recorded any field visits today. Press "Record New Visit Now" below to begin.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> visit) {
    final status = (visit['status'] ?? 'PENDING').toString().toUpperCase();
    final clientName = (visit['client_name'] ?? 'Field Visit').toString();
    final clientPhone = visit['client_phone'] as String?;
    final notes = visit['notes'] as String?;
    final captureTimeStr = (visit['device_capture_time'] ?? visit['server_receipt_time'] ?? visit['time']) as String?;
    final accuracy = (visit['gps_accuracy'] as num?)?.toDouble() ?? 0.0;
    final reviewReason = visit['review_reason'] as String?;
    final reviewerName = visit['reviewed_by_name'] as String?;
    final reviewedAtStr = visit['reviewed_at'] as String?;
    final bool isUpdatedByAdmin = visit['is_updated_by_admin'] == true ||
        status != 'PENDING' ||
        reviewReason != null;

    Color badgeBg;
    Color badgeText;
    String badgeLabel;
    IconData badgeIcon;

    if (status == 'VERIFIED') {
      badgeBg = AppTheme.cropGreenLight;
      badgeText = AppTheme.cropGreen;
      badgeLabel = 'VERIFIED BY ADMIN';
      badgeIcon = Icons.verified;
    } else if (status == 'REJECTED') {
      badgeBg = const Color(0xFFFFEBEE);
      badgeText = AppTheme.alertCrimson;
      badgeLabel = 'REJECTED BY ADMIN';
      badgeIcon = Icons.cancel;
    } else {
      badgeBg = const Color(0xFFFFF8E1);
      badgeText = AppTheme.earthAmber;
      badgeLabel = 'PENDING ADMIN AUDIT';
      badgeIcon = Icons.hourglass_empty;
    }

    String timeFormatted = '--:--';
    if (captureTimeStr != null) {
      try {
        final dt = DateTime.parse(captureTimeStr).toLocal();
        final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final m = dt.minute.toString().padLeft(2, '0');
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        timeFormatted = '$h:$m $ampm';
      } catch (_) {
        timeFormatted = captureTimeStr;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
        border: Border.all(
          color: isUpdatedByAdmin && status == 'VERIFIED'
              ? AppTheme.cropGreen.withOpacity(0.5)
              : (isUpdatedByAdmin && status == 'REJECTED'
                  ? AppTheme.alertCrimson.withOpacity(0.5)
                  : AppTheme.sageBorder),
          width: isUpdatedByAdmin ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        clientName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMain,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 13, color: badgeText),
                          const SizedBox(width: 4),
                          Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: badgeText,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'Time: $timeFormatted',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.gps_fixed, size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'GPS ±${accuracy.toStringAsFixed(1)}m',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (clientPhone != null && clientPhone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 13, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        clientPhone,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.sageLight.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Agronomist Notes: $notes',
                      style: const TextStyle(fontSize: 11, color: AppTheme.botanicalDark, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Admin Review Banner (if updated/verified/rejected by admin)
          if (isUpdatedByAdmin) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: status == 'VERIFIED'
                    ? AppTheme.cropGreenLight.withOpacity(0.3)
                    : (status == 'REJECTED' ? const Color(0xFFFFEBEE) : AppTheme.sageLight),
                border: Border(
                  top: BorderSide(
                    color: status == 'VERIFIED'
                        ? AppTheme.cropGreen.withOpacity(0.3)
                        : (status == 'REJECTED' ? AppTheme.alertCrimson.withOpacity(0.3) : AppTheme.sageBorder),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        status == 'VERIFIED' ? Icons.verified : (status == 'REJECTED' ? Icons.error_outline : Icons.rate_review),
                        size: 15,
                        color: status == 'VERIFIED' ? AppTheme.cropGreen : (status == 'REJECTED' ? AppTheme.alertCrimson : AppTheme.botanicalPrimary),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status == 'VERIFIED'
                            ? 'Admin Audit: Verified & Approved'
                            : (status == 'REJECTED' ? 'Admin Audit: Rejected / Needs Correction' : 'Admin Update Received'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: status == 'VERIFIED' ? AppTheme.cropGreen : (status == 'REJECTED' ? AppTheme.alertCrimson : AppTheme.botanicalPrimary),
                        ),
                      ),
                    ],
                  ),
                  if (reviewerName != null && reviewerName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Reviewed by: $reviewerName',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                    ),
                  ],
                  if (reviewReason != null && reviewReason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Supervisor Notes: "$reviewReason"',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: status == 'REJECTED' ? AppTheme.alertCrimson : AppTheme.textMain,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusMetricTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final String badge;

  const _StatusMetricTile({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.badge,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMain),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipButton({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.botanicalPrimary : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.botanicalPrimary : AppTheme.sageBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textMain,
          ),
        ),
      ),
    );
  }
}

