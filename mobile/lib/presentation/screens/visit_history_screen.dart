import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/real_visit_repository.dart';
import 'visit_detail_screen.dart';

class VisitHistoryScreen extends StatefulWidget {
  final UserModel user;

  const VisitHistoryScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  String _selectedFilter = 'ALL';
  List<Map<String, dynamic>> _visits = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVisits();
  }

  Future<void> _loadVisits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = RealVisitRepository();
      final items = await repo.getVisitHistory(widget.user.accessToken ?? '');
      if (!mounted) return;
      setState(() {
        _visits = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load visits: ${e.toString().replaceAll('Exception: ', '')}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredVisits = _visits.where((v) {
      if (_selectedFilter == 'ALL') return true;
      final s = v['status']?.toString().toUpperCase() ?? '';
      return s == _selectedFilter;
    }).toList();

    final verifiedCount = _visits.where((v) => (v['status']?.toString().toUpperCase() ?? '') == 'VERIFIED').length;
    final pendingCount = _visits.where((v) => (v['status']?.toString().toUpperCase() ?? '') == 'PENDING').length;
    final rejectedCount = _visits.where((v) => (v['status']?.toString().toUpperCase() ?? '') == 'REJECTED').length;

    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: const Text('Field Visit History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVisits,
            tooltip: 'Refresh Visits',
          ),
        ],
      ),
      body: SafeArea(
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

            // Visit Cards List
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
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _loadVisits,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.botanicalPrimary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filteredVisits.isEmpty
                          ? RefreshIndicator(
                              onRefresh: _loadVisits,
                              color: AppTheme.botanicalPrimary,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.45,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.assignment_outlined, size: 48, color: AppTheme.textMuted),
                                          const SizedBox(height: 12),
                                          Text(
                                            _selectedFilter == 'ALL'
                                                ? 'No field visits logged yet.\nSubmit visits to see live history here.'
                                                : 'No $_selectedFilter field visits found.',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: AppTheme.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadVisits,
                              color: AppTheme.botanicalPrimary,
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredVisits.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final visit = filteredVisits[index];
                                  final status = visit['status']?.toString().toUpperCase() ?? 'PENDING';
                                  final isVerified = status == 'VERIFIED';
                                  final isPending = status == 'PENDING';

                                  final clientName = visit['client_name']?.toString() ?? 'Field Client';
                                  final purpose = visit['purpose']?.toString() ?? visit['notes']?.toString() ?? 'Crop Health Inspection';
                                  final timestamp = visit['timestamp']?.toString() ?? visit['device_capture_time']?.toString() ?? 'Recent';
                                  final accuracy = visit['accuracy']?.toString() ?? (visit['gps_accuracy'] != null ? '${visit['gps_accuracy']}m' : '10.0m');
                                  final clientType = visit['client_type']?.toString() ?? 'CLIENT';

                                  Color badgeColor = isVerified
                                      ? AppTheme.cropGreen
                                      : (isPending ? AppTheme.earthAmber : AppTheme.alertCrimson);
                                  Color badgeBg = isVerified
                                      ? AppTheme.cropGreenLight
                                      : (isPending ? AppTheme.earthAmberLight : AppTheme.alertCrimsonLight);

                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => VisitDetailScreen(visit: visit),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
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
                                                ),
                                              ),
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
                                          const SizedBox(height: 6),
                                          Text(
                                            '$purpose • $clientType',
                                            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time, size: 14, color: AppTheme.textMuted),
                                              const SizedBox(width: 4),
                                              Text(
                                                timestamp,
                                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                              ),
                                              const SizedBox(width: 14),
                                              const Icon(Icons.location_on, size: 14, color: AppTheme.botanicalPrimary),
                                              const SizedBox(width: 4),
                                              Text(
                                                'GPS ±$accuracy',
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
            ),
          ],
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
      borderRadius: BorderRadius.circular(6),
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
