# PhytoDoctor Technical Audit: 11 - Offline & Synchronization Architecture

> **Domain:** Offline-First Data Capture, Local SQLite Queue, Deterministic Synchronization, and Backend Idempotency.

---

## 1. Offline Architecture Overview

Agricultural field agronomists frequently operate in rural zones of Pakistan with intermittent 2G/3G connectivity or complete signal dropouts. The application implements an **Offline-First Data Pipeline**:

```
[ Field Visit Form Submission ]
               │
               ▼
   [ LocalVisitQueue.enqueueVisit() ]
               │
               ├── 1. Generates unique client UUID ('VISIT_{timestamp}_{hash}')
               ├── 2. Stores photo in local device cache
               └── 3. Inserts into SQLite table 'local_field_visits' (sync_state='pendingSync')
               │
               ▼
[ OfflineSyncManager.syncNow() ] ◄── Triggered by: Manual "Sync Now" tap OR Network Reconnection
               │
      [ Concurrency Lock Check ] (Rejects overlapping sync runs)
               │
      [ Storage Health Check ] (Verifies adequate device flash space)
               │
   ┌───────────┴──────────────────────────────┐
   │ Loop through pending records (FIFO)      │
   ▼                                          ▼
[ Step A: Cloudinary Upload ]        [ Step B: Visit Submission ]
- Uploads local photo to Cloudinary   - Transmits VisitCreate with client UUID
- Recovers if already uploaded       - Backend evaluates idempotency key
- Stores photo_url in SQLite row     - SQLite updates state: 'synced'
```

---

## 2. Local Database Schema: `local_field_visits`

Defined in `mobile/lib/core/storage/sqlite_visit_database.dart`:

```sql
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
```

---

## 3. Synchronization State Machine (`VisitSyncState`)

Defined in `mobile/lib/core/models/visit_state.dart`:

```
               ┌───────────────────────┐
               │      pendingSync      │ ◄──────────┐
               └───────────┬───────────┘            │
                           │ Sync starts            │
                           ▼                        │
               ┌───────────────────────┐            │
               │        syncing        │            │
               └─────┬───────────┬─────┘            │
       Success       │           │ Failure          │ Interrupted
  (HTTP 200/201)     │           │ (HTTP error)     │ (App Kill)
                     ▼           ▼                  │
          ┌─────────────┐     ┌──────────────┐      │
          │   synced    │     │  syncFailed  │      │
          └─────────────┘     └──────┬───────┘      │
                                     │ Retry        │
                                     └──────────────┘
```

### App Termination Recovery:
If the mobile operating system terminates the application while an upload is in progress:
- The record would normally remain stuck in the `'syncing'` state indefinitely.
- On startup, `SqliteVisitDatabase.resetStaleSyncingStates()` automatically executes:
  ```dart
  if (row['sync_state'] == 'syncing') {
    row['sync_state'] = 'pendingSync';
    row['sync_error'] = 'Upload interrupted by app termination. Recovered from SQLite.';
  }
  ```

---

## 4. Synchronization Resilience Controls

Implemented in `mobile/lib/core/sync/offline_sync_manager.dart`:

### 4.1. Concurrency Debounce Lock
Prevents race conditions caused by repeated user taps on the "Sync Now" button:
```dart
if (_isSyncing) {
  debugPrint('Sync is already active. Repeated Sync Now request debounced.');
  return 0;
}
```

### 4.2. Exponential Backoff Formula
To prevent network flooding and battery drain during repeated failures:
$$\text{Backoff Duration} = 2^{\min(\text{attempts}, 5)} \text{ seconds}$$
- Attempt 1: 2 seconds
- Attempt 2: 4 seconds
- Attempt 3: 8 seconds
- Attempt 4: 16 seconds
- Attempt 5+: 32 seconds (Capped at 60s max)

### 4.3. Anti-Data-Loss Retention Guard
Unsynced records can **never** be deleted by user actions or auto-pruning:
```dart
Future<bool> deleteVisit(String id) async {
  final state = row['sync_state'];
  if (state != 'synced' && state != 'needsReview') {
    debugPrint('Retention guard: Rejected deleting unsynced visit $id');
    return false;
  }
  ...
}
```

---

## 5. Backend Idempotency & Deduplication Engine

Declared in `backend/app/api/v1/visits.py`:

### 5.1. UUID Idempotency Key
- When a visit is logged offline, the client generates a unique UUID (e.g., `e4b6c8a2-1422-4871...`).
- When syncing, this UUID is submitted in `VisitCreate.id`.
- If a network dropout occurs after the server committed the visit but before the client received the HTTP 200, the client will retry with the exact same UUID.
- The server checks `db.get(FieldVisit, visit_in.id)`:
  - If found and `existing.employee_id == current_user.id`, it immediately returns `VisitResponse.model_validate(existing)` with HTTP 200.
  - **No duplicate visit is recorded.**

### 5.2. Photo Asset Uniqueness
- If a client attempts to submit a visit using a `photo_asset_id` that has already been registered in another visit, the server raises `HTTP 409 Conflict`:
  > *"Duplicate photo evidence: This photo asset has already been associated with an existing visit and cannot be resubmitted or silently replaced."*

---

## 6. Implementation Deficiencies in Current Offline Storage

1. **In-Memory Cache vs. True SQLite Disk Persistence:**
   - In `sqlite_visit_database.dart`, records are held in a private map `_tableRows = {}`.
   - While the SQL table creation strings are declared, the current implementation stores rows in Dart memory, meaning that a full application process kill on Android will reset the pending queue unless backed by `sqflite`.
2. **Missing Network Connectivity Listener:**
   - Synchronization is currently triggered primarily via manual tap ("Sync Now") or screen mount.
   - Automatic background synchronization on connectivity restoration (`connectivity_plus` package) is not implemented.
