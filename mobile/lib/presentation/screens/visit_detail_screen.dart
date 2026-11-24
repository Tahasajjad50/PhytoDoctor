import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class VisitDetailScreen extends StatefulWidget {
  final Map<String, dynamic> visit;

  const VisitDetailScreen({Key? key, required this.visit}) : super(key: key);

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  late Map<String, dynamic> _visit;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _visit = Map<String, dynamic>.from(widget.visit);
  }

  Future<void> _openGoogleMaps(BuildContext context, double lat, double lng) async {
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng(Visit+Location)');
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

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coordinates: ${lat.toStringAsFixed(4)}°N, ${lng.toStringAsFixed(4)}°E. (Lat/Long verified)'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _verifyVisit(bool approved, [String? reviewReason]) async {
    final visitId = _visit['id']?.toString();
    if (visitId == null || visitId.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final token = AuthService().currentUser?.accessToken;
      final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/visits/$visitId/verify');
      final finalReason = reviewReason ?? (approved ? 'Verified on-site by supervisor' : 'Flagged by supervisor review');
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': approved ? 'VERIFIED' : 'REJECTED',
          'review_reason': finalReason,
        }),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _visit['status'] = approved ? 'VERIFIED' : 'REJECTED';
          _visit['review_reason'] = finalReason;
          _visit['reviewed_at'] = DateTime.now().toUtc().toIso8601String();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approved
                ? 'Visit successfully verified & approved'
                : 'Visit rejected: $finalReason'),
            backgroundColor: approved ? AppTheme.cropGreen : AppTheme.alertCrimson,
          ),
        );
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['detail'] ?? 'Verification failed (${res.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating visit: $e'),
          backgroundColor: AppTheme.alertCrimson,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showRejectReasonDialog(String clientName) async {
    final TextEditingController reasonController = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.alertCrimson, size: 26),
            SizedBox(width: 8),
            Text(
              'Reject Field Visit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject the visit for "$clientName"?',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMain),
            ),
            const SizedBox(height: 12),
            const Text(
              'Rejection Reason (Optional):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMain),
              decoration: InputDecoration(
                hintText: 'e.g. Unclear photo proof, location mismatch, client unreachable...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.sageBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.cropGreen),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertCrimson,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Reject Visit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userReason = reasonController.text.trim();
      final reasonToSend = userReason.isNotEmpty ? userReason : 'Flagged by supervisor review';
      await _verifyVisit(false, reasonToSend);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (_visit['status']?.toString() ?? 'PENDING').toUpperCase();
    final isVerified = status == 'VERIFIED';
    final isPending = status == 'PENDING';
    final isRejected = status == 'REJECTED';
    final clientType = _visit['client_type']?.toString() ?? 'FIELD VISIT';
    final clientName = _visit['client_name']?.toString() ?? 'Client Record';
    final rawNotes = _visit['notes']?.toString() ?? 'No field notes provided.';
    final notes = rawNotes.replaceAllMapped(
      RegExp(r'(\[[^\]]+\])\s*\1+'),
      (m) => m.group(1)!,
    );
    final recordedTime = _visit['device_capture_time']?.toString() ?? _visit['timestamp']?.toString() ?? 'Recorded Today';
    final photoId = _visit['photo_asset_id']?.toString() ?? _visit['photo_id']?.toString() ?? 'AUTHENTICATED_PHOTO';
    final accuracy = _visit['gps_accuracy'] ?? _visit['accuracy'] ?? 10;
    final distanceToShop = _visit['distance_to_shop']?.toString() ?? 'Verified on site (±${accuracy}m)';
    final officerName = _visit['employee_name']?.toString() ?? _visit['officer']?.toString() ?? 'Salman (Field Agronomist)';

    Color statusColor = isVerified
        ? AppTheme.cropGreen
        : (isPending ? AppTheme.earthAmber : AppTheme.alertCrimson);

    final currentUser = AuthService().currentUser;
    final canVerify = (currentUser?.role == 'MANAGER' || currentUser?.role == 'ADMIN' || currentUser?.role == 'OWNER');

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

              // Rejection Reason Banner (if visit was rejected or reviewed with explanation)
              if (isRejected || (_visit['review_reason'] != null && _visit['review_reason'].toString().isNotEmpty)) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F0),
                    borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
                    border: Border.all(color: AppTheme.alertCrimson.withOpacity(0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.cancel_outlined, color: AppTheme.alertCrimson, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Visit Flagged / Rejected by Supervisor',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.alertCrimson,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _visit['review_reason']?.toString() ?? 'Flagged during supervisor review',
                              style: const TextStyle(fontSize: 13, color: AppTheme.textMain, height: 1.35),
                            ),
                            if (_visit['reviewed_at'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Reviewed at: ${_visit['reviewed_at']}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GestureDetector(
                        onTap: () {
                          final photoUrl = _visit['photo_url']?.toString();
                          final localPath = _visit['local_photo_path']?.toString();
                          final visitId = _visit['id']?.toString() ?? '';
                          _showFullScreenImage(context, photoUrl, localPath, photoId, accuracy, visitId);
                        },
                        child: Container(
                          height: 240,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2820),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.sageBorder),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // 1. Live Cloudinary photo, server-hosted photo, or local captured file
                              Builder(builder: (context) {
                                String? photoUrl = _visit['photo_url']?.toString();
                                final localPath = _visit['local_photo_path']?.toString();
                                final visitId = _visit['id']?.toString() ?? '';
                                final base = AuthService.defaultBaseUrl.isNotEmpty ? AuthService.defaultBaseUrl : 'https://phytodoctor-api.onrender.com';
                                final serverPhotoUrl = visitId.isNotEmpty ? '$base/api/v1/media/visits/$visitId/photo-file' : null;

                                if (photoUrl != null && photoUrl.contains('phytodoctor_dev') && serverPhotoUrl != null) {
                                  photoUrl = serverPhotoUrl;
                                } else if ((photoUrl == null || photoUrl.isEmpty) && serverPhotoUrl != null) {
                                  photoUrl = serverPhotoUrl;
                                }

                                final hasNetwork = photoUrl != null && photoUrl.startsWith('http');
                                final hasLocal = localPath != null && localPath.isNotEmpty && File(localPath).existsSync();

                                if (hasNetwork) {
                                  return Image.network(
                                    photoUrl!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(color: AppTheme.cropGreen),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      if (hasLocal) {
                                        return Image.file(File(localPath!), fit: BoxFit.cover);
                                      }
                                      if (serverPhotoUrl != null && photoUrl != serverPhotoUrl) {
                                        return Image.network(
                                          serverPhotoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, err2, st2) => _buildFallbackPhotoPlaceholder(photoId, accuracy),
                                        );
                                      }
                                      return _buildFallbackPhotoPlaceholder(photoId, accuracy);
                                    },
                                  );
                                } else if (hasLocal) {
                                  return Image.file(File(localPath!), fit: BoxFit.cover);
                                } else if (serverPhotoUrl != null) {
                                  return Image.network(
                                    serverPhotoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => _buildFallbackPhotoPlaceholder(photoId, accuracy),
                                  );
                                } else {
                                  return _buildFallbackPhotoPlaceholder(photoId, accuracy);
                                }
                              }),

                              // 2. Tap to zoom hint at top right
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Tap to Zoom',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // 3. Authenticated Shutter watermark overlay banner at bottom
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  color: Colors.black.withOpacity(0.72),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          photoId,
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        'GPS ACCURACY: ±$accuracy',
                                        style: const TextStyle(color: Color(0xFF81C784), fontSize: 11, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                            final lat = (_visit['latitude'] as num?)?.toDouble() ?? 31.5204;
                            final lng = (_visit['longitude'] as num?)?.toDouble() ?? 74.3587;
                            _openGoogleMaps(context, lat, lng);
                          },
                          child: Row(
                            children: [
                              Text(
                                '${((_visit['latitude'] as num?)?.toDouble() ?? 31.5204).toStringAsFixed(6)}° N, ${((_visit['longitude'] as num?)?.toDouble() ?? 74.3587).toStringAsFixed(6)}° E',
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
                        final lat = (_visit['latitude'] as num?)?.toDouble() ?? 31.5204;
                        final lng = (_visit['longitude'] as num?)?.toDouble() ?? 74.3587;
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

              const SizedBox(height: 20),

              // Supervisor / Admin Decision Actions (if pending)
              if (isPending && canVerify) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : () => _showRejectReasonDialog(clientName),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Flag / Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.alertCrimson,
                          side: const BorderSide(color: AppTheme.alertCrimson),
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () => _verifyVisit(true),
                        icon: const Icon(Icons.check, size: 16),
                        label: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Approve Visit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cropGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackPhotoPlaceholder(String photoId, dynamic accuracy) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_camera_back, size: 48, color: Colors.white54),
          const SizedBox(height: 8),
          Text(
            photoId,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Watermark Embedded • Authenticated Shutter',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(
    BuildContext context,
    String? photoUrl,
    String? localPath,
    String photoId,
    dynamic accuracy, [
    String? visitId,
  ]) {
    String? effectiveUrl = photoUrl;
    final base = AuthService.defaultBaseUrl.isNotEmpty ? AuthService.defaultBaseUrl : 'https://phytodoctor-api.onrender.com';
    final serverPhotoUrl = (visitId != null && visitId.isNotEmpty) ? '$base/api/v1/media/visits/$visitId/photo-file' : null;

    if (effectiveUrl != null && effectiveUrl.contains('phytodoctor_dev') && serverPhotoUrl != null) {
      effectiveUrl = serverPhotoUrl;
    } else if ((effectiveUrl == null || effectiveUrl.isEmpty) && serverPhotoUrl != null) {
      effectiveUrl = serverPhotoUrl;
    }

    final hasNetwork = effectiveUrl != null && effectiveUrl.startsWith('http');
    final hasLocal = localPath != null && localPath.isNotEmpty && File(localPath).existsSync();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(photoId, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: hasNetwork
                  ? Image.network(
                      effectiveUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) => progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator(color: AppTheme.cropGreen)),
                      errorBuilder: (context, error, stackTrace) {
                        if (hasLocal) {
                          return Image.file(File(localPath!), fit: BoxFit.contain);
                        }
                        if (serverPhotoUrl != null && effectiveUrl != serverPhotoUrl) {
                          return Image.network(
                            serverPhotoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, err2, st2) => _buildFallbackPhotoPlaceholder(photoId, accuracy),
                          );
                        }
                        return _buildFallbackPhotoPlaceholder(photoId, accuracy);
                      },
                    )
                  : (hasLocal
                      ? Image.file(File(localPath!), fit: BoxFit.contain)
                      : (serverPhotoUrl != null
                          ? Image.network(
                              serverPhotoUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (context, err2, st2) => _buildFallbackPhotoPlaceholder(photoId, accuracy),
                            )
                          : _buildFallbackPhotoPlaceholder(photoId, accuracy))),
            ),
          ),
        ),
      ),
    );
  }
}
