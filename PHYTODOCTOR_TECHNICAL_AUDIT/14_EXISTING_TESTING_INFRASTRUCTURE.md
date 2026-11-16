# PhytoDoctor Technical Audit: 14 - Existing Testing Infrastructure

> **Audit Scope:** Inspection of existing test suites across the FastAPI backend (`backend/tests/`) and Flutter mobile app (`mobile/test/`), testing configurations, and CI/CD validation gates.

---

## 1. Backend Test Suite Architecture (`backend/tests/`)

The backend testing suite is built on **Pytest** and **pytest-asyncio**, utilizing an isolated, in-memory SQLite database to ensure tests run rapidly without side effects on production data.

```
backend/tests/
├── conftest.py                      # Global fixtures: test DB engine, async HTTP client, seed accounts
├── test_admin_dashboard_api.py      # Admin KPI statistics and audit log endpoints
├── test_attendance.py               # Shift clock-in/out state machine and manager roster
├── test_auth_and_roles.py           # Login, portals, RBAC, password checks, rate limiting
├── test_chat.py                     # Direct messaging, room security, and announcements
├── test_cloudinary_integration.py   # Signature generation, mock upload, format limits
├── test_full_backend.py             # Integrated end-to-end multi-role system test
├── test_offline_sync_idempotency.py # UUID idempotency keys and photo dedup enforcement
├── test_system_version.py           # App version gating, force-update flag, APK download
├── test_targets_and_performance.py  # Quota calculations, batch targets, multi-period trends
└── test_visit_workflow.py           # Visit submission, anti-fraud checks, supervisor verify
```

### 1.1. Test Harness & Fixtures (`conftest.py`)
- **Database Engine:** `sqlite+aiosqlite:///./test_phytodoctor.db`
- **Execution Mode:** Every test function runs within an isolated transaction that creates all tables on setup and drops them on teardown.
- **Client Fixture:** `httpx.AsyncClient` bound to `app` with `base_url="http://test"`.
- **Pre-provisioned Fixtures:**
  - `owner_token`: Valid HS256 Bearer JWT for `UserRole.OWNER`.
  - `manager_token`: Valid HS256 Bearer JWT for `UserRole.MANAGER`.
  - `employee_token`: Valid HS256 Bearer JWT for `UserRole.EMPLOYEE`.

---

## 2. Detailed Breakdown of Backend Test Modules

| Test File | Test Cases Implemented | Key Validations |
|-----------|------------------------|-----------------|
| `test_auth_and_roles.py` | 14 test functions | - Case-insensitive email/username login<br>- Password bcrypt verification<br>- Rejection of wrong passwords<br>- Inactive account lockout (403)<br>- Portal validation (Agronomist blocked from Admin Portal)<br>- Token refresh and token rotation<br>- Rate limiting lockout after 5 consecutive failures |
| `test_visit_workflow.py` | 8 test functions | - Successful visit submission with photo & GPS<br>- Verification rejection of duplicate `photo_asset_id`<br>- Accuracy > 50m triggers `LOW_GPS_ACCURACY` signal<br>- Mock location flag triggers `REPORTED_MOCK_LOCATION`<br>- Clock drift > 24h triggers `SUSPICIOUS_UPLOAD_DELAY`<br>- Supervisor approval (`VERIFIED`) and rejection (`REJECTED`) |
| `test_offline_sync_idempotency.py`| 6 test functions | - Re-submitting identical visit UUID returns HTTP 200 without creating duplicate row<br>- UUID collision between different users raises HTTP 409<br>- Multiple retries under flaky simulated network return consistent results |
| `test_targets_and_performance.py` | 10 test functions | - Single target creation with date validations<br>- Batch target creation for multiple subordinates<br>- Weekly target multiplier (x6 days) and Monthly multiplier (x26 days)<br>- Verification rule: Unverified visits do NOT count towards targets |
| `test_attendance.py` | 6 test functions | - Agronomist clock-in marks `is_active=True`<br>- Repeated clock-in returns idempotent status<br>- Clock-out updates `clock_out_time` and sets `is_active=False`<br>- Manager roster accurately formats active vs off-duty counts |
| `test_chat.py` | 7 test functions | - Direct room creation between employee and assigned manager<br>- Message delivery order and timestamps<br>- Polling filter (`?after=timestamp`) returns only fresh messages<br>- Announcement channel creation restricted to CEO |
| `test_cloudinary_integration.py` | 5 test functions | - Signed authorization HMAC-SHA1 signature verification<br>- File size check rejecting uploads > 10MB (413 Payload Too Large)<br>- Content-type check rejecting disallowed MIME types |
| `test_system_version.py` | 4 test functions | - Client version check against `min_required_build_number`<br>- `force_update=True` flag verification<br>- Direct APK binary streaming (`download-apk`) verification |

---

## 3. Mobile Client Test Suite Architecture (`mobile/test/`)

The mobile test suite runs under the Flutter Test framework (`flutter_test`):

```
mobile/test/
├── auth_flow_test.dart       # Portal selection, form validation, and authentication routing
├── offline_sync_test.dart    # SQLite queue enqueueing, sync state transitions, backoff calculation
└── visit_workflow_test.dart  # Form field validation, GPS acquisition states, submission logic
```

### 3.1. Test Details
1. **`auth_flow_test.dart`:**
   - Tests `PortalSelectionScreen` tap interactions (navigating to Employee vs Admin login).
   - Validates required form fields in `LoginScreen`.
   - Tests mocked authentication responses from `AuthService`.
2. **`offline_sync_test.dart`:**
   - Tests `LocalVisitQueue.enqueueVisit` inserting into the queue.
   - Tests `OfflineSyncManager.calculateBackoff`: verifies $2^n$ progression.
   - Verifies `resetStaleSyncingStates` recovers interrupted uploads.
3. **`visit_workflow_test.dart`:**
   - Tests `RecordVisitScreen` validation: requires client name of at least 2 characters.
   - Verifies GPS locking threshold displays.
   - Tests submission state disabling buttons during active upload.

---

## 4. CI/CD Automated Test Execution

Configured in `.github/workflows/production-release.yml`:

```yaml
- name: Run Full Backend Test Suite
  env:
    ENVIRONMENT: test
    PYTHONPATH: .
    SECRET_KEY: test_secret_key_ci_environment_verification_hs256_32bytes
    DATABASE_URL: sqlite+aiosqlite:///./test_phytodoctor.db
  run: |
    python -m pytest -v

- name: Test Database Disaster Recovery Drill
  run: |
    python scripts/backup_restore.py --drill

- name: Run Flutter Unit & Widget Tests
  run: flutter --no-version-check test
```

Both backend Pytest and mobile Flutter tests must pass with 0 exit code before production release artifacts (APK/AAB/Web dist) are compiled.

---

## 5. Testing Deficiencies & Gaps in Current Infrastructure

| Testing Domain | Current Status | Defect / Vulnerability |
|----------------|----------------|------------------------|
| **Mobile End-to-End Integration Tests** | Missing | No automated integration tests (Patrol, Maestro, or Flutter Driver) validating actual UI interactions on physical devices. |
| **PostgreSQL Integration Tests** | Missing | Both local tests and CI test against SQLite. SQL dialect differences with PostgreSQL (e.g., date math, JSON functions, FK constraints) are not tested. |
| **Network Flakiness Simulation** | Minimal | No automated test simulates partial HTTP socket drops halfway through a 10MB photo upload. |
| **Concurrent Load / Stress Testing** | Missing | In-memory rate limiting and SQLite file locking have not been evaluated under simultaneous multi-user loads (e.g. Locust / k6). |
| **Live Device Hardware Mocks** | Partial | Flutter camera viewfinder and native Android GPS locking are mocked in unit tests, not validated against real hardware sensors. |
