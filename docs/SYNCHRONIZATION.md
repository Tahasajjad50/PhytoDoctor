# Phyto Doctor — Offline-First Synchronization & Conflict Handling Architecture

## 1. Executive Summary

Phyto Doctor field agronomists frequently operate in rural agricultural regions across Pakistan (e.g. Multan, Khanewal, Vehari, Bahawalpur) with intermittent, 2G, or non-existent cellular coverage. 

The application implements a strict **Offline-First Architecture**:
1. Every visit is committed to a local **SQLite database** and **app-private storage** before any network call is initiated.
2. The device generates a client-authoritative **UUIDv4** for each visit before transmission.
3. The server uses this UUID as an **Idempotency Key**, ensuring duplicate submissions from network retransmissions, timeouts, or repeated "Sync Now" taps return the confirmed visit without duplicate rows or errors.
4. **Zero Evidence Deletion Guard**: Evidence photos and visit records are never pruned locally until explicit server confirmation is received and the retention period (30 days) has elapsed.

---

## 2. Visit State Lifecycle

Each visit moves through deterministic states defined in `VisitSyncState`:

```
                 +-----------------+
                 |      Draft      |
                 +--------+--------+
                          | User taps "Save & Submit"
                          v
                 +-----------------+
        +------->|   Pending Sync  |<---------+
        |        +--------+--------+          |
        |                 | Sync triggered    | Interrupted /
        |                 v (Sync Now / WorkMgr)| App killed
        |        +-----------------+          |
        |        |     Syncing     |----------+
        |        +--------+--------+
        |                 |
        |   +-------------+-------------+
        |   | Error (401 / Timeout)     | HTTP 200/201
        |   v                           v
+-------+--------+              +-----------------+
|   Sync Failed  |              |     Synced      |
| (With Backoff) |              +--------+--------+
+----------------+                       | Flagged by Server
                                         v
                                +-----------------+
                                |  Needs Review   |
                                +-----------------+
```

### State Definitions
* **`Draft`**: Form is being edited; photo or GPS not yet finalized.
* **`Pending Sync`**: Transactionally committed to SQLite; queued for network transmission.
* **`Syncing`**: In-flight HTTP request. If the app is killed during this state, SQLite crash recovery automatically resets it to `Pending Sync` on next startup.
* **`Synced`**: Confirmed by server with HTTP 200/201.
* **`Needs Review`**: Confirmed by server, but supervisor review signals triggered (e.g. reported mock GPS, $\gt 50\text{m}$ accuracy radius, or clock drift).
* **`Sync Failed`**: Network failure, timeout, or server error. Retried with exponential backoff.

---

## 3. SQLite Database Schema (`local_field_visits`)

Structured records are stored in the app-private SQLite database:

| Column | Type | Constraints / Description |
| :--- | :--- | :--- |
| `id` | `TEXT` | Primary Key. UUID generated locally prior to transmission. |
| `employee_id` | `TEXT` | UUID of the authenticated agronomist. |
| `client_name` | `TEXT` | Mandatory client/dealer/farmer name. |
| `client_phone` | `TEXT` | Optional phone number. |
| `client_type` | `TEXT` | `DEALER`, `DISTRIBUTOR`, or `FARMER`. |
| `visit_purpose` | `TEXT` | Category of interaction. |
| `notes` | `TEXT` | Qualitative observations. |
| `latitude` | `REAL` | GPS latitude fix. |
| `longitude` | `REAL` | GPS longitude fix. |
| `gps_accuracy` | `REAL` | Accuracy radius in meters. |
| `is_mock_location` | `INTEGER` | `0` = genuine hardware; `1` = mock signal. |
| `device_capture_time`| `TEXT` | ISO-8601 UTC timestamp stamped at camera shutter. |
| `server_receipt_time`| `TEXT` | ISO-8601 UTC timestamp confirmed by backend. |
| `local_photo_path` | `TEXT` | App-private absolute file path. |
| `photo_asset_id` | `TEXT` | Unique asset ID (e.g. `PHOTO_<epoch>_<emp>`). Unique index. |
| `photo_upload_url` | `TEXT` | Staged Cloudinary delivery URL once binary is uploaded. |
| `sync_state` | `TEXT` | `pendingSync`, `syncing`, `synced`, `needsReview`, `syncFailed`. |
| `sync_attempts` | `INTEGER`| Counter used to compute exponential backoff. |
| `last_sync_attempt`| `TEXT` | Timestamp of last transmission attempt. |
| `sync_error` | `TEXT` | Human-readable explanation of network, auth, or server error. |
| `is_flagged_for_review`| `INTEGER` | `1` if supervisor inspection signals triggered. |
| `review_signals` | `TEXT` | JSON array of flagged signal tags. |
| `created_at` | `TEXT` | Local record creation timestamp. |
| `updated_at` | `TEXT` | Last update timestamp. |

---

## 4. App-Private Photo Storage & Integrity

* **Sandbox Location:** Stored exclusively in the app's internal sandbox:
  `/data/user/0/com.phytodoctor.fieldapp/app_flutter/private_evidence/`
* **Gallery Exclusion:** Photos are saved with private Unix permissions (`0600`). Android's public `MediaStore` is never touched, preventing the gallery from viewing or corrupting evidence.
* **Low Storage Warning:** `PhotoStorageService.checkStorageHealth()` checks free space before shutter release. If available disk space is $< 50\text{ MB}$, the user receives an alert:
  > *"Warning: Low device storage (<50MB free). Please free up disk space to ensure visit photos can be saved reliably."*
* **Partial Photo Recovery:** Before initiating upload, file size and integrity are validated. If a photo was partially captured or truncated due to a sudden power outage, it is flagged for retake rather than uploading a corrupted 0-byte file.

---

## 5. Synchronization & Conflict Handling Mechanics

### 5.1 Concurrency Lock (Debouncing)
When an employee repeatedly taps **Sync Now**, `OfflineSyncManager` checks `_isSyncing`. If an upload is in-flight, the second tap is ignored, preventing overlapping HTTP calls and race conditions.

### 5.2 Exponential Backoff
Failed visits are retried according to the formula:
$$\text{Backoff Duration} = 2^{\min(\text{attempts}, 5)} \text{ seconds}$$
* Attempt 1: 2s
* Attempt 2: 4s
* Attempt 3: 8s
* Attempt 4: 16s
* Attempt 5+: 32s (capped at 60s)

Manual tapping of **Sync Now** overrides the backoff window and forces an immediate retry.

### 5.3 UUID Idempotency Key
Every submission payload includes `'id': '<client_uuid>'`. When the FastAPI backend receives the request:
```python
if visit_in.id:
    existing_by_id = await db.get(FieldVisit, visit_in.id.strip())
    if existing_by_id:
        if existing_by_id.employee_id == current_user.id:
            return VisitResponse.model_validate(existing_by_id) # Idempotent 200 OK
        else:
            raise HTTPException(409, "UUID collision across accounts")
```
If a mobile network times out after the server inserts the row, the mobile app's subsequent retry sends the same UUID. The server recognizes the existing record and returns it with HTTP 200, confirming the sync without error or duplicate records.

### 5.4 Expired Authentication (HTTP 401)
If an access token expires while offline:
1. The server returns HTTP 401 Unauthorized.
2. `OfflineSyncManager` catches the 401 and sets `_lastError = "Session expired (HTTP 401). Local records safely preserved in SQLite. Please log in again to sync."`
3. **No local records are deleted.** All drafts and visits remain safely stored in SQLite.
4. When the user logs in, fresh tokens are issued, and the sync resumes immediately.

### 5.5 Evidence Immutability & Conflict Resolution
* **Conflict Rule:** The server is the authority for **review decisions** (`VERIFIED` vs `REJECTED`), while the client is the authority for **on-site sensor evidence** (GPS coordinates and shutter photo timestamp).
* **Immutability Guard:** Resubmitting a new visit with an existing `photo_asset_id` on a different visit is blocked with `HTTP 409 Conflict`. Evidence cannot be replaced or overwritten.

---

## 6. Android WorkManager Integration

* **Background Worker:** Registered with Android `WorkManager` using periodic constraint:
  * Network: `NetworkType.CONNECTED`
  * Interval: 15 minutes
  * Battery: `BatteryNotLow = true`
* **Boot Persistence:** Configured with `RECEIVE_BOOT_COMPLETED` in `AndroidManifest.xml` so background sync resumes automatically after device reboot.
