import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_theme.dart';
import 'visit_detail_screen.dart';

class VisitHistoryScreen extends StatefulWidget {
  final UserModel user;

  const VisitHistoryScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  String _selectedFilter = 'ALL';

  final List<Map<String, dynamic>> _mockVisits = [
    {
      'id': 'v-101',
      'client_name': 'Al-Rehman Agro Services',
      'client_type': 'DEALER',
      'purpose': 'Product Pitch (Trichoderma WP)',
      'timestamp': 'Today, 11:45 AM',
      'status': 'VERIFIED',
      'accuracy': '11.2m',
      'photo_id': 'PHOTO_20261021_01.jpg',
      'distance_to_shop': '18 meters',
      'notes': 'Booked order for 50 cartons of bio-fungicide. Dealer agreed on cash terms.',
      'verified_by': 'Farhan Qureshi (Manager)',
    },
    {
      'id': 'v-102',
      'client_name': 'Chaudhry Cotton Farm #4',
      'client_type': 'FARMER',
      'purpose': 'Crop Disease Inspection',
      'timestamp': 'Today, 09:15 AM',
      'status': 'VERIFIED',
      'accuracy': '8.5m',
      'photo_id': 'PHOTO_20261021_02.jpg',
      'distance_to_shop': 'On-Site Field',
      'notes': 'Pink bollworm scouting. Advised bio-control spray next Monday.',
      'verified_by': 'Farhan Qureshi (Manager)',
    },
    {
      'id': 'v-103',
      'client_name': 'Kisan Madadgar Pesticides',
      'client_type': 'DEALER',
      'purpose': 'Payment Recovery',
      'timestamp': 'Yesterday, 04:30 PM',
      'status': 'PENDING',
      'accuracy': '14.0m',
      'photo_id': 'PHOTO_20261020_03.jpg',
      'distance_to_shop': '32 meters',
      'notes': 'Collected payment cheque PKR 125,000 for September invoice.',
      'verified_by': 'Pending Manager Review',
    },
    {
      'id': 'v-104',
      'client_name': 'Bismillah Fertilizer Store',
      'client_type': 'DISTRIBUTOR',
      'purpose': 'General Relationship Visit',
      'timestamp': 'Yesterday, 02:10 PM',
      'status': 'REJECTED',
      'accuracy': '82.0m',
      'photo_id': 'PHOTO_20261020_04.jpg',
      'distance_to_shop': '650 meters away',
      'notes': 'Flagged: GPS coordinate too far from registered distributor address.',
      'verified_by': 'Flagged by Manager',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredVisits = _mockVisits.where((v) {
      if (_selectedFilter == 'ALL') return true;
      return v['status'] == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: const Text('Field Visit History'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Pills Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.surfaceCard,
              child: Row(
                children: [
                  _FilterTab(
                    title: 'All (${_mockVisits.length})',
                    isSelected: _selectedFilter == 'ALL',
                    onTap: () => setState(() => _selectedFilter = 'ALL'),
                  ),
                  const SizedBox(width: 8),
                  _FilterTab(
                    title: 'Verified',
                    isSelected: _selectedFilter == 'VERIFIED',
                    badgeColor: AppTheme.cropGreen,
                    onTap: () => setState(() => _selectedFilter = 'VERIFIED'),
                  ),
                  const SizedBox(width: 8),
                  _FilterTab(
                    title: 'Pending',
                    isSelected: _selectedFilter == 'PENDING',
                    badgeColor: AppTheme.earthAmber,
                    onTap: () => setState(() => _selectedFilter = 'PENDING'),
                  ),
                  const SizedBox(width: 8),
                  _FilterTab(
                    title: 'Rejected',
                    isSelected: _selectedFilter == 'REJECTED',
                    badgeColor: AppTheme.alertCrimson,
                    onTap: () => setState(() => _selectedFilter = 'REJECTED'),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Visit Cards List
            Expanded(
              child: filteredVisits.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.assignment_outlined, size: 48, color: AppTheme.textMuted),
                          SizedBox(height: 12),
                          Text('No field visits found for selected filter.'),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredVisits.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final visit = filteredVisits[index];
                        final status = visit['status'] as String;
                        final isVerified = status == 'VERIFIED';
                        final isPending = status == 'PENDING';

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
                                        visit['client_name'] as String,
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
                                  '${visit['purpose']} • ${visit['client_type']}',
                                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: AppTheme.textMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      visit['timestamp'] as String,
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                    ),
                                    const SizedBox(width: 14),
                                    const Icon(Icons.location_on, size: 14, color: AppTheme.botanicalPrimary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'GPS ±${visit['accuracy']}',
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
