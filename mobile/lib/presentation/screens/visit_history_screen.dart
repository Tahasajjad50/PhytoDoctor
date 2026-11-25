import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import 'visit_detail_screen.dart';

class VisitHistoryScreen extends StatefulWidget {
  final UserModel user;
  final String? employeeId;
  final String? employeeName;

  const VisitHistoryScreen({
    Key? key,
    required this.user,
    this.employeeId,
    this.employeeName,
  }) : super(key: key);

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  String _selectedFilter = 'ALL';
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _visits = [];

  @override
  void initState() {
    super.initState();
    _fetchVisits();
  }

  Future<void> _fetchVisits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = widget.user.accessToken;
      final targetEmpId = widget.employeeId ?? (widget.user.isEmployee ? widget.user.id : null);
      var query = 'limit=100';
      if (targetEmpId != null) {
        query += '&employee_id=$targetEmpId';
      }
      final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/visits?$query');
      final res = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List<dynamic> items = data is Map ? (data['items'] ?? []) : (data is List ? data : []);
        final parsed = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (!mounted) return;
        setState(() {
          _visits = parsed;
          _isLoading = false;
        });
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['detail'] ?? 'Failed to load visits (${res.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredVisits = _visits.where((v) {
      if (_selectedFilter == 'ALL') return true;
      final status = (v['status']?.toString() ?? '').toUpperCase();
      return status == _selectedFilter;
    }).toList();

    final verifiedCount = _visits.where((v) => (v['status']?.toString() ?? '').toUpperCase() == 'VERIFIED').length;
    final pendingCount = _visits.where((v) => (v['status']?.toString() ?? '').toUpperCase() == 'PENDING').length;
    final rejectedCount = _visits.where((v) => (v['status']?.toString() ?? '').toUpperCase() == 'REJECTED').length;

    final title = widget.employeeName != null
        ? '${widget.employeeName} - Visit History'
        : 'Field Visit History';

    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchVisits,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchVisits,
          child: Column(
            children: [
              // Filter Pills Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppTheme.surfaceCard,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterTab(
                        title: 'All (${_visits.length})',
                        isSelected: _selectedFilter == 'ALL',
                        onTap: () => setState(() => _selectedFilter = 'ALL'),
                      ),
                      const SizedBox(width: 8),
                      _FilterTab(
                        title: 'Verified ($verifiedCount)',
                        isSelected: _selectedFilter == 'VERIFIED',
                        badgeColor: AppTheme.cropGreen,
                        onTap: () => setState(() => _selectedFilter = 'VERIFIED'),
                      ),
                      const SizedBox(width: 8),
                      _FilterTab(
                        title: 'Pending ($pendingCount)',
                        isSelected: _selectedFilter == 'PENDING',
                        badgeColor: AppTheme.earthAmber,
                        onTap: () => setState(() => _selectedFilter = 'PENDING'),
                      ),
                      const SizedBox(width: 8),
                      _FilterTab(
                        title: 'Rejected ($rejectedCount)',
                        isSelected: _selectedFilter == 'REJECTED',
                        badgeColor: AppTheme.alertCrimson,
                        onTap: () => setState(() => _selectedFilter = 'REJECTED'),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),

              // Content Area
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.botanicalPrimary),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, size: 48, color: AppTheme.alertCrimson),
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchVisits,
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.botanicalPrimary),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : filteredVisits.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.assignment_outlined, size: 48, color: AppTheme.textMuted),
                                    const SizedBox(height: 12),
                                    Text(
                                      _visits.isEmpty
                                          ? 'No field visits recorded yet.'
                                          : 'No visits matching selected filter.',
                                      style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredVisits.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final visit = filteredVisits[index];
                                  final status = (visit['status']?.toString() ?? 'PENDING').toUpperCase();
                                  final isVerified = status == 'VERIFIED';
                                  final isPending = status == 'PENDING';

                                  Color badgeColor = isVerified
                                      ? AppTheme.cropGreen
                                      : (isPending ? AppTheme.earthAmber : AppTheme.alertCrimson);
                                  Color badgeBg = isVerified
                                      ? AppTheme.cropGreenLight
                                      : (isPending ? AppTheme.earthAmberLight : AppTheme.alertCrimsonLight);

                                  final clientName = visit['client_name']?.toString() ?? 'Field Visit';
                                  final empName = visit['employee_name']?.toString() ?? visit['officer']?.toString() ?? '';
                                  final notes = visit['notes']?.toString() ?? visit['purpose']?.toString() ?? 'Field Inspection';
                                  final captureTime = visit['device_capture_time']?.toString() ?? visit['timestamp']?.toString() ?? '';
                                  final accuracy = visit['gps_accuracy'] ?? visit['accuracy'] ?? 10;

                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => VisitDetailScreen(visit: visit),
                                        ),
                                      ).then((_) => _fetchVisits());
                                    },
                                    child: Container(
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
                                              Expanded(
                                                child: Text(
                                                  clientName,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.textMain,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: badgeBg,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: badgeColor.withOpacity(0.4)),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: badgeColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (empName.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Officer: $empName',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.botanicalPrimary),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Text(
                                            notes,
                                            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time, size: 14, color: AppTheme.textMuted),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  captureTime.length > 19 ? captureTime.substring(0, 19).replaceFirst('T', ' ') : captureTime,
                                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const Icon(Icons.location_on, size: 14, color: AppTheme.botanicalPrimary),
                                              const SizedBox(width: 4),
                                              Text(
                                                'GPS ±${(accuracy is num ? accuracy.toDouble() : double.tryParse(accuracy.toString()) ?? 0.0).toStringAsFixed(1)}m',
                                                style: const TextStyle(fontSize: 12, color: AppTheme.botanicalPrimary),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String title;
  final bool isSelected;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _FilterTab({
    Key? key,
    required this.title,
    required this.isSelected,
    this.badgeColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.botanicalPrimary : AppTheme.warmOffWhite,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.botanicalPrimary : AppTheme.sageBorder,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
