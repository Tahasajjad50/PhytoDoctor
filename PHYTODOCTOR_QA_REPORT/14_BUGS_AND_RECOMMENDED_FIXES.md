# 14 – BUGS CATALOG & RESOLUTIONS

### PHY-BUG-01: Flutter Error Grey Box on Verification Queue
- **Severity:** High
- **Status:** **RESOLVED**
- **Symptom:** Manager saw "1 Awaiting" but queue card rendered as empty grey container.
- **Fix:** Replaced strict type cast `audit['distance_to_shop'] as String` with null-safe fallback getters in `manager_dashboard_screen.dart` and `visit_detail_screen.dart`.

### PHY-BUG-02: Verification Approval Schema Mismatch
- **Severity:** High
- **Status:** **RESOLVED**
- **Symptom:** Approving a visit failed silently with HTTP 422 and reappeared on refresh.
- **Fix:** Updated request body in `_verifyVisit` from `decision` to `status` and `review_reason`.

### PHY-BUG-03: Server URL Leaked in Credentials Sharing
- **Severity:** Medium
- **Status:** **RESOLVED**
- **Symptom:** Sharing credentials text shared internal server address with employees.
- **Fix:** Removed `Server Address: ${AuthService.defaultBaseUrl}` from share templates.

### PHY-BUG-04: Empty Supervised Team on Manager Portal
- **Severity:** Medium
- **Status:** **RESOLVED**
- **Symptom:** Manager portal showed "No field agronomists assigned" because team list was never populated.
- **Fix:** Connected `_teamMembers` to `/api/v1/attendance/admin/roster` with tap-to-history navigation.

### PHY-BUG-05: Mock Dummy Visits in Visit History
- **Severity:** Low
- **Status:** **RESOLVED**
- **Symptom:** Visit history showed hardcoded static entries (`Bismillah Fertilizer Store`).
- **Fix:** Connected `visit_history_screen.dart` to live `/api/v1/visits` endpoint.

### PHY-BUG-06: SQLite Missing Columns on Deployed Database
- **Severity:** High
- **Status:** **RESOLVED**
- **Symptom:** Queries failed with `no such column: users.created_by_id`.
- **Fix:** Added startup column migrations in `main.py` lifespan context.
