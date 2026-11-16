# PhytoDoctor Technical Audit: 05 - Role & Feature Inventory

> **Inspection Scope:** Complete cross-comparison of user roles (`OWNER`, `MANAGER`, `EMPLOYEE`), frontend UI affordances, backend route guards, and database access controls.

---

## 1. Role Definitions & Permissions Matrix

PhytoDoctor implements three distinct user roles defined in `backend/app/models/user.py` as `UserRole`:

| Feature / Permission Area | Employee (Field Agronomist) | Manager (Regional Admin) | Owner (Company CEO) | Enforcement Mechanism |
|---------------------------|:---------------------------:|:------------------------:|:-------------------:|-----------------------|
| **Portal Access** | Field Portal Only | Admin Portal Only | Admin Portal Only | Frontend & Backend (`portal` param in `/auth/login`) |
| **View Own Dashboard** | ✅ Full Access | ✅ Redirects to Admin | ✅ Redirects to Admin | Frontend & Backend |
| **Record Field Visit** | ✅ In-App Camera + GPS | ❌ Prohibited | ❌ Prohibited | Backend (`require_employee` / role check) |
| **View Field Visits** | 👁️ Own Visits Only | 👁️ Own Team Visits Only | 👁️ Company-Wide All | Backend SQL Scoping in `/visits/` |
| **Verify / Reject Visits** | ❌ Forbidden | ✅ Supervised Agronomists | ✅ All Agronomists | Backend (`require_admin` in `/visits/{id}/verify`) |
| **Dynamic Daily Target** | 👁️ View Assigned | ✏️ Assign to Own Team | ✏️ Assign Globally | Backend (`targets.py` manager check) |
| **Add Customer / Farm** | ❌ No Create Access | ✅ Add in Supervised Area | ✅ Add Company-Wide | Backend (`require_admin` in `/customers/`) |
| **View Customers** | 👁️ Assigned & Territory | 👁️ All in Territory | 👁️ All Company-Wide | Backend SQL Scoping in `/customers/` |
| **Shift Attendance (Clock In/Out)** | ✅ Shift Toggle | 👁️ Roster View Only | 👁️ Roster View Only | Backend (`attendance.py` role check) |
| **View Attendance Roster** | ❌ Forbidden | ✅ View Supervised Staff | ✅ View All Staff | Backend (`require_admin` in `/attendance/admin/roster`) |
| **Create Employee Account** | ❌ Forbidden | ✅ Create Team Member | ✅ Create Any Role | Backend (`require_admin` in `/users/`) |
| **Manage Credentials** | ❌ Forbidden | ✏️ Own Created Only | ✏️ All Users | Backend (`users.py` manager ID check) |
| **Share Credentials (WhatsApp)**| ❌ Forbidden | ✅ Share Supervised | ✅ Share Any | Frontend Native Share Sheet |
| **Supervision Transfer** | ❌ Forbidden | ❌ Forbidden | ✏️ Reassign Agronomist | Backend (`require_owner` in `/users/supervision/transfer`) |
| **Company KPI Overview** | ❌ Forbidden | ❌ Scoped to Team | ✅ Full Company Overview | Backend (`require_owner` / `require_admin`) |
| **Direct 1-on-1 Chat** | 💬 With Supervised Admin | 💬 With Team & CEO | 💬 With Anyone | Backend (`chat.py` room permissions) |
| **Company Announcement Broadcast**| 👁️ Read-Only | 👁️ Read-Only | 📢 Broadcast to All | Backend (`chat.py` announcement flag check) |
| **In-App Update Enforcement** | ⚠️ Forced Modal | ⚠️ Forced Modal | ⚠️ Forced Modal | Backend `/api/v1/system/version` check |

---

## 2. Complete Feature Inventory & Implementation Status

Status Indicators:
- `FULLY IMPLEMENTED` — Complete end-to-end integration between Flutter UI, FastAPI endpoint, and Database.
- `PARTIALLY IMPLEMENTED` — Working end-to-end, but with documented edge-case limitations or fallback dependencies.
- `FRONTEND ONLY` — Screen or button exists in UI, but has no backend endpoint or calls mock logic.
- `BACKEND ONLY` — Fully operational FastAPI endpoint exists, but has no dedicated UI trigger in Flutter.
- `MOCKED` — Returns simulated data in test/offline modes.

| # | Feature Name | Intended Roles | Frontend Component | Backend Endpoint | Database Model | External Service | Status |
|---|--------------|----------------|--------------------|------------------|----------------|------------------|--------|
| **1** | **User Login & Portal Guard** | All Roles | `login_screen.dart` | `POST /api/v1/auth/login` | `User`, `RefreshToken` | None | **FULLY IMPLEMENTED** |
| **2** | **Token Refresh Rotation** | All Roles | `auth_service.dart` | `POST /api/v1/auth/refresh` | `RefreshToken` | None | **FULLY IMPLEMENTED** |
| **3** | **Field Visit Submission** | `EMPLOYEE` | `record_visit_screen.dart` | `POST /api/v1/visits` | `FieldVisit` | None | **FULLY IMPLEMENTED** |
| **4** | **Camera Photo Capture** | `EMPLOYEE` | `camera_capture_screen.dart` | `POST /api/v1/media/visits/{id}/photo` | `FieldVisit` | Cloudinary API | **FULLY IMPLEMENTED** |
| **5** | **GNSS Accuracy Validation** | `EMPLOYEE` | `gps_acquisition_screen.dart` | Inspected during visit creation | `FieldVisit.gps_accuracy` | Android GPS | **FULLY IMPLEMENTED** |
| **6** | **Mock Location Flagging** | System | `location_service.dart` | Inspected in `/visits` creation | `FieldVisit.is_mock_location` | Android Location | **FULLY IMPLEMENTED** |
| **7** | **Clock Drift Calculation** | System | Device timestamp | Inspected in `/visits` creation | `FieldVisit.clock_drift_seconds` | Server UTC Clock | **FULLY IMPLEMENTED** |
| **8** | **Visit UUID Idempotency** | `EMPLOYEE` | Client-generated UUID | `POST /api/v1/visits` | `FieldVisit.id` | None | **FULLY IMPLEMENTED** |
| **9** | **Photo Deduplication Check** | System | `photo_asset_id` | `POST /api/v1/visits` | `FieldVisit.photo_asset_id` | Cloudinary | **FULLY IMPLEMENTED** |
| **10**| **Supervisor Verification Queue**| `MANAGER`, `OWNER` | `manager_dashboard_screen.dart` | `GET /api/v1/visits?status=PENDING` | `FieldVisit` | None | **FULLY IMPLEMENTED** |
| **11**| **Visit Approval / Rejection** | `MANAGER`, `OWNER` | `manager_dashboard_screen.dart` | `POST /api/v1/visits/{id}/verify`| `FieldVisit`, `AuditEvent` | None | **FULLY IMPLEMENTED** |
| **12**| **Google Maps Location Launch** | `MANAGER`, `OWNER` | `manager_dashboard_screen.dart` | None (Client Intent) | None | Google Maps App | **FULLY IMPLEMENTED** |
| **13**| **Dynamic Daily Target Progress**| `EMPLOYEE` | `employee_dashboard_screen.dart` | `GET /api/v1/employee/dashboard-summary` | `EmployeeTarget` | None | **FULLY IMPLEMENTED** |
| **14**| **Employee Target Breakdown** | `EMPLOYEE` | `employee_target_detail_screen.dart`| `GET /api/v1/employee/dashboard-summary` | `EmployeeTarget`, `FieldVisit` | None | **FULLY IMPLEMENTED** |
| **15**| **Employee Shift Clock In/Out** | `EMPLOYEE` | `employee_dashboard_screen.dart` | `POST /api/v1/attendance/clock-in`, `clock-out` | `Attendance` | None | **FULLY IMPLEMENTED** |
| **16**| **Live Staff Attendance Roster**| `MANAGER`, `OWNER` | `employee_attendance_screen.dart`| `GET /api/v1/attendance/admin/roster` | `Attendance`, `User` | None | **FULLY IMPLEMENTED** |
| **17**| **Add Customer / Farm Client** | `MANAGER`, `OWNER` | Dialog in Manager Dashboard | `POST /api/v1/customers/` | `Customer` | None | **FULLY IMPLEMENTED** |
| **18**| **Territory Auto-Assignment** | System | Customer Dialog | Resolved in `POST /customers/` | `Customer.assigned_employee_id` | None | **PARTIALLY IMPLEMENTED** (matches by substring in designation) |
| **19**| **Employee Account Creation** | `MANAGER`, `OWNER` | Dialog in Account Directory | `POST /api/v1/users/` | `User` | None | **FULLY IMPLEMENTED** |
| **20**| **Supervised Account Directory** | `MANAGER`, `OWNER` | `account_directory_screen.dart` | `GET /api/v1/users/created-accounts` | `User` | None | **FULLY IMPLEMENTED** |
| **21**| **Update Employee Credentials** | `MANAGER`, `OWNER` | `account_directory_screen.dart` | `PUT /api/v1/users/{id}/credentials` | `User`, `RefreshToken` | None | **FULLY IMPLEMENTED** |
| **22**| **WhatsApp Credential Sharing** | `MANAGER`, `OWNER` | `account_directory_screen.dart` | None (Android Intent) | None | Android Share Sheet | **FULLY IMPLEMENTED** |
| **23**| **Supervision Transfer (CEO)** | `OWNER` | `supervision_management_screen.dart`| `POST /api/v1/users/supervision/transfer` | `User.manager_id`, `AuditEvent` | None | **FULLY IMPLEMENTED** |
| **24**| **Performance Analytics (Tabs)**| `EMPLOYEE` | `performance_screen.dart` | `GET /api/v1/performance/employee/{id}/analytics` | `FieldVisit`, `EmployeeTarget` | None | **FULLY IMPLEMENTED** |
| **25**| **Team Performance Comparison** | `MANAGER`, `OWNER` | In `performance_screen.dart` / Web | `GET /api/v1/performance/team-comparison` | `FieldVisit`, `EmployeeTarget` | None | **PARTIALLY IMPLEMENTED** (API exists; mobile UI is basic) |
| **26**| **Company Performance Overview**| `OWNER` | `owner_admin_dashboard_screen.dart`| `GET /api/v1/admin/dashboard-stats` | Multiple aggregations | None | **FULLY IMPLEMENTED** |
| **27**| **In-App Direct Chat Messaging** | All Roles | `chat_conversation_screen.dart`| `GET/POST /api/v1/chat/rooms/{id}/messages`| `ChatRoom`, `ChatMessage` | None | **FULLY IMPLEMENTED** (Polling-based) |
| **28**| **Company Announcements** | `OWNER` (Write), All (Read)| `chat_list_screen.dart` | `POST /api/v1/chat/rooms` (type=ANNOUNCEMENT)| `ChatRoom`, `ChatMessage` | None | **FULLY IMPLEMENTED** |
| **29**| **Offline SQLite Draft Queue** | `EMPLOYEE` | `local_visit_queue.dart` | None (Local Engine) | `sqlite_visit_database.dart` | Android SQLite | **PARTIALLY IMPLEMENTED** (Memory cache backed; needs full disk integration) |
| **30**| **Manual "Sync Now"** | `EMPLOYEE` | `employee_dashboard_screen.dart` | Flushes queue to `POST /api/v1/visits` | `local_field_visits` | None | **FULLY IMPLEMENTED** |
| **31**| **Mandatory App Version Update** | All Roles | `app_update_service.dart` | `GET /api/v1/system/version` | `AppVersionConfig` | None | **FULLY IMPLEMENTED** |
| **32**| **Direct APK File Download** | All Roles | Browser intent | `GET /api/v1/system/download-apk` | File on disk | Static storage | **FULLY IMPLEMENTED** |
| **33**| **Audit Event Logging** | System | None | Inserted on critical actions | `AuditEvent` | None | **BACKEND ONLY** (Web admin reads via `/admin/audit-logs`) |
| **34**| **Disaster Recovery Backup Drill**| System | None | `python scripts/backup_restore.py` | SQLite DB file | Local Disk / CI | **BACKEND ONLY** |
