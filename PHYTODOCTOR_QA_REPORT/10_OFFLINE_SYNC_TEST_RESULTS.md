# 10 – OFFLINE SYNCHRONIZATION & IDEMPOTENCY TESTS

## 1. Offline SQLite Queueing
- When device is in Airplane Mode, `LocalVisitQueue` writes visit records to local SQLite.
- Pending sync counter on dashboard increments immediately (`0 Drafts` -> `1 Drafts Pending Sync`).

## 2. Automatic Reconnection & Sync
- When connectivity resumes, `OfflineSyncManager` automatically uploads queued visits.
- Once HTTP 201 is received from backend, local SQLite draft is deleted, preventing disk bloat.

## 3. Idempotency & Duplicate Prevention
- Each offline visit generates a client-side UUID idempotency key before transmission.
- Submitting the same visit twice returns the existing record with HTTP 200 without creating duplicate visits or inflating target quotas. Verified in `test_offline_sync_idempotency.py`.

## 4. Concurrency Guard
- Repeated taps on "Sync Now" trigger the concurrency lock:
  `[OfflineSyncManager] Sync is already active. Repeated Sync Now request debounced.`
