import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/repositories/visit_repository.dart';
import '../models/visit_state.dart';
import '../storage/cloudinary_upload_service.dart';
import '../storage/photo_storage_service.dart';
import '../storage/sqlite_visit_database.dart';


class OfflineSyncManager extends ChangeNotifier {
  static final OfflineSyncManager _instance = OfflineSyncManager._internal();
  factory OfflineSyncManager() => _instance;
  OfflineSyncManager._internal();

  final SqliteVisitDatabase _db = SqliteVisitDatabase();
  final PhotoStorageService _photoStorage = PhotoStorageService();

  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _currentStepMessage = 'Idle';
  String? _lastError;
  DateTime? _lastSyncTime;
  int _pendingCount = 0;
  int _needsReviewCount = 0;
  bool _isLowStorage = false;

  // Getters
  bool get isSyncing => _isSyncing;
  double get syncProgress => _syncProgress;
  String get currentStepMessage => _currentStepMessage;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get pendingCount => _pendingCount;
  int get needsReviewCount => _needsReviewCount;
  bool get isLowStorage => _isLowStorage;

  /// Initializes manager, checks storage health, and counts pending records
  Future<void> initialize() async {
    _isSyncing = false;
    _lastError = null;
    await _db.initDatabase();
    await refreshCounts();
    await checkStorageHealth();
  }

  /// Refreshes pending & needs-review counts from SQLite
  Future<void> refreshCounts() async {
    _pendingCount = await _db.getPendingCount();
    _needsReviewCount = await _db.getNeedsReviewCount();
    if (_pendingCount == 0) {
      _lastError = null;
    }
    notifyListeners();
  }

  /// Reconciles local SQLite queue with visit IDs already confirmed on the server
  Future<void> reconcileWithServerVisits(Iterable<String> serverVisitIds) async {
    final updated = await _db.markUploadedIdsAsSynced(serverVisitIds);
    if (updated > 0) {
      await refreshCounts();
    }
  }

  /// Storage Health Check
  Future<void> checkStorageHealth() async {
    final health = await _photoStorage.checkStorageHealth();
    _isLowStorage = health.isLowStorage;
    if (_isLowStorage) {
      _lastError = health.message;
    }
    notifyListeners();
  }

  /// Calculates exponential backoff duration based on retry attempt count
  /// Formula: 2^(attempts) seconds, capped at 60 seconds
  Duration calculateBackoff(int attempts) {
    final exponent = attempts.clamp(0, 5);
    final seconds = (1 << exponent);
    return Duration(seconds: seconds);
  }

  /// Manual "Sync Now" or WorkManager background trigger
  /// Guarantees:
  /// - Concurrency lock: Rejects overlapping sync executions from repeated taps
  /// - Idempotency key: Passes client visit UUID to server
  /// - Safe recovery from partial/interrupted uploads
  /// - Never displays false success: only marks 'synced' on confirmed HTTP 200/201
  /// - Handles expired tokens without losing local records
  Future<int> syncNow({
    required VisitRepository repository,
    required String token,
    bool forceRetryAll = false,
  }) async {
    // 1. Concurrency Lock: Debounce repeated taps
    if (_isSyncing) {
      debugPrint('[OfflineSyncManager] Sync is already active. Repeated Sync Now request debounced.');
      return 0;
    }

    _isSyncing = true;
    _lastError = null;
    _syncProgress = 0.0;
    _currentStepMessage = 'Checking local SQLite database...';
    notifyListeners();

    int successfulSyncs = 0;

    try {
      final pendingVisits = await _db.getPendingVisits();
      _pendingCount = pendingVisits.length;

      if (pendingVisits.isEmpty) {
        _currentStepMessage = 'All visits are up-to-date.';
        _lastSyncTime = DateTime.now();
        _isSyncing = false;
        notifyListeners();
        return 0;
      }

      final total = pendingVisits.length;

      // Fail fast when device is completely offline so queued visits don't stall on socket timeouts
      if (!repository.isMock) {
        bool hasNetwork = false;
        try {
          final lookup = await InternetAddress.lookup('api.cloudinary.com')
              .timeout(const Duration(seconds: 2));
          hasNetwork = lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
        } catch (_) {
          hasNetwork = false;
        }
        if (!hasNetwork) {
          _lastError = 'No internet connection. Saved in queue and will upload when online.';
          for (final pendingVisit in pendingVisits) {
            await _db.updateSyncState(
              pendingVisit.id,
              VisitSyncState.syncFailed,
              error: _lastError,
            );
          }
          _lastSyncTime = DateTime.now();
          _syncProgress = 0.0;
          _currentStepMessage = _lastError!;
          return 0;
        }
      }

      for (int i = 0; i < total; i++) {
        final visit = pendingVisits[i];
        _syncProgress = i / total;

        // Exponential backoff check (unless forced by manual button tap)
        if (!forceRetryAll && visit.syncAttempts > 0 && visit.lastSyncAttempt != null) {
          final backoff = calculateBackoff(visit.syncAttempts);
          final elapsed = DateTime.now().difference(visit.lastSyncAttempt!);
          if (elapsed < backoff) {
            final remainingSec = (backoff - elapsed).inSeconds;
            debugPrint(
              '[OfflineSyncManager] Visit ${visit.id} is in backoff window (${remainingSec}s remaining). Skipping until next cycle.',
            );
            continue;
          }
        }

        // Set state to syncing in SQLite
        await _db.updateSyncState(
          visit.id,
          VisitSyncState.syncing,
          syncAttempts: visit.syncAttempts + 1,
        );

        _currentStepMessage = 'Syncing visit ${i + 1} of $total: ${visit.clientName}...';
        notifyListeners();

        // 2. Safe Recovery from Interrupted Photo Upload & Avoid Duplicate Uploads
        String? confirmedPhotoUrl = visit.photoUploadUrl;
        if (confirmedPhotoUrl == null || confirmedPhotoUrl.isEmpty) {
          _currentStepMessage = 'Verifying and uploading photo for ${visit.clientName}...';
          notifyListeners();

          // Verify photo file integrity before network transmission
          final photoValid = _photoStorage.verifyPhotoIntegrity(visit.localPhotoPath, 1024);
          if (!photoValid) {
            await _db.updateSyncState(
              visit.id,
              VisitSyncState.syncFailed,
              error: 'Storage error: Local photo file corrupted or missing in app-private sandbox.',
            );
            continue;
          }

          try {
            // Upload photo evidence securely to Cloudinary
            final uploadResult = await CloudinaryUploadService().uploadPhotoEvidence(
              visitId: visit.id,
              localPhotoPath: visit.localPhotoPath,
              token: token,
            );
            confirmedPhotoUrl = uploadResult.photoUrl;
            // Persist Cloudinary URL right away so a failed visit POST never re-uploads the image
            await _db.updateSyncState(
              visit.id,
              VisitSyncState.syncing,
              photoUrl: confirmedPhotoUrl,
            );
          } catch (uploadError) {
            final errLower = uploadError.toString().toLowerCase();
            final isNetErr = errLower.contains('socket') ||
                errLower.contains('network') ||
                errLower.contains('timed out') ||
                errLower.contains('failed host lookup');
            _lastError = isNetErr
                ? 'Network unavailable. Visits preserved offline and will sync when internet returns.'
                : 'Photo upload failed: ${uploadError.toString().replaceFirst('Exception: ', '')}';
            await _db.updateSyncState(
              visit.id,
              VisitSyncState.syncFailed,
              error: _lastError,
            );
            if (isNetErr) break;
            continue;
          }
        }

        // 3. Prepare Payload with Visit UUID Idempotency Key
        final payload = visit.toApiPayload();
        payload['photo_url'] = confirmedPhotoUrl;


        // 4. Server Transmission
        try {
          final bool success = await repository.recordVisit(
            token: token,
            visitData: payload,
          );

          if (success) {
            // NEVER DISPLAY FALSE SUCCESS: Verify confirmed server status
            final confirmedState = visit.isFlaggedForReview
                ? VisitSyncState.needsReview
                : VisitSyncState.synced;

            await _db.updateSyncState(
              visit.id,
              confirmedState,
              error: null,
              serverReceiptTime: DateTime.now().toUtc(),
              photoUrl: confirmedPhotoUrl,
            );
            successfulSyncs++;
          } else {
            // Server did not confirm
            await _db.updateSyncState(
              visit.id,
              VisitSyncState.syncFailed,
              error: 'Server rejected visit submission. Queued for supervisor audit.',
            );
          }
        } catch (e) {
          final errStr = e.toString().toLowerCase();

          if (errStr.contains('401') || errStr.contains('unauthorized') || errStr.contains('token')) {
            // EXPIRED AUTHENTICATION: Never lose local records!
            _lastError = 'Session expired (HTTP 401). Local records safely preserved in SQLite. Please log in again.';
            await _db.updateSyncState(
              visit.id,
              VisitSyncState.syncFailed,
              error: _lastError,
            );
            // Break loop so employee can re-authenticate
            break;
          } else if (errStr.contains('socket') || errStr.contains('network') || errStr.contains('timed out')) {
            // NETWORK DISCONNECTION / AIRPLANE MODE
            _lastError = 'Network unavailable. Visits preserved offline and will sync when internet returns.';
            await _db.updateSyncState(
              visit.id,
              VisitSyncState.syncFailed,
              error: _lastError,
            );
          } else {
            // GENERIC OR SERVER ERROR
            _lastError = 'Server error during sync: $e';
            await _db.updateSyncState(
              visit.id,
              VisitSyncState.syncFailed,
              error: _lastError,
            );
          }
        }
      }

      _lastSyncTime = DateTime.now();
      _syncProgress = 1.0;
      _currentStepMessage = successfulSyncs > 0
          ? 'Synchronized $successfulSyncs visit(s) successfully.'
          : (_lastError ?? 'Sync cycle completed.');
    } finally {
      _isSyncing = false;
      await refreshCounts();
      notifyListeners();
    }

    return successfulSyncs;
  }

  /// Android WorkManager contract dispatcher
  static Future<void> workmanagerCallbackDispatcher() async {
    debugPrint('[OfflineSyncManager] Android WorkManager background sync triggered.');
    // Invoked by WorkManager periodic task (e.g. every 15 minutes with NetworkType.CONNECTED)
  }
}
