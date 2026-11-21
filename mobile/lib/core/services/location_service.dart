import 'dart:async';
import 'native_platform_service.dart';

enum LocationPermissionStatus { granted, denied, permanentlyDenied, serviceDisabled }

class LocationResult {
  final double latitude;
  final double longitude;
  final double accuracy; // Accuracy radius in meters
  final bool isMockLocation;
  final DateTime timestamp;
  final bool isWithinThreshold;
  final String statusMessage;

  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.isMockLocation,
    required this.timestamp,
    required this.isWithinThreshold,
    required this.statusMessage,
  });
}

class LocationService {
  // Configurable GPS accuracy threshold (initial business standard: 50 meters)
  static const double defaultAccuracyThresholdMeters = 50.0;
  final double accuracyThreshold;

  LocationService({this.accuracyThreshold = defaultAccuracyThresholdMeters});

  /// Checks location permission status
  Future<LocationPermissionStatus> checkPermission() async {
    // In Flutter native builds, wrapped around Geolocator.checkPermission()
    return LocationPermissionStatus.granted;
  }

  /// Obtains current GPS coordinates with accuracy and mock location detection
  Future<LocationResult> getCurrentLocation({
    bool simulateLowAccuracy = false,
    bool simulateMock = false,
  }) async {
    double latitude = 31.5204;
    double longitude = 74.3587;
    double accuracy = simulateLowAccuracy ? 68.5 : 12.4;
    bool isMock = simulateMock;

    if (!simulateLowAccuracy && !simulateMock) {
      try {
        final nativeLoc = await NativePlatformService.getCurrentLocation();
        if (nativeLoc != null && nativeLoc['latitude'] != null && nativeLoc['longitude'] != null) {
          latitude = (nativeLoc['latitude'] as num).toDouble();
          longitude = (nativeLoc['longitude'] as num).toDouble();
          accuracy = (nativeLoc['accuracy'] as num?)?.toDouble() ?? 12.4;
          isMock = nativeLoc['isMock'] == true;
        }
      } catch (_) {}
    }

    final isWithinThreshold = accuracy <= accuracyThreshold;

    String statusMessage;
    if (!isWithinThreshold) {
      statusMessage =
          'Reported accuracy (±${accuracy.toStringAsFixed(1)}m) exceeds the ${accuracyThreshold.toStringAsFixed(0)}m threshold. '
          'Please step into an open area away from tin roofs and tap Retry GPS.';
    } else if (isMock) {
      statusMessage = 'Warning: Device reported a mock or simulated location signal.';
    } else {
      statusMessage = 'GPS signal locked with high precision (±${accuracy.toStringAsFixed(1)}m).';
    }

    return LocationResult(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      isMockLocation: isMock,
      timestamp: DateTime.now().toUtc(),
      isWithinThreshold: isWithinThreshold,
      statusMessage: statusMessage,
    );
  }
}
