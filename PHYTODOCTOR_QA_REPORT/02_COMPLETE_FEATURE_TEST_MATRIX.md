# 02 – COMPLETE FEATURE TEST MATRIX

| Module | Feature / User Story | Role | Automated Test | Live Verified | Result |
|---|---|---|---|---|---|
| **Auth** | Multi-portal login routing (admin vs employee) | ALL | `test_auth_and_roles.py` | YES | **PASS** |
| **Auth** | JWT Token expiration & Refresh token rotation | ALL | `test_auth_and_roles.py` | YES | **PASS** |
| **Auth** | Rate limit: 5 failed attempts locks for 15 mins (HTTP 429) | ALL | `test_auth_and_roles.py` | YES | **PASS** |
| **Auth** | Password reset & token revocation | OWNER | `test_admin_dashboard_api.py` | YES | **PASS** |
| **Attendance**| Daily Clock-in with server UTC timestamp | EMPLOYEE | `test_attendance.py` | YES | **PASS** |
| **Attendance**| Daily Clock-out with status change | EMPLOYEE | `test_attendance.py` | YES | **PASS** |
| **Attendance**| Real-time staff roster view for manager | MANAGER | `test_attendance.py` | YES | **PASS** |
| **Attendance**| Company-wide active attendance count | OWNER | `test_admin_dashboard_api.py` | YES | **PASS** |
| **Visits** | Field visit submission with GNSS and photo ID | EMPLOYEE | `test_visit_workflow.py` | YES | **PASS** |
| **Visits** | Client name mandatory validation (>=2 chars) | EMPLOYEE | `visit_workflow_test.dart` | YES | **PASS** |
| **Visits** | GPS accuracy threshold enforcement (<=50m) | ALL | `visit_workflow_test.dart` | YES | **PASS** |
| **Visits** | Mock location signal detection & flagging | ALL | `test_visit_workflow.py` | YES | **PASS** |
| **Visits** | Device capture time clock drift detection | ALL | `test_visit_workflow.py` | YES | **PASS** |
| **Visits** | Duplicate photo prevention (unique asset ID) | ALL | `test_visit_workflow.py` | YES | **PASS** |
| **Visits** | Manager Pending Verification Queue listing | MANAGER | `test_admin_dashboard_api.py` | YES | **PASS** |
| **Visits** | Supervisor visit approval with reason | MANAGER | `test_admin_dashboard_api.py` | YES | **PASS** |
| **Visits** | Supervisor visit rejection with reason | MANAGER | `test_admin_dashboard_api.py` | YES | **PASS** |
| **Visits** | Visit detail inspection & Google Maps link | MANAGER | Manual Inspection | YES | **PASS** |
| **Targets** | Dynamic daily target loading (default 6) | EMPLOYEE | `test_targets_and_performance.py`| YES | **PASS** |
| **Targets** | Target Quota breakdown screen navigation | EMPLOYEE | Manual Inspection | YES | **PASS** |
| **Targets** | Verified visits increment quota completion | EMPLOYEE | `test_targets_and_performance.py`| YES | **PASS** |
| **Targets** | Pending/Drafts do NOT inflate verified target | EMPLOYEE | `test_targets_and_performance.py`| YES | **PASS** |
| **Performance**| Day-by-day trend points calculation | EMPLOYEE | `test_targets_and_performance.py`| YES | **PASS** |
| **Performance**| Team comparison leaderboard for managers | MANAGER | `test_targets_and_performance.py`| YES | **PASS** |
| **Performance**| Company-wide completion percentage | OWNER | `test_admin_dashboard_api.py` | YES | **PASS** |
| **Users** | Provision field employee account | OWNER/MGR| `test_admin_dashboard_api.py` | YES | **PASS** |
| **Users** | Provision regional manager account | OWNER | `test_admin_dashboard_api.py` | YES | **PASS** |
| **Users** | Supervisor reassignment / reporting transfer | OWNER | `test_admin_dashboard_api.py` | YES | **PASS** |
| **Users** | Supervised employee account list & password view | MANAGER | Manual Inspection | YES | **PASS** |
| **Offline** | Disconnected visit capture to SQLite queue | EMPLOYEE | `offline_sync_test.dart` | YES | **PASS** |
| **Offline** | Reconnection auto-sync with exponential backoff | EMPLOYEE | `offline_sync_test.dart` | YES | **PASS** |
| **Offline** | Idempotent sync (no duplicate records on retry)| EMPLOYEE | `test_offline_sync_idempotency.py`| YES | **PASS** |
| **Customers** | Add farmer/dealer client & assign to agronomist| MANAGER | `test_full_backend.py` | YES | **PASS** |
| **System** | App version check & mandatory update prompt | ALL | `test_system_version.py` | YES | **PASS** |
| **Audit** | Immutable security audit trail recording | OWNER | `test_admin_dashboard_api.py` | YES | **PASS** |
