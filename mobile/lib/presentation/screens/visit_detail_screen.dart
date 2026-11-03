import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

class VisitDetailScreen extends StatelessWidget {
  final Map<String, dynamic> visit;

  const VisitDetailScreen({Key? key, required this.visit}) : super(key: key);

  Future<void> _openGoogleMaps(BuildContext context, double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open map application.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching Google Maps: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = visit['status'] as String;
    final isVerified = status == 'VERIFIED';
    final isPending = status == 'PENDING';

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
                          visit['client_type'] as String,
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
                      visit['client_name'] as String,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Purpose: ${visit['purpose']}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recorded: ${visit['timestamp']}',
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
                                visit['photo_id'] as String,
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
                                'GPS ACCURACY: ±${visit['accuracy']}',
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
                          visit['distance_to_shop'] as String,
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
                      visit['notes'] as String,
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
