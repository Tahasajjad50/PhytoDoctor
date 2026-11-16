# PhytoDoctor Technical Audit: 04 - Frontend Architecture

> **Target Codebase:** `mobile/lib/`  
> **Inspection Level:** Full static analysis of all Dart screens, services, storage managers, repositories, and Android native configs.

---

## 1. Application Entry Point & Initialization Lifecycle

The mobile application initiates execution in `mobile/lib/main.dart`:

```
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = SecureStorageService();
  final savedUser = await storage.getUserSession();
  runApp(PhytoDoctorApp(initialUser: savedUser));
}
```

### Execution Flow:
1. `WidgetsFlutterBinding.ensureInitialized()` locks the Flutter engine.
2. `SecureStorageService.getUserSession()` queries Android KeyStore (`encryptedSharedPreferences`) to read cached token and user data.
3. If a valid, active user session exists:
   - If `savedUser.isAdmin` (`role == 'OWNER' || role == 'MANAGER'`), routes directly to `AdminDashboardScreen` (`OwnerAdminDashboardScreen`).
   - If `savedUser.isEmployee` (`role == 'EMPLOYEE'`), routes directly to `EmployeeDashboardScreen`.
4. If no valid session exists, routes to `PortalSelectionScreen`.
5. On app boot, `AppUpdateService.checkAndPromptUpdate(context)` checks the server's minimum build number and displays a non-dismissible update modal if the client build is outdated.

---

## 2. Screen Inventory & Route Map

The application comprises 18 distinct presentation screen files in `mobile/lib/presentation/screens/`:

| Screen Name | File Path | Permitted Roles | Primary Purpose & Key Features | API Endpoints Called | Navigation Destinations |
|-------------|-----------|-----------------|--------------------------------|----------------------|-------------------------|
| **PortalSelectionScreen** | `portal_selection_screen.dart` | Unauthenticated | Allows user to select between "Field Employee Access" and "Manager & Admin Access". | None | `LoginScreen` (passing `portal` type) |
| **LoginScreen** | `login_screen.dart` | Unauthenticated | Username/email & password entry. Portal-validated authentication. | `POST /api/v1/auth/login` | `EmployeeDashboardScreen`, `AdminDashboardScreen` |
| **EmployeeDashboardScreen** | `employee_dashboard_screen.dart` | `EMPLOYEE` | "Field Agronomist Hub": Target progress bar, 4 stat tiles (Today's Target, Verified Visits, Remaining Visits, Pending Sync), shift attendance toggle, offline sync banner. | `GET /api/v1/employee/dashboard-summary`, `POST /api/v1/attendance/clock-in`, `clock-out` | `RecordVisitScreen`, `EmployeeTargetDetailScreen`, `VisitHistoryScreen`, `PerformanceScreen`, `ChatListScreen`, `ProfileSettingsScreen` |
| **EmployeeTargetDetailScreen** | `employee_target_detail_screen.dart` | `EMPLOYEE` | Detailed breakdown of daily quota, remaining visits, verified visits, and supervisor-reviewed/flagged visits. | `GET /api/v1/employee/dashboard-summary` | `RecordVisitScreen` |
| **RecordVisitScreen** | `record_visit_screen.dart` | `EMPLOYEE` | Multi-step visit data entry: client name, phone, crop notes, GPS acquisition, photo capture. | `POST /api/v1/visits`, `POST /api/v1/media/visits/{id}/photo` | `VisitHistoryScreen` |
| **CameraCaptureScreen** | `camera_capture_screen.dart` | `EMPLOYEE` | Shutter viewfinder to capture field crop and shop evidence. | None (Native Camera channel) | Returns photo path to `RecordVisitScreen` |
| **GpsAcquisitionScreen** | `gps_acquisition_screen.dart` | `EMPLOYEE` | Acquires GNSS lock, checks accuracy radius against 50m threshold, checks mock location. | `GET /api/v1/visits/evidence-policy` | Returns coordinates to `RecordVisitScreen` |
| **VisitHistoryScreen** | `visit_history_screen.dart` | `EMPLOYEE`, `MANAGER`, `OWNER` | Chronological list of submitted visits with status badges (`PENDING`, `VERIFIED`, `REJECTED`). | `GET /api/v1/visits` | `VisitDetailScreen` |
| **VisitDetailScreen** | `visit_detail_screen.dart` | All Roles | Detail view of an individual visit: photo preview, coordinates, Google Maps intent, review reasons. | `GET /api/v1/visits/{id}` | External Google Maps |
| **PerformanceScreen** | `performance_screen.dart` | `EMPLOYEE` | Analytics across Daily, Weekly, and Monthly tabs; completion rates, trend graph, recent reviews. | `GET /api/v1/performance/employee/{id}/analytics` | `EmployeeTargetDetailScreen` |
| **EmployeeAttendanceScreen** | `employee_attendance_screen.dart` | `MANAGER`, `OWNER` | Real-time staff attendance roster showing who is active on duty, in/out timestamps. | `GET /api/v1/attendance/admin/roster` | `ProfileSettingsScreen` |
| **EmployeeLocationTrackingScreen**| `employee_location_tracking_screen.dart`| `MANAGER`, `OWNER` | Real-time map displaying last known GPS pings for all supervised field officers. | `GET /api/v1/attendance/admin/roster`, `GET /api/v1/admin/dashboard-stats` | External Google Maps |
| **ManagerDashboardScreen** | `manager_dashboard_screen.dart` | `MANAGER` | Verification queue for supervised agronomists; approve/reject buttons; "Add Customer" dialog. | `GET /api/v1/visits?status=PENDING`, `POST /api/v1/visits/{id}/verify`, `POST /api/v1/customers/` | `AccountDirectoryScreen`, `VisitDetailScreen`, `ChatListScreen` |
| **AdminDashboardScreen** | `admin_dashboard_screen.dart` | `MANAGER`, `OWNER` | Structural router delegating directly to `OwnerAdminDashboardScreen`. | None | `OwnerAdminDashboardScreen` |
| **OwnerAdminDashboardScreen** | `owner_admin_dashboard_screen.dart`| `OWNER`, `MANAGER` | Company-wide executive command center: live KPI cards, global verification queue, quotas, team list. | `GET /api/v1/admin/dashboard-stats`, `GET /api/v1/targets/quotas` | `SupervisionManagementScreen`, `AccountDirectoryScreen`, `ChatListScreen` |
| **SupervisionManagementScreen** | `supervision_management_screen.dart`| `OWNER` | Interface to reassign field agronomists between regional branch managers. | `GET /api/v1/users/supervision/list`, `POST /api/v1/users/supervision/transfer` | Back |
| **AccountDirectoryScreen** | `account_directory_screen.dart` | `MANAGER`, `OWNER` | Directory of created employee credentials. Credential editor, WhatsApp/SMS credential share sheet. | `GET /api/v1/users/created-accounts`, `PUT /api/v1/users/{id}/credentials` | Native Share Sheet |
| **ChatListScreen** | `chat_list_screen.dart` | All Roles | Overview of chatrooms: Company Announcements, Management Channel, and 1-on-1 Direct Chats. | `GET /api/v1/chat/rooms`, `GET /api/v1/chat/contacts` | `ChatConversationScreen` |
| **ChatConversationScreen** | `chat_conversation_screen.dart` | All Roles | Messaging thread with polling refresh. Supports text messaging and announcement broadcast. | `GET /api/v1/chat/rooms/{id}/messages`, `POST /api/v1/chat/rooms/{id}/messages` | Back |
| **ProfileSettingsScreen** | `profile_settings_screen.dart` | All Roles | User profile summary, designations, server status ping, password reset, and Sign Out button. | `GET /api/v1/users/me`, `POST /api/v1/auth/logout` | `PortalSelectionScreen` |

---

## 3. State Management & Data Architecture

PhytoDoctor uses a hybrid architectural pattern combining **Service-Oriented Architecture (SOA)** and the **Repository Pattern**:

```
+-------------------------------------------------------------------------------+
|                             FLUTTER PRESENTATION                              |
|   StatefulWidget & setState()  |  ChangeNotifier & ListenableBuilder          |
+-------------------------------------------------------------------------------+
                                      |
                                      v
+-------------------------------------------------------------------------------+
|                              REPOSITORY LAYER                                 |
|   VisitRepository (abstract)                                                  |
|   ├── RealVisitRepository (live http calls to FastAPI backend)                |
|   └── MockVisitRepository (isolated fallback for offline UI previews)         |
+-------------------------------------------------------------------------------+
         |                                              |
         v                                              v
+-------------------------------+             +---------------------------------+
|         SERVICE LAYER         |             |          STORAGE LAYER          |
|  - AuthService                |             |  - SqliteVisitDatabase          |
|  - AttendanceService          |             |  - LocalVisitQueue              |
|  - ChatService                |             |  - SecureStorageService         |
|  - LocationService            |             |  - PhotoStorageService          |
|  - AppUpdateService           |             |  - CloudinaryUploadService      |
|  - NativePlatformService      |             +---------------------------------+
+-------------------------------+                               |
         |                                                      v
         v                                            [ Android SQLite & Keystore ]
+-------------------------------+
|         NETWORKING            |
|  - http.Client                |
|  - Multi-candidate Probing    |
|  - Bearer Token Auth          |
+-------------------------------+
```

### Key Architectural Characteristics:
1. **No Heavy External State Framework:** The app relies on Flutter's built-in `StatefulWidget` and `setState` for screen-level reactivity, paired with `ChangeNotifier` in `OfflineSyncManager` and `LocalVisitQueue`.
2. **Encrypted Token Persistence:** Access and refresh tokens are stored using `FlutterSecureStorage` with Android `EncryptedSharedPreferences`.
3. **Multi-Host Candidate Probing:** In `auth_service.dart`, if the primary backend URL fails during development or cold-starts, the service probes a list of fallback endpoints (`10.0.2.2:8000`, local LAN IP) before declaring a network failure.

---

## 4. Reusable Widgets & Component Catalog

Located in `mobile/lib/presentation/widgets/`:

| Widget | Purpose | Key Properties |
|--------|---------|----------------|
| `CustomButton` | Standardized botanical green rounded button | `text`, `icon`, `isLoading`, `onPressed`, `height`, `backgroundColor` |
| `CustomTextField` | Form input with prefix icon and error states | `controller`, `labelText`, `hintText`, `obscureText`, `validator` |
| `PhytoDoctorLogo` | Brand logo rendering | `compactIconOnly`, `width`, `height` |
| `StateViews` | Loading, error, and empty states | `LoadingView`, `ErrorView`, `EmptyView`, `OfflineBanner` |
| `StatusBadge` | Visual pill badge for verification status | `status` (`PENDING` = amber, `VERIFIED` = green, `REJECTED` = crimson) |

---

## 5. Android Native Configuration & Permissions

Declared in `mobile/android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### Native Method Channel:
Channel name: `com.phytodoctor.fieldapp/native`  
Methods supported in `native_platform_service.dart`:
- `requestPermissions`: Prompts native Android OS runtime dialogs for Camera and Location.
- `checkPermissions`: Returns boolean map `{camera: bool, location: bool}`.
- `capturePhoto`: Invokes native hardware camera and returns absolute file path.
- `shareText`: Invokes native Android Intent chooser (WhatsApp, Gmail, SMS).

---

## 6. Frontend Discrepancies, Placeholders & Mock Findings

During static code inspection of the frontend, the following items were identified:
1. **Mock Data Repository in Production Path:** `mock_visit_repository.dart` exists in the repository. While `RealVisitRepository` is the active default, fallback logic in `app_config.dart` (`useMockDataWhenOffline = true`) could inadvertently present mock visits if an unhandled network error occurs.
2. **Hardcoded Fallback Quotas:** In `employee_dashboard_screen.dart` and `real_visit_repository.dart`, the daily quota falls back to `6` if the backend response does not contain an assigned target count.
3. **Simulated GPS Mode:** In `location_service.dart`, `getCurrentLocation` includes parameters `simulateLowAccuracy` and `simulateMock` which default to returning hardcoded Lahore coordinates (`31.5204° N, 74.3587° E`) when running in synthetic environments.
