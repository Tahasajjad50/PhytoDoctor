import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/attendance_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/attendance_service.dart';
import '../../core/theme/app_theme.dart';

class EmployeeAttendanceScreen extends StatefulWidget {
  final UserModel currentUser;

  const EmployeeAttendanceScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  State<EmployeeAttendanceScreen> createState() => _EmployeeAttendanceScreenState();
}

class _EmployeeAttendanceScreenState extends State<EmployeeAttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  AdminAttendanceRosterModel? _roster;
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // 'ALL', 'ACTIVE', 'INACTIVE'
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadRoster();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_isLoading) {
        _loadRoster(isBackground: true);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRoster({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final token = widget.currentUser.accessToken ?? '';
      final roster = await _attendanceService.getAdminRoster(token);
      if (!mounted) return;
      setState(() {
        _roster = roster;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!isBackground) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final weekday = days[dt.weekday - 1];
      final month = months[dt.month - 1];
      return '$weekday, $month ${dt.day}, ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = (_roster?.employees ?? []).where((emp) {
      if (_selectedFilter == 'ACTIVE' && !emp.isActiveNow) return false;
      if (_selectedFilter == 'INACTIVE' && emp.isActiveNow) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final matchName = emp.fullName.toLowerCase().contains(query);
        final matchUser = emp.username.toLowerCase().contains(query);
        final matchDesig = (emp.designation ?? '').toLowerCase().contains(query);
        if (!matchName && !matchUser && !matchDesig) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: const Text('Staff Attendance Roster'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Roster',
            onPressed: () => _loadRoster(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadRoster(),
          color: AppTheme.botanicalPrimary,
          child: _isLoading && _roster == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.botanicalPrimary),
                )
              : _errorMessage != null && _roster == null
                  ? _buildErrorView()
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        _buildDateBanner(),
                        const SizedBox(height: 14),
                        _buildSummaryCards(),
                        const SizedBox(height: 16),
                        _buildSearchAndFilterBar(),
                        const SizedBox(height: 14),
                        if (filteredEmployees.isEmpty)
                          _buildEmptyList()
                        else
                          ...filteredEmployees.map((emp) => _buildEmployeeCard(emp)),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildDateBanner() {
    final dateStr = _roster?.date != null ? _formatDate(_roster!.date) : 'Today';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.sageBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.botanicalPrimary),
              const SizedBox(width: 8),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.cropGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE ROSTER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.cropGreen,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final total = _roster?.totalEmployees ?? 0;
    final active = _roster?.activeCount ?? 0;
    final inactive = _roster?.inactiveCount ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'Total Staff',
            count: '$total',
            color: AppTheme.adminSlate,
            icon: Icons.people_outline,
            isSelected: _selectedFilter == 'ALL',
            onTap: () => setState(() => _selectedFilter = 'ALL'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            title: 'Active Now',
            count: '$active',
            color: AppTheme.cropGreen,
            icon: Icons.check_circle_outline,
            isSelected: _selectedFilter == 'ACTIVE',
            onTap: () => setState(() => _selectedFilter = 'ACTIVE'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            title: 'Off Duty',
            count: '$inactive',
            color: Colors.grey.shade600,
            icon: Icons.pause_circle_outline,
            isSelected: _selectedFilter == 'INACTIVE',
            onTap: () => setState(() => _selectedFilter = 'INACTIVE'),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String count,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppTheme.sageBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              count,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return TextField(
      onChanged: (val) => setState(() => _searchQuery = val),
      decoration: InputDecoration(
        hintText: 'Search agronomist by name or username...',
        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textMuted),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => setState(() => _searchQuery = ''),
              )
            : null,
        filled: true,
        fillColor: AppTheme.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.sageBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.sageBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.botanicalPrimary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeAttendanceItemModel emp) {
    final isActive = emp.isActiveNow;
    final initials = emp.fullName.trim().isNotEmpty
        ? emp.fullName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('').toUpperCase()
        : 'AG';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppTheme.cropGreen.withOpacity(0.5) : AppTheme.sageBorder,
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppTheme.cropGreen.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isActive
                        ? AppTheme.cropGreen.withOpacity(0.15)
                        : Colors.grey.shade200,
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isActive ? AppTheme.cropGreen : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.cropGreen : Colors.grey.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.fullName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${emp.username}' +
                          (emp.designation != null && emp.designation!.isNotEmpty
                              ? ' • ${emp.designation}'
                              : ' • Field Agronomist'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    if (emp.phone != null && emp.phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Phone: ${emp.phone}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFE8F5E9) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isActive ? AppTheme.cropGreen.withOpacity(0.5) : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? Icons.fiber_manual_record : Icons.remove_circle_outline,
                      size: 9,
                      color: isActive ? AppTheme.cropGreen : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isActive ? 'ACTIVE NOW' : 'OFF DUTY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isActive ? AppTheme.cropGreen : Colors.grey.shade600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.sageBorder),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTimeDetail(
                  label: 'Mark In Time',
                  time: emp.clockInTime != null ? _formatTime(emp.clockInTime) : 'Not marked in',
                  icon: Icons.login,
                  color: emp.clockInTime != null ? AppTheme.cropGreen : AppTheme.textMuted,
                ),
              ),
              Container(
                height: 28,
                width: 1,
                color: AppTheme.sageBorder,
              ),
              Expanded(
                child: _buildTimeDetail(
                  label: 'Mark Out Time',
                  time: emp.clockOutTime != null
                      ? _formatTime(emp.clockOutTime)
                      : (isActive ? 'On Duty' : 'Not marked out'),
                  icon: Icons.logout,
                  color: emp.clockOutTime != null
                      ? AppTheme.alertCrimson
                      : (isActive ? AppTheme.botanicalPrimary : AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDetail({
    required String label,
    required String time,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyList() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.sageBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.badge_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No Agronomists Found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'No staff member matched "$_searchQuery".'
                : 'No employees registered under your management.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.alertCrimson),
            const SizedBox(height: 12),
            const Text(
              'Failed to Load Attendance Roster',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadRoster(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.botanicalPrimary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
