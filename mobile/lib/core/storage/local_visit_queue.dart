import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../data/repositories/visit_repository.dart';
import '../models/local_visit_model.dart';
import '../models/visit_state.dart';
import '../sync/offline_sync_manager.dart';
import 'sqlite_visit_database.dart';

class LocalVisitQueue extends ChangeNotifier {
  static final LocalVisitQueue _instance = LocalVisitQueue._internal();
  factory LocalVisitQueue() => _instance;
  LocalVisitQueue._internal();

  final SqliteVisitDatabase _db = SqliteVisitDatabase();
  final List<Map<String, dynamic>> _queue = [];

  List<Map<String, dynamic>> get queuedVisits => List.unmodifiable(_queue);
  int get pendingCount => _queue.length;
  bool get hasPending => _queue.isNotEmpty;

  /// Enqueues a visit locally into SQLite immediately upon creation
  Future<void> enqueueVisit(Map<String, dynamic> visit) async {
    final visitRecord = Map<String, dynamic>.from(visit);
    final visitId = (visitRecord['id'] as String?) ??
        'VISIT_${DateTime.now().millisecondsSinceEpoch}_${(visitRecord['client_name'] as String? ?? 'CLIENT').hashCode.abs()}';
    visitRecord['id'] = visitId;
    visitRecord['local_queued_at'] = DateTime.now().toUtc().toIso8601String();
    visitRecord['sync_status'] = 'QUEUED_OFFLINE';

    // Insert into SQLite database for cross-restart preservation
    final localModel = LocalVisitModel(
      id: visitId,
      employeeId: (visitRecord['employee_id'] as String?) ?? '',
      clientName: (visitRecord['client_name'] as String?) ?? 'Unknown Client',
      clientPhone: visitRecord['client_phone'] as String?,
      clientType: (visitRecord['client_type'] as String?) ?? 'DEALER',
      visitPurpose: (visitRecord['visit_purpose'] as String?) ?? 'PRODUCT_PITCH',
      notes: visitRecord['notes'] as String?,
      latitude: (visitRecord['latitude'] as num?)?.toDouble() ?? 31.5204,
      longitude: (visitRecord['longitude'] as num?)?.toDouble() ?? 74.3587,
      gpsAccuracy: (visitRecord['gps_accuracy'] as num?)?.toDouble() ?? 12.4,
      isMockLocation: visitRecord['is_mock_location'] == true,
      deviceCaptureTime: visitRecord['device_capture_time'] != null
          ? DateTime.parse(visitRecord['device_capture_time'] as String)
          : DateTime.now().toUtc(),
      localPhotoPath: (visitRecord['local_photo_path'] as String?) ?? (visitRecord['photo_asset_id'] as String? ?? 'photo.jpg'),
      photoAssetId: (visitRecord['photo_asset_id'] as String?) ?? 'ASSET_${DateTime.now().millisecondsSinceEpoch}',
      photoUploadUrl: visitRecord['photo_url'] as String?,
      syncState: VisitSyncState.pendingSync,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    await _db.insertVisit(localModel);

    _queue.add(visitRecord);
    await OfflineSyncManager().refreshCounts();
    notifyListeners();
  }

  /// Synchronizes all locally queued visits with the backend server
  Future<int> syncQueuedVisits(VisitRepository repository, String token) async {
    if (_queue.isEmpty) return 0;

    int syncedCount = 0;
    final List<Map<String, dynamic>> remainingQueue = [];

    for (final visit in _queue) {
      try {
        final success = await repository.recordVisit(
          token: token,
          visitData: visit,
        );

        if (success) {
          syncedCount++;
          final id = visit['id'] as String?;
          if (id != null) {
            await _db.updateSyncState(id, VisitSyncState.synced);
          }
        } else {
          remainingQueue.add(visit);
          final id = visit['id'] as String?;
          if (id != null) {
            await _db.updateSyncState(id, VisitSyncState.syncFailed, error: 'Server rejected submission');
          }
        }
      } catch (e) {
        remainingQueue.add(visit);
        final id = visit['id'] as String?;
        if (id != null) {
          await _db.updateSyncState(id, VisitSyncState.syncFailed, error: e.toString());
        }
      }
    }

    _queue.clear();
    _queue.addAll(remainingQueue);
    await OfflineSyncManager().refreshCounts();
    notifyListeners();
    return syncedCount;
  }

  void clearQueue() {
    _queue.clear();
    notifyListeners();
  }
}
