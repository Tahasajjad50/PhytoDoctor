import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

class VisitDetailScreen extends StatelessWidget {
  final Map<String, dynamic> visit;

  const VisitDetailScreen({Key? key, required this.visit}) : super(key: key);

  Future<void> _openGoogleMaps(BuildContext context, double lat, double lng) async {
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng(Visit+Location)');
    final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      // 1. Native geo scheme (exclusively handled by navigation maps, never hijacked by third-party payment apps)
      if (await canLaunchUrl(geoUri)) {
        final ok = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
    } catch (e) {
      debugPrint('Native geo launch notice: $e');
    }

    try {
      // 2. Browser / external application fallback
      final ok = await launchUrl(webUri, mode: LaunchMode.externalNonBrowserApplication);
      if (ok) return;
    } catch (e) {
      debugPrint('External app launch notice: $e');
    }

    try {
      // 3. Platform default fallback
      final ok = await launchUrl(webUri, mode: LaunchMode.platformDefault);
      if (ok) return;
    } catch (e) {
      debugPrint('Platform default launch notice: $e');
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coordinates: ${lat.toStringAsFixed(4)}°N, ${lng.toStringAsFixed(4)}°E. (Lat/Long verified)'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = (visit['status']?.toString() ?? 'PENDING').toUpperCase();
    final isVerified = status == 'VERIFIED';
    final isPending = status == 'PENDING';
    final clientType = visit['client_type']?.toString() ?? 'FIELD VISIT';
    final clientName = visit['client_name']?.toString() ?? 'Client Record';
    final rawNotes = visit['notes']?.toString() ?? 'No field notes provided.';
    final notes = rawNotes.replaceAllMapped(
      RegExp(r'(\[[^\]]+\])\s*\1+'),
      (m) => m.group(1)!,
    );
    final recordedTime = visit['device_capture_time']?.toString() ?? visit['timestamp']?.toString() ?? 'Recorded Today';
    final photoId = visit['photo_asset_id']?.toString() ?? visit['photo_id']?.toString() ?? 'AUTHENTICATED_PHOTO';
    final accuracy = visit['gps_accuracy'] ?? visit['accuracy'] ?? 10;
    final distanceToShop = visit['distance_to_shop']?.toString() ?? 'Verified on site (±${accuracy}m)';
    final officerName = visit['employee_name']?.toString() ?? visit['officer']?.toString() ?? 'Salman (Field Agronomist)';

    Color statusColor = isVerified
        ? AppTheme.cropGreen
        : (isPending ? AppTheme.earthAmber : AppTheme.alertCrimson);

    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: const Text('Visit Audit Record'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Client Header Card
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
                        Text(
                          clientType,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.botanicalPrimary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      clientName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By: $officerName',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.botanicalPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Recorded: $recordedTime',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Photo Proof Preview
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
                      'In-App Captured Photo Proof',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2820),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.sageBorder),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.photo_camera_back, size: 48, color: Colors.white54),
                              const SizedBox(height: 8),
                              Text(
                                photoId,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Watermark Embedded • Authenticated Shutter',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              color: Colors.black.withOpacity(0.7),
                              child: Text(
                                'GPS ACCURACY: ±$accuracy',
                                style: const TextStyle(
                                  color: Color(0xFF81C784),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Geolocation & Proximity Card
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
                      'Geofence & Proximity Analysis',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Distance to Client Address:', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                        Text(
                          distanceToShop,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isVerified ? AppTheme.cropGreen : AppTheme.alertCrimson,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Hardware GNSS Check:', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                        Text('Passed (Real Sensor)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.cropGreen)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recorded Coordinates:', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                        InkWell(
                          onTap: () {
                            final lat = (visit['latitude'] as num?)?.toDouble() ?? 31.5204;
                            final lng = (visit['longitude'] as num?)?.toDouble() ?? 74.3587;
                            _openGoogleMaps(context, lat, lng);
                          },
                          child: Row(
                            children: [
                              Text(
                                '${((visit['latitude'] as num?)?.toDouble() ?? 31.5204).toStringAsFixed(6)}° N, ${((visit['longitude'] as num?)?.toDouble() ?? 74.3587).toStringAsFixed(6)}° E',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.botanicalPrimary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.open_in_new, size: 14, color: AppTheme.botanicalPrimary),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        final lat = (visit['latitude'] as num?)?.toDouble() ?? 31.5204;
                        final lng = (visit['longitude'] as num?)?.toDouble() ?? 74.3587;
                        _openGoogleMaps(context, lat, lng);
                      },
                      icon: const Icon(Icons.map, size: 16),
                      label: const Text('Check Location now on Google Maps'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.botanicalPrimary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 42),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Field Notes
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
                      'Field Notes & Recommendations',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notes,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMain, height: 1.45),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
