import 'package:flutter_test/flutter_test.dart';
import 'package:phyto_doctor/core/models/local_visit_model.dart';
import 'package:phyto_doctor/core/models/visit_state.dart';
import 'package:phyto_doctor/core/storage/photo_storage_service.dart';
import 'package:phyto_doctor/core/storage/sqlite_visit_database.dart';
import 'package:phyto_doctor/core/sync/offline_sync_manager.dart';
import 'package:phyto_doctor/data/repositories/visit_repository.dart';

class MockOfflineVisitRepo implements VisitRepository {
  bool simulateOffline = false;
  bool simulateAuthExpired = false;
  bool simulateServerFailure = false;
  int networkCallCount = 0;
  final List<Map<String, dynamic>> serverReceivedVisits = [];

  @override
  bool get isMock => true;

  @override
  String get repositorySource => 'Mock Offline Test Repo';

  @override
  Future<Map<String, dynamic>> getDashboardSummary(String token) async {
    return {'target_visits': 6, 'completed_today': 0, 'verified_visits': 0};
  }

  @override
  Future<List<Map<String, dynamic>>> getVisitHistory(String token) async {
    return serverReceivedVisits;
  }

  @override
  Future<bool> recordVisit({
    required String token,
    required Map<String, dynamic> visitData,
  }) async {
    networkCallCount++;

    if (simulateAuthExpired) {
      throw Exception('HTTP 401 Unauthorized: Session token expired');
    }

    if (simulateOffline) {
      throw Exception('SocketException: Failed host lookup - Airplane mode active');
    }

    if (simulateServerFailure) {
      throw Exception('HTTP 503 Service Unavailable: Server busy');
    }

    serverReceivedVisits.add(visitData);
    return true;
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
  late SqliteVisitDatabase db;
  late OfflineSyncManager syncManager;
  late PhotoStorageService photoStorage;
  late MockOfflineVisitRepo mockRepo;

  setUp(() async {
    db = SqliteVisitDatabase();
    await db.clearAll();
    await db.initDatabase();

    syncManager = OfflineSyncManager();
    photoStorage = PhotoStorageService();
    mockRepo = MockOfflineVisitRepo();
  });

  group('Offline-First Synchronization Scenarios', () {
    test('1. Airplane Mode: Visit saved locally in SQLite, pending count increments, no false success', () async {
      mockRepo.simulateOffline = true;

      final visit = LocalVisitModel(
        id: 'UUID-AIRPLANE-001',
        employeeId: 'emp-101',
        clientName: 'Rehman Agro Supplies',
        clientType: 'DEALER',
        visitPurpose: 'PRODUCT_PITCH',
        latitude: 31.5204,
        longitude: 74.3587,
        gpsAccuracy: 12.0,
        isMockLocation: false,
        deviceCaptureTime: DateTime.now().toUtc(),
        localPhotoPath: '/data/user/0/com.phytodoctor/private_evidence/photo_1.jpg',
        photoAssetId: 'PHOTO_AIRPLANE_1',
        syncState: VisitSyncState.pendingSync,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      // Save visit locally immediately
      await db.insertVisit(visit);
      expect(await db.getPendingCount(), equals(1));

      // Attempt sync while in airplane mode
      final synced = await syncManager.syncNow(
        repository: mockRepo,
        token: 'test_token',
        forceRetryAll: true,
      );

      // Verify no false success
      expect(synced, equals(0));
      expect(await db.getPendingCount(), equals(1));

      // Verify visit is marked syncFailed in SQLite with explanatory error message
      final stored = await db.getVisitById('UUID-AIRPLANE-001');
      expect(stored, isNotNull);
      expect(stored!.syncState, equals(VisitSyncState.syncFailed));
      expect(stored.syncError, contains('Network unavailable'));
    });

    test('2. App Termination During Upload: Stuck syncing state is recovered on SQLite restart', () async {
      // Simulate visit that was in-flight when Android killed the app
      final inFlightVisit = LocalVisitModel(
        id: 'UUID-TERMINATED-002',
        employeeId: 'emp-101',
        clientName: 'Haseeb Seed Store',
        clientType: 'DEALER',
        visitPurpose: 'PRODUCT_PITCH',
        latitude: 31.5204,
        longitude: 74.3587,
        gpsAccuracy: 14.0,
        isMockLocation: false,
        deviceCaptureTime: DateTime.now().toUtc(),
        localPhotoPath: '/data/user/0/com.phytodoctor/private_evidence/photo_2.jpg',
        photoAssetId: 'PHOTO_TERMINATED_2',
        syncState: VisitSyncState.syncing, // Stuck in syncing!
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await db.insertVisit(inFlightVisit);

      // On app cold launch, initDatabase resets orphaned 'syncing' records to 'pendingSync'
      final recoveredCount = await db.resetStaleSyncingStates();
      expect(recoveredCount, equals(1));

      final recovered = await db.getVisitById('UUID-TERMINATED-002');
      expect(recovered!.syncState, equals(VisitSyncState.pendingSync));
      expect(recovered.syncError, contains('interrupted by app termination'));
    });

    test('3. Network Disconnection During Photo Upload: Backoff calculation & retry preservation', () async {
      // Test exponential backoff calculation: 2^attempts seconds
      expect(syncManager.calculateBackoff(0), equals(const Duration(seconds: 1)));
      expect(syncManager.calculateBackoff(1), equals(const Duration(seconds: 2)));
      expect(syncManager.calculateBackoff(2), equals(const Duration(seconds: 4)));
      expect(syncManager.calculateBackoff(3), equals(const Duration(seconds: 8)));
      expect(syncManager.calculateBackoff(4), equals(const Duration(seconds: 16)));
      expect(syncManager.calculateBackoff(5), equals(const Duration(seconds: 32)));

      // Partial photo verification test
      final isIntact = photoStorage.verifyPhotoIntegrity('/path/to/valid_photo.jpg', 2048);
      expect(isIntact, isTrue);

      final isCorrupted = photoStorage.verifyPhotoIntegrity('/path/to/empty.jpg', 0);
      expect(isCorrupted, isFalse);
    });

    test('4. Repeated Sync Now Actions: Concurrency lock debounces rapid taps', () async {
      final visit = LocalVisitModel(
        id: 'UUID-CONCURRENCY-004',
        employeeId: 'emp-101',
        clientName: 'Punjab Pesticide House',
        clientType: 'DEALER',
        visitPurpose: 'PRODUCT_PITCH',
        latitude: 31.5204,
        longitude: 74.3587,
        gpsAccuracy: 10.0,
        isMockLocation: false,
        deviceCaptureTime: DateTime.now().toUtc(),
        localPhotoPath: '/data/user/0/com.phytodoctor/private_evidence/photo_4.jpg',
        photoAssetId: 'PHOTO_CONCURRENCY_4',
        syncState: VisitSyncState.pendingSync,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await db.insertVisit(visit);

      // Trigger two simultaneous sync calls
      final future1 = syncManager.syncNow(repository: mockRepo, token: 'valid_token');
      final future2 = syncManager.syncNow(repository: mockRepo, token: 'valid_token');

      final results = await Future.wait([future1, future2]);

      // Exactly one execution proceeded; the other was debounced by concurrency lock
      final totalSynced = results[0] + results[1];
      expect(totalSynced, equals(1));
      expect(mockRepo.networkCallCount, equals(1)); // Only 1 HTTP call made!
    });

    test('5. Duplicate Requests & Retention: Never delete local records before confirmed upload', () async {
      final visit = LocalVisitModel(
        id: 'UUID-RETENTION-005',
        employeeId: 'emp-101',
        clientName: 'Sadiq Brother Agro',
        clientType: 'DEALER',
        visitPurpose: 'PRODUCT_PITCH',
        latitude: 31.5204,
        longitude: 74.3587,
        gpsAccuracy: 11.5,
        isMockLocation: false,
        deviceCaptureTime: DateTime.now().toUtc(),
        localPhotoPath: '/data/user/0/com.phytodoctor/private_evidence/photo_5.jpg',
        photoAssetId: 'PHOTO_RETENTION_5',
        syncState: VisitSyncState.pendingSync,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await db.insertVisit(visit);

      // Attempt to delete unconfirmed visit -> MUST BE REJECTED!
      final deleted = await db.deleteVisit('UUID-RETENTION-005');
      expect(deleted, isFalse);

      // Verify still preserved in SQLite
      final retained = await db.getVisitById('UUID-RETENTION-005');
      expect(retained, isNotNull);

      // Verify photo pruning guard
      final canPruneUnsynced = photoStorage.canSafelyPrunePhoto(
        isConfirmedSynced: false,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      );
      expect(canPruneUnsynced, isFalse);
    });

    test('6. Expired Authentication: 401 Unauthorized preserves local SQLite records safely', () async {
      mockRepo.simulateAuthExpired = true;

      final visit = LocalVisitModel(
        id: 'UUID-AUTH-006',
        employeeId: 'emp-101',
        clientName: 'Tariq & Sons Bio Crop',
        clientType: 'DEALER',
        visitPurpose: 'PRODUCT_PITCH',
        latitude: 31.5204,
        longitude: 74.3587,
        gpsAccuracy: 12.0,
        isMockLocation: false,
        deviceCaptureTime: DateTime.now().toUtc(),
        localPhotoPath: '/data/user/0/com.phytodoctor/private_evidence/photo_6.jpg',
        photoAssetId: 'PHOTO_AUTH_6',
        syncState: VisitSyncState.pendingSync,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await db.insertVisit(visit);

      final synced = await syncManager.syncNow(
        repository: mockRepo,
        token: 'expired_token',
        forceRetryAll: true,
      );

      expect(synced, equals(0));
      expect(syncManager.lastError, contains('Session expired'));

      // CRITICAL CHECK: Local record MUST NOT be deleted or lost!
      final preserved = await db.getVisitById('UUID-AUTH-006');
      expect(preserved, isNotNull);
      expect(preserved!.syncState, equals(VisitSyncState.syncFailed));
      expect(preserved.syncError, contains('Session expired'));
    });

    test('7. Storage Health Warning: Identifies low device disk storage', () async {
      final health = await photoStorage.checkStorageHealth();
      expect(health.estimatedFreeMb, greaterThan(0));
      expect(health.message, isNotEmpty);
    });
  });
}
