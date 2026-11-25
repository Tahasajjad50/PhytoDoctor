import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class EmployeeLocationTrackingScreen extends StatefulWidget {
  final UserModel user;

  const EmployeeLocationTrackingScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<EmployeeLocationTrackingScreen> createState() => _EmployeeLocationTrackingScreenState();
}

class _EmployeeLocationTrackingScreenState extends State<EmployeeLocationTrackingScreen> {
  final List<Map<String, dynamic>> _liveEmployees = [];
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshFeeds(silent: true);
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng(Staff+Location)');
    final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      if (await canLaunchUrl(geoUri)) {
        final ok = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
    } catch (e) {
      debugPrint('Native geo launch notice: $e');
    }

    try {
      final ok = await launchUrl(webUri, mode: LaunchMode.externalNonBrowserApplication);
      if (ok) return;
    } catch (e) {
      debugPrint('External app launch notice: $e');
    }

    try {
      final ok = await launchUrl(webUri, mode: LaunchMode.platformDefault);
      if (ok) return;
    } catch (e) {
      debugPrint('Platform default launch notice: $e');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coordinates: ${lat.toStringAsFixed(4)}°N, ${lng.toStringAsFixed(4)}°E. (Lat/Long verified)'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _refreshFeeds({bool silent = false}) async {
    setState(() => _isRefreshing = true);
    try {
      final token = widget.user.accessToken;
      final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/visits/?limit=50');
      final res = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final items = decoded is List ? decoded : (decoded['items'] as List? ?? []);
        final Map<String, Map<String, dynamic>> latestByEmp = {};
        for (final raw in items) {
          if (raw is! Map) continue;
          final empId = (raw['employee_id'] ?? '').toString();
          if (empId.isEmpty || latestByEmp.containsKey(empId)) continue;
          final lat = (raw['latitude'] as num?)?.toDouble();
          final lng = (raw['longitude'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;
          final acc = (raw['gps_accuracy'] as num?)?.toDouble() ?? 10.0;
          latestByEmp[empId] = {
            'name': (raw['employee_name'] ?? raw['officer'] ?? 'Field Officer').toString(),
            'status': (raw['status'] ?? 'ACTIVE').toString(),
            'route': 'Last visit: ${raw['client_name'] ?? 'Field Client'}',
            'lat': lat,
            'lng': lng,
            'accuracy': acc.toStringAsFixed(1),
            'address': (raw['device_capture_time'] ?? '').toString(),
          };
        }
        if (!mounted) return;
        setState(() {
          _liveEmployees
            ..clear()
            ..addAll(latestByEmp.values);
        });
      }
    } catch (_) {
      // Preserve last fetched list on offline error
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_liveEmployees.length} active device(s).'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
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
                        Expanded(
                          child: Row(
                            children: const [
                              Icon(Icons.gps_fixed, size: 20, color: AppTheme.botanicalPrimary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Live GPS Tracking',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textMain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
                      'Live employee device locations.',
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
                        'Active employee locations will appear here.',
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
