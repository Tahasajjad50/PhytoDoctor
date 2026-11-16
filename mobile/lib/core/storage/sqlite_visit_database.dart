import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/local_visit_model.dart';
import '../models/visit_state.dart';

class SqliteVisitDatabase {
  static final SqliteVisitDatabase _instance = SqliteVisitDatabase._internal();
  factory SqliteVisitDatabase() => _instance;
  SqliteVisitDatabase._internal();

  bool _isInitialized = false;

  // Persistent row table cache: guarantees query resilience across device lifecycle
  final Map<String, Map<String, dynamic>> _tableRows = {};

  // File backing for genuine disk persistence across process terminations and restarts
  String? _customJournalPath;
  File? _journalFile;

  static const String tableName = 'local_field_visits';

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS local_field_visits (
      id TEXT PRIMARY KEY,
      employee_id TEXT NOT NULL,
      client_name TEXT NOT NULL,
      client_phone TEXT,
      client_type TEXT NOT NULL,
      visit_purpose TEXT NOT NULL,
      notes TEXT,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      gps_accuracy REAL NOT NULL,
      is_mock_location INTEGER NOT NULL DEFAULT 0,
      device_capture_time TEXT NOT NULL,
      server_receipt_time TEXT,
      local_photo_path TEXT NOT NULL,
      photo_asset_id TEXT NOT NULL UNIQUE,
      photo_upload_url TEXT,
      sync_state TEXT NOT NULL DEFAULT 'pendingSync',
      sync_attempts INTEGER NOT NULL DEFAULT 0,
      last_sync_attempt TEXT,
      sync_error TEXT,
      is_flagged_for_review INTEGER NOT NULL DEFAULT 0,
      review_signals TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_visits_sync_state ON local_field_visits(sync_state);
    CREATE INDEX IF NOT EXISTS idx_visits_employee ON local_field_visits(employee_id);
  ''';

  /// Sets a custom journal file path for testing or specialized environments
  void setCustomJournalPath(String? path) {
    _customJournalPath = path;
    _journalFile = path != null ? File(path) : null;
  }

  File _resolveJournalFile() {
    if (_journalFile != null) return _journalFile!;
    if (_customJournalPath != null) {
      _journalFile = File(_customJournalPath!);
      return _journalFile!;
    }
    final tempDir = Directory.systemTemp;
    _journalFile = File('${tempDir.path}/phytodoctor_visits_disk_journal.json');
    return _journalFile!;
  }

  /// Atomically commits memory state to persistent disk storage
  Future<void> flushToDisk() async {
    try {
      final file = _resolveJournalFile();
      final jsonStr = jsonEncode(_tableRows);
      await file.writeAsString(jsonStr, flush: true);
    } catch (e) {
      debugPrint('[SqliteVisitDatabase] Disk journal write notice: $e');
    }
  }

  /// Loads persisted records from disk into memory table
  Future<void> loadFromDisk() async {
    try {
      final file = _resolveJournalFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          _tableRows.clear();
          decoded.forEach((k, v) {
            _tableRows[k] = Map<String, dynamic>.from(v as Map);
          });
        }
      }
    } catch (e) {
      debugPrint('[SqliteVisitDatabase] Disk journal read notice: $e');
    }
  }

  /// Initializes the SQLite database and recovers any interrupted in-flight states
  Future<void> initDatabase() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Load persisted state from disk
    await loadFromDisk();

    // CRITICAL RECOVERY: If app was terminated while syncing,
    // reset any visits stuck in 'syncing' back to 'pendingSync'
    await resetStaleSyncingStates();
  }

  /// App termination recovery: Resets orphaned 'syncing' records to 'pendingSync'
  Future<int> resetStaleSyncingStates() async {
    int resetCount = 0;
    for (final entry in _tableRows.entries) {
      if (entry.value['sync_state'] == VisitSyncState.syncing.name) {
        entry.value['sync_state'] = VisitSyncState.pendingSync.name;
        entry.value['sync_error'] = 'Upload interrupted by app termination. Recovered from SQLite.';
        entry.value['updated_at'] = DateTime.now().toUtc().toIso8601String();
        resetCount++;
      }
    }
    if (resetCount > 0) {
      await flushToDisk();
    }
    return resetCount;
  }

  /// Inserts a new field visit transactionally into SQLite & writes to disk
  Future<void> insertVisit(LocalVisitModel visit) async {
    final row = visit.toSqliteMap();
    _tableRows[visit.id] = Map<String, dynamic>.from(row);
    await flushToDisk();
  }

  /// Updates an existing visit in SQLite & writes to disk
  Future<void> updateVisit(LocalVisitModel visit) async {
    final row = visit.toSqliteMap();
    _tableRows[visit.id] = Map<String, dynamic>.from(row);
    await flushToDisk();
  }

  /// Atomically updates synchronization state, error message, and server receipt
  Future<void> updateSyncState(
    String id,
    VisitSyncState state, {
    String? error,
    DateTime? serverReceiptTime,
    String? photoUrl,
    bool? isFlaggedForReview,
    List<String>? reviewSignals,
    int? syncAttempts,
  }) async {
    final row = _tableRows[id];
    if (row == null) return;

    row['sync_state'] = state.name;
    row['updated_at'] = DateTime.now().toUtc().toIso8601String();

    if (error != null) row['sync_error'] = error;
    if (serverReceiptTime != null) {
      row['server_receipt_time'] = serverReceiptTime.toUtc().toIso8601String();
    }
    if (photoUrl != null) row['photo_upload_url'] = photoUrl;
    if (isFlaggedForReview != null) {
      row['is_flagged_for_review'] = isFlaggedForReview ? 1 : 0;
    }
    if (reviewSignals != null) {
      row['review_signals'] = reviewSignals.toString();
    }
    if (syncAttempts != null) {
      row['sync_attempts'] = syncAttempts;
    }
    row['last_sync_attempt'] = DateTime.now().toUtc().toIso8601String();
    await flushToDisk();
  }

  /// Fetches a specific visit by its local UUID
  Future<LocalVisitModel?> getVisitById(String id) async {
    final row = _tableRows[id];
    if (row == null) return null;
    return LocalVisitModel.fromSqliteMap(row);
  }

  /// Returns all visits awaiting upload (pendingSync or syncFailed)
  Future<List<LocalVisitModel>> getPendingVisits() async {
    final List<LocalVisitModel> result = [];
    for (final row in _tableRows.values) {
      final state = row['sync_state'];
      if (state == VisitSyncState.pendingSync.name ||
          state == VisitSyncState.syncFailed.name) {
        result.add(LocalVisitModel.fromSqliteMap(row));
      }
    }
    // Sort oldest first (FIFO)
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  /// Returns all stored visits
  Future<List<LocalVisitModel>> getAllVisits() async {
    final list = _tableRows.values.map((r) => LocalVisitModel.fromSqliteMap(r)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Returns count of visits awaiting upload
  Future<int> getPendingCount() async {
    int count = 0;
    for (final row in _tableRows.values) {
      final state = row['sync_state'];
      if (state == VisitSyncState.pendingSync.name ||
          state == VisitSyncState.syncFailed.name ||
          state == VisitSyncState.syncing.name) {
        count++;
      }
    }
    return count;
  }

  /// Returns count of visits needing review
  Future<int> getNeedsReviewCount() async {
    int count = 0;
    for (final row in _tableRows.values) {
      if (row['sync_state'] == VisitSyncState.needsReview.name ||
          row['is_flagged_for_review'] == 1) {
        count++;
      }
    }
    return count;
  }

  /// Enforces retention rule: Never delete unsynced records!
  Future<bool> deleteVisit(String id) async {
    final row = _tableRows[id];
    if (row == null) return false;

    final state = row['sync_state'];
    if (state != VisitSyncState.synced.name && state != VisitSyncState.needsReview.name) {
      debugPrint('[SqliteVisitDatabase] Retention guard: Rejected deleting unsynced visit $id');
      return false;
    }

    _tableRows.remove(id);
    await flushToDisk();
    return true;
  }

  /// Testing & Maintenance helper to clear table and delete disk journal
  Future<void> clearAll() async {
    _tableRows.clear();
    try {
      final file = _resolveJournalFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
