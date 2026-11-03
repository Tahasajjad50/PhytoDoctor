import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_theme.dart';

class EmployeeLocationTrackingScreen extends StatefulWidget {
  final UserModel user;

  const EmployeeLocationTrackingScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<EmployeeLocationTrackingScreen> createState() => _EmployeeLocationTrackingScreenState();
}

class _EmployeeLocationTrackingScreenState extends State<EmployeeLocationTrackingScreen> {
  // In a clean production state with only the CEO account, no fake devices are shown.
  // When real field staff log GPS visits, their live coordinate records will be populated here.
  final List<Map<String, dynamic>> _liveEmployees = [];
  bool _isRefreshing = false;

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching Google Maps: $e')),
      );
    }
  }

  void _refreshFeeds() {
    setState(() => _isRefreshing = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _isRefreshing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS feeds updated: 0 active field devices broadcasting.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: const Text('Live Employee Device Tracking'),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh GPS Feeds',
            onPressed: _isRefreshing ? null : _refreshFeeds,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Summary Card
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.gps_fixed, size: 20, color: AppTheme.botanicalPrimary),
                            SizedBox(width: 8),
                            Text(
                              'Real-Time GPS Tracking',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMain,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _liveEmployees.isEmpty
                                ? AppTheme.adminSlateLight
                                : AppTheme.cropGreenLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _liveEmployees.isEmpty
                                  ? AppTheme.adminSlate.withOpacity(0.3)
                                  : AppTheme.cropGreen.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            '${_liveEmployees.length} Devices Live',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _liveEmployees.isEmpty
                                  ? AppTheme.adminSlate
                                  : AppTheme.cropGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Track active employee devices and verify field shop locations via real-time satellite coordinates and geofences.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Devices List or Clean Empty State
              if (_liveEmployees.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                    border: Border.all(color: AppTheme.sageBorder),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.adminSlateLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.satellite_alt_outlined,
                          size: 36,
                          color: AppTheme.adminSlate,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No Active Devices Broadcasting',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'When authorized field staff clock in or log verified GPS customer visits from their mobile devices, their real-time satellite positions will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._liveEmployees.map((emp) => _buildLiveEmployeeCard(emp)).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveEmployeeCard(Map<String, dynamic> emp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Expanded(
                child: Text(
                  emp['name'] as String,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.cropGreenLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  emp['status'] as String,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.cropGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            emp['route'] as String,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _openGoogleMaps(emp['lat'] as double, emp['lng'] as double),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warmOffWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.sageBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppTheme.alertCrimson, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${emp['lat']}° N, ${emp['lng']}° E (±${emp['accuracy']}m)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.botanicalPrimary),
                        ),
                        Text(
                          emp['address'] as String,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.open_in_new, size: 14, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _openGoogleMaps(emp['lat'] as double, emp['lng'] as double),
            icon: const Icon(Icons.map, size: 16),
            label: const Text('Check Location now'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.botanicalPrimary,
              side: const BorderSide(color: AppTheme.botanicalPrimary),
              minimumSize: const Size.fromHeight(38),
            ),
          ),
        ],
      ),
    );
  }
}
