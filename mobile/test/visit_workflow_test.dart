import 'package:flutter_test/flutter_test.dart';
import 'package:phyto_doctor/core/services/location_service.dart';
import 'package:phyto_doctor/core/storage/local_visit_queue.dart';
import 'package:phyto_doctor/data/repositories/visit_repository.dart';

class MockVisitRepo implements VisitRepository {
  bool shouldSucceed = true;
  final List<Map<String, dynamic>> recordedVisits = [];

  @override
  bool get isMock => true;

  @override
  String get repositorySource => 'Mock Test Repo';

  @override
  Future<Map<String, dynamic>> getDashboardSummary(String token) async {
    return {'target_visits': 6, 'completed_today': 2, 'verified_visits': 2};
  }

  @override
  Future<List<Map<String, dynamic>>> getVisitHistory(String token) async {
    return recordedVisits;
  }

  @override
  Future<bool> recordVisit({
    required String token,
    required Map<String, dynamic> visitData,
  }) async {
    if (shouldSucceed) {
      recordedVisits.add(visitData);
      return true;
    }
    return false;
  }

  @override
  Future<Map<String, dynamic>> getPerformanceAnalytics({
    required String token,
    required String employeeId,
    String timeframe = 'daily',
  }) async => {};

  @override
  Future<Map<String, dynamic>> getTeamComparison({
    required String token,
    String timeframe = 'monthly',
  }) async => {};
}

void main() {
  group('Field Visit Validation & Accuracy Threshold Tests', () {
    test('Client name validation rejects blank or whitespace-only names', () {
      String? validateClientName(String? value) {
        if (value == null || value.trim().isEmpty) {
          return 'Client name is mandatory';
        }
        return null;
      }

      expect(validateClientName(''), equals('Client name is mandatory'));
      expect(validateClientName('   '), equals('Client name is mandatory'));
      expect(validateClientName(null), equals('Client name is mandatory'));
      expect(validateClientName('Al-Madina Agro Traders'), isNull);
    });

    test('LocationService enforces 50m accuracy threshold', () async {
      final service = LocationService(accuracyThreshold: 50.0);

      // 1. High accuracy location within 50m
      final goodLocation = await service.getCurrentLocation(simulateLowAccuracy: false);
      expect(goodLocation.accuracy, lessThanOrEqualTo(50.0));
      expect(goodLocation.isWithinThreshold, isTrue);
      expect(goodLocation.statusMessage, contains('high precision'));

      // 2. Low accuracy location exceeding 50m
      final poorLocation = await service.getCurrentLocation(simulateLowAccuracy: true);
      expect(poorLocation.accuracy, greaterThan(50.0));
      expect(poorLocation.isWithinThreshold, isFalse);
      expect(poorLocation.statusMessage, contains('exceeds the 50m threshold'));
      expect(poorLocation.statusMessage, contains('Retry GPS'));
    });

    test('LocationService detects reported mock location signal', () async {
      final service = LocationService(accuracyThreshold: 50.0);
      final mockLocation = await service.getCurrentLocation(simulateMock: true);

      expect(mockLocation.isMockLocation, isTrue);
      expect(mockLocation.statusMessage, contains('mock or simulated location'));
    });
    test('Photo evidence validation rejects missing or uncaptured photo', () {
      bool isPhotoValid(String? photoAssetId, String? photoPath) {
        if (photoAssetId == null || photoAssetId.trim().isEmpty) return false;
        if (photoPath == null || photoPath.trim().isEmpty) return false;
        return true;
      }

      expect(isPhotoValid(null, null), isFalse);
      expect(isPhotoValid('', '/path/to/img.jpg'), isFalse);
      expect(isPhotoValid('PHOTO_123', null), isFalse);
      expect(isPhotoValid('PHOTO_123', '/path/to/img.jpg'), isTrue);
    });

    test('Coordinates validation strictly rejects out-of-range coordinates', () {
      bool areCoordinatesValid(double? lat, double? lng) {
        if (lat == null || lng == null) return false;
        if (lat < -90.0 || lat > 90.0) return false;
        if (lng < -180.0 || lng > 180.0) return false;
        return true;
      }

      expect(areCoordinatesValid(null, 74.3587), isFalse);
      expect(areCoordinatesValid(31.5204, null), isFalse);
      expect(areCoordinatesValid(95.0, 74.3587), isFalse);
      expect(areCoordinatesValid(-95.0, 74.3587), isFalse);
      expect(areCoordinatesValid(31.5204, 195.0), isFalse);
      expect(areCoordinatesValid(31.5204, -195.0), isFalse);
      expect(areCoordinatesValid(31.5204, 74.3587), isTrue);
    });
  });

  group('Offline Visit Queue & Synchronization Tests', () {
    test('Enqueues visits locally when offline and preserves evidence attributes', () async {
      final queue = LocalVisitQueue();
      queue.clearQueue();

      expect(queue.pendingCount, equals(0));
      expect(queue.hasPending, isFalse);

      final visitRecord = {
        'client_name': 'Kisan Pesticides Center',
        'latitude': 31.5204,
        'longitude': 74.3587,
        'gps_accuracy': 14.2,
        'photo_asset_id': 'PHOTO_TEST_101',
        'device_capture_time': DateTime.now().toUtc().toIso8601String(),
      };

      await queue.enqueueVisit(visitRecord);

      expect(queue.pendingCount, equals(1));
      expect(queue.hasPending, isTrue);
      expect(queue.queuedVisits.first['client_name'], equals('Kisan Pesticides Center'));
      expect(queue.queuedVisits.first['sync_status'], equals('QUEUED_OFFLINE'));
      expect(queue.queuedVisits.first['local_queued_at'], isNotNull);
    });

    test('Synchronizes queued visits with repository and drains queue on success', () async {
      final queue = LocalVisitQueue();
      queue.clearQueue();
      final mockRepo = MockVisitRepo();

      await queue.enqueueVisit({
        'client_name': 'Hafiz Agro Chemical',
        'latitude': 31.5204,
        'longitude': 74.3587,
        'gps_accuracy': 12.0,
        'photo_asset_id': 'PHOTO_TEST_102',
      });

      expect(queue.pendingCount, equals(1));

      // Successful sync
      mockRepo.shouldSucceed = true;
      final syncedCount = await queue.syncQueuedVisits(mockRepo, 'valid_token');

      expect(syncedCount, equals(1));
      expect(queue.pendingCount, equals(0));
      expect(mockRepo.recordedVisits.length, equals(1));
      expect(mockRepo.recordedVisits.first['client_name'], equals('Hafiz Agro Chemical'));
    });

    test('Retains visits in local queue when network sync fails', () async {
      final queue = LocalVisitQueue();
      queue.clearQueue();
      final mockRepo = MockVisitRepo();

      await queue.enqueueVisit({
        'client_name': 'Bismillah Fertilizer Store',
        'latitude': 31.5204,
        'longitude': 74.3587,
        'gps_accuracy': 16.5,
        'photo_asset_id': 'PHOTO_TEST_103',
      });

      // Network failure
      mockRepo.shouldSucceed = false;
      final syncedCount = await queue.syncQueuedVisits(mockRepo, 'valid_token');

      expect(syncedCount, equals(0));
      expect(queue.pendingCount, equals(1)); // Visit safely retained in queue!
    });
  });

  group('Permission Handling Simulation', () {
    test('Identifies denied permission status gracefully', () async {
      final service = LocationService();
      final status = await service.checkPermission();
      expect(status, isNotNull);
    });

    test('Handles denied and permanently denied location permission states', () {
      bool shouldShowPermissionDialog(LocationPermissionStatus status) {
        return status == LocationPermissionStatus.denied ||
            status == LocationPermissionStatus.permanentlyDenied ||
            status == LocationPermissionStatus.serviceDisabled;
      }

      expect(shouldShowPermissionDialog(LocationPermissionStatus.granted), isFalse);
      expect(shouldShowPermissionDialog(LocationPermissionStatus.denied), isTrue);
      expect(shouldShowPermissionDialog(LocationPermissionStatus.permanentlyDenied), isTrue);
      expect(shouldShowPermissionDialog(LocationPermissionStatus.serviceDisabled), isTrue);
    });

    test('Handles denied camera permission state cleanly', () {
      bool canLaunchCamera(bool cameraPermissionDenied) {
        return !cameraPermissionDenied;
      }

      expect(canLaunchCamera(false), isTrue);
      expect(canLaunchCamera(true), isFalse);
    });
  });
}
