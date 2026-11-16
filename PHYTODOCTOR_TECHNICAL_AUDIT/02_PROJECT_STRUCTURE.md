# PhytoDoctor Technical Audit: 02 - Project Structure

> **Target Directory:** `d:\Projects\VS Code\PhytoDoctor`  
> **Inspection Level:** Full recursive scan (Depth 5)  
> **Excluded Patterns:** `.git`, `node_modules`, `__pycache__`, `.dart_tool`, `build/`, `.gradle`, `.pub-cache`, `ios/`, `web/`, `windows/`, `linux/`, `macos/`, `.idea/`, `venv/`, `.venv/`

---

## 1. Complete Project Directory Tree

```
PhytoDoctor/
├── .github/
│   └── workflows/
│       ├── production-release.yml           # Automated release workflow (Backend test, Admin build, APK build)
│       └── render_keep_alive.yml            # Cron/manual keep-alive pinger for Render free tier
├── admin/                                   # React / Vite Web Admin Dashboard
│   ├── public/                              # Static public web assets
│   ├── src/                                 # React TypeScript application source
│   ├── package.json                         # Node.js dependencies and scripts
│   ├── tsconfig.json                        # TypeScript root configuration
│   └── vite.config.ts                       # Vite bundler configuration
├── backend/                                 # FastAPI Backend Service
│   ├── app/
│   │   ├── api/
│   │   │   └── v1/
│   │   │       ├── admin.py                 # Admin dashboard statistics & audit logs
│   │   │       ├── attendance.py            # Field staff clock-in/out and manager roster
│   │   │       ├── auth.py                  # Login, token refresh, logout, profile
│   │   │       ├── chat.py                  # Announcements, management, direct messaging
│   │   │       ├── customers.py             # Customer/farm registration & territory assignment
│   │   │       ├── employee.py              # Agronomist dashboard summary & visit counts
│   │   │       ├── media.py                 # Cloudinary upload authorization & photo confirmation
│   │   │       ├── performance.py           # Employee & team performance metrics & trends
│   │   │       ├── system.py                # App versioning, force-update config, APK download
│   │   │       ├── targets.py               # Quota targets (daily/weekly/monthly) CRUD
│   │   │       ├── users.py                 # User CRUD, credential management, supervision transfer
│   │   │       └── visits.py                # Visit submission, anti-fraud checks, verification
│   │   ├── core/
│   │   │   ├── config.py                    # Pydantic Settings (env vars, secrets, thresholds)
│   │   │   ├── database.py                  # SQLAlchemy async engine, session factory, Base
│   │   │   ├── deps.py                      # Bearer token validation & RBAC dependencies
│   │   │   ├── rate_limit.py                # In-memory login brute-force rate limiter
│   │   │   └── security.py                  # bcrypt hashing, JWT encode/decode, token generator
│   │   ├── models/
│   │   │   ├── __init__.py                  # Imports all models to register on Base.metadata
│   │   │   ├── app_version.py               # AppVersionConfig model
│   │   │   ├── attendance.py                # Attendance model
│   │   │   ├── audit.py                     # AuditEvent model
│   │   │   ├── chat.py                      # ChatRoom & ChatMessage models
│   │   │   ├── customer.py                  # Customer model
│   │   │   ├── refresh_token.py             # RefreshToken model
│   │   │   ├── target.py                    # EmployeeTarget model
│   │   │   ├── user.py                      # User model & UserRole enum
│   │   │   └── visit.py                     # FieldVisit model & VisitStatus enum
│   │   ├── schemas/
│   │   │   ├── admin.py                     # Pydantic schemas for admin stats & audit logs
│   │   │   ├── auth.py                      # LoginRequest, TokenResponse, UserSummary
│   │   │   ├── chat.py                      # Chat room & message request/response schemas
│   │   │   ├── customer.py                  # Customer create/response schemas
│   │   │   ├── media.py                     # Cloudinary upload auth & confirmation schemas
│   │   │   ├── performance.py               # Analytics, trends, team comparison schemas
│   │   │   ├── target.py                    # Target creation & pagination schemas
│   │   │   ├── user.py                      # User creation, credentials, supervision schemas
│   │   │   └── visit.py                     # VisitCreate, VisitResponse, VisitVerifyRequest
│   │   ├── services/
│   │   │   └── audit_service.py             # Helper to insert immutable AuditEvent records
│   │   ├── static/                          # Static file server directory (holds APK)
│   │   ├── main.py                          # FastAPI app entry point, CORS, router mounts
│   │   └── seed.py                          # Database seed script for initial user accounts
│   ├── scripts/                             # Server administration & database utilities
│   │   └── backup_restore.py                # SQLite backup, verification, and disaster drill
│   ├── tests/                               # Pytest test suite
│   │   ├── conftest.py                      # Test database engine & fixtures
│   │   ├── test_admin_dashboard_api.py      # Admin stats & audit log tests
│   │   ├── test_attendance.py               # Clock-in/out & roster tests
│   │   ├── test_auth_and_roles.py           # Login, portals, RBAC, password checks
│   │   ├── test_chat.py                     # Messaging & channel permissions tests
│   │   ├── test_cloudinary_integration.py   # Cloudinary auth & mock upload tests
│   │   ├── test_full_backend.py             # Integrated end-to-end backend test suite
│   │   ├── test_offline_sync_idempotency.py # UUID & photo idempotency tests
│   │   ├── test_system_version.py           # App versioning & force-update tests
│   │   ├── test_targets_and_performance.py  # Target calculation & trend tests
│   │   └── test_visit_workflow.py           # Visit submission & supervisor verification
│   ├── render.yaml                          # Render.com service configuration for backend
│   └── requirements.txt                     # Python pip dependencies
├── docs/                                    # Architectural specifications & handover notes
│   ├── ARCHITECTURE.md                      # Core system design document
│   ├── HANDOVER.md                          # Production handover documentation
│   ├── PROJECT_PLAN.md                      # Project roadmap & milestones
│   └── SYNCHRONIZATION.md                   # Offline synchronization technical specification
├── mobile/                                  # Flutter Android Mobile Application
│   ├── android/                             # Native Android configuration
│   │   └── app/
│   │       ├── build.gradle                 # Android build config (minSdk, targetSdk, package)
│   │       └── src/main/AndroidManifest.xml # Permissions (Camera, GPS, Internet, Storage)
│   ├── lib/
│   │   ├── core/
│   │   │   ├── config/
│   │   │   │   └── app_config.dart          # Environment config & dynamic compile-time API_URL
│   │   │   ├── models/
│   │   │   │   ├── attendance_model.dart    # Attendance status & roster data models
│   │   │   │   ├── chat_model.dart          # Chat room & message data models
│   │   │   │   ├── local_visit_model.dart   # SQLite row model for local visit drafts
│   │   │   │   ├── user_model.dart          # UserModel, CreatedAccountModel, role getters
│   │   │   │   └── visit_state.dart         # VisitSyncState enum
│   │   │   ├── services/
│   │   │   │   ├── app_update_service.dart  # In-app update check, version dialog, APK trigger
│   │   │   │   ├── attendance_service.dart  # Clock in/out and admin roster HTTP service
│   │   │   │   ├── auth_service.dart        # Login, token storage, portal validation
│   │   │   │   ├── chat_service.dart        # Chatrooms & messaging HTTP service
│   │   │   │   ├── location_service.dart    # GPS hardware location acquisition & mock check
│   │   │   │   ├── native_platform_service.dart # MethodChannel for native camera & sharing
│   │   │   │   └── share_service.dart       # Account credential sharing wrapper
│   │   │   ├── storage/
│   │   │   │   ├── cloudinary_upload_service.dart # Uploads photo to Cloudinary
│   │   │   │   ├── local_visit_queue.dart   # In-memory & SQLite visit enqueueing manager
│   │   │   │   ├── photo_storage_service.dart # Local file storage & pruning rules
│   │   │   │   ├── secure_storage_service.dart # Encrypted shared preferences for tokens
│   │   │   │   └── sqlite_visit_database.dart # Persistent SQLite database for offline visits
│   │   │   ├── sync/
│   │   │   │   └── offline_sync_manager.dart # Sync coordinator with exponential backoff
│   │   │   └── theme/
│   │   │       └── app_theme.dart           # PhytoDoctor design system colors, typography, styles
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       ├── mock_visit_repository.dart # Isolated mock repository for preview mode
│   │   │       ├── real_visit_repository.dart # HTTP repository calling live FastAPI endpoints
│   │   │       └── visit_repository.dart    # Abstract interface for visit repositories
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── account_directory_screen.dart # Supervised employee credentials & sharing
│   │   │   │   ├── admin_dashboard_screen.dart   # Thin wrapper delegating to owner dashboard
│   │   │   │   ├── camera_capture_screen.dart    # Native/flutter camera preview & shutter
│   │   │   │   ├── chat_conversation_screen.dart # 1-on-1 and announcement message thread
│   │   │   │   ├── chat_list_screen.dart         # List of accessible chatrooms
│   │   │   │   ├── employee_attendance_screen.dart # Staff attendance monitor screen
│   │   │   │   ├── employee_dashboard_screen.dart  # Field Agronomist Hub (metrics & actions)
│   │   │   │   ├── employee_location_tracking_screen.dart # Real-time field team map tracking
│   │   │   │   ├── employee_target_detail_screen.dart # Visit quota breakdown & admin reviews
│   │   │   │   ├── gps_acquisition_screen.dart   # GPS coordinate locking screen
│   │   │   │   ├── login_screen.dart             # Credentials input for employee or admin
│   │   │   │   ├── manager_dashboard_screen.dart # Verification queue & audit for managers
│   │   │   │   ├── owner_admin_dashboard_screen.dart # Full CEO command center
│   │   │   │   ├── performance_screen.dart       # Analytics, trend graphs, weekly/monthly tabs
│   │   │   │   ├── portal_selection_screen.dart  # Initial screen to pick Employee or Admin
│   │   │   │   ├── profile_settings_screen.dart  # User profile view and sign-out
│   │   │   │   ├── record_visit_screen.dart      # Multi-step visit data entry & evidence capture
│   │   │   │   ├── supervision_management_screen.dart # Transfer agronomists between managers
│   │   │   │   ├── visit_detail_screen.dart      # Detailed inspection view of photo & GPS
│   │   │   │   └── visit_history_screen.dart     # Chronological log of past submissions
│   │   │   └── widgets/
│   │   │       ├── custom_button.dart            # Standard branded button with states
│   │   │       ├── custom_text_field.dart        # Branded form input field with validation
│   │   │       ├── phyto_logo.dart               # Vector and asset logo component
│   │   │       ├── state_views.dart              # Offline banner, loading spinner, error cards
│   │   │       └── status_badge.dart             # PENDING, VERIFIED, REJECTED badge
│   │   └── main.dart                             # Flutter app entry point, session restoration
│   ├── test/                                     # Flutter test suite
│   │   ├── auth_flow_test.dart                   # Portal routing and authentication tests
│   │   ├── offline_sync_test.dart                # Local SQLite enqueueing and sync tests
│   │   └── visit_workflow_test.dart              # Record visit form & submission tests
│   └── pubspec.yaml                              # Flutter dependencies & assets declaration
├── scripts/                                      # Operational scripts
│   └── publish_update.py                         # Single-click APK build, tag, & Render deploy
├── Build_Production_APK.bat                      # Windows batch script to build release APK
├── Keep_Server_Awake.bat                         # Windows batch script for local endpoint ping
├── Launch_Emulator.bat                           # Script to boot Android emulator
├── render.yaml                                   # Root Render blueprint file (matches backend)
└── .gitignore                                    # Git exclusion rules
```

---

## 2. File Dictionary: Critical Modules

### 2.1. Backend Core & Configuration

| File Path | Primary Responsibilities | Key Dependencies | Dependent Modules |
|-----------|--------------------------|------------------|-------------------|
| `backend/app/main.py` | FastAPI instantiation, lifespan table creation, seed invocation, CORS setup, router mounting | `fastapi`, `sqlalchemy`, `app.api.v1.*`, `app.models` | ASGI runner (`uvicorn`), Render deployment |
| `backend/app/core/config.py` | Pydantic BaseSettings: loads environment variables (`DATABASE_URL`, `SECRET_KEY`, Cloudinary credentials) | `pydantic-settings` | All routers, `security.py`, `database.py` |
| `backend/app/core/database.py` | Configures async SQLAlchemy engine and async session maker (`get_db`) | `sqlalchemy.ext.asyncio`, `aiosqlite` | All API routes, `deps.py`, `seed.py` |
| `backend/app/core/security.py` | Password hashing (bcrypt), JWT creation/decoding, refresh token hashing | `bcrypt`, `pyjwt`, `secrets`, `hashlib` | `auth.py`, `deps.py`, `users.py` |
| `backend/app/core/deps.py` | FastAPI dependencies: `get_current_user`, `require_roles`, `require_admin`, `require_owner` | `fastapi.security`, `app.core.security`, `app.models.user` | All protected API routers |
| `backend/app/core/rate_limit.py` | In-memory IP/identifier brute force tracking (locks after 5 failed attempts for 15 mins) | `time`, `collections` | `auth.py` |
| `backend/app/seed.py` | Idempotent initial user provisioning (CEO, Admin, 3 Employees) with passwords and manager links | `app.models.*`, `app.core.security` | `main.py` lifespan |

### 2.2. Backend Models & Database Entities

| File Path | Primary Entities | Key Fields | Relationships |
|-----------|------------------|------------|---------------|
| `backend/app/models/user.py` | `User`, `UserRole` | `id`, `email`, `username`, `role`, `manager_id`, `created_by_id`, `assigned_password` | Self-referential `manager` / `subordinates`, `visits`, `targets` |
| `backend/app/models/visit.py` | `FieldVisit`, `VisitStatus` | `id`, `employee_id`, `client_name`, `latitude`, `longitude`, `photo_asset_id`, `status`, `review_signals` | `employee` (`User`), `reviewer` (`User`) |
| `backend/app/models/target.py` | `EmployeeTarget`, `TargetPeriod` | `id`, `employee_id`, `target_count` (def: 6), `period_type`, `start_date`, `end_date` | `employee` (`User`), `creator` (`User`) |
| `backend/app/models/customer.py` | `Customer`, `CustomerType` | `id`, `name`, `customer_type`, `territory`, `assigned_employee_id`, `created_by_id` | `assigned_employee` (`User`), `creator` (`User`) |
| `backend/app/models/attendance.py` | `Attendance` | `id`, `user_id`, `date`, `clock_in_time`, `clock_out_time`, `is_active` | `user` (`User`) |
| `backend/app/models/chat.py` | `ChatRoom`, `ChatMessage` | `room_type`, `participant_1_id`, `participant_2_id`, `sender_id`, `content` | `messages` (`ChatMessage`), `room` (`ChatRoom`) |
| `backend/app/models/audit.py` | `AuditEvent` | `id`, `actor_id`, `actor_role`, `action`, `affected_record_id`, `metadata_json` | `actor` (`User`) |
| `backend/app/models/refresh_token.py` | `RefreshToken` | `id`, `user_id`, `token_hash`, `expires_at`, `is_revoked` | `user` (`User`) |
| `backend/app/models/app_version.py` | `AppVersionConfig` | `latest_version`, `latest_build_number`, `min_required_build_number`, `force_update` | Singleton table |

### 2.3. Frontend Core Services & Architecture

| File Path | Primary Function | Key Features | Dependent Screens |
|-----------|------------------|--------------|-------------------|
| `mobile/lib/core/config/app_config.dart` | Build configuration | Compile-time `--dart-define=API_URL` override with Render cloud fallback | All services and repositories |
| `mobile/lib/core/services/auth_service.dart` | Authentication manager | Multi-host candidate probing, portal role enforcement, session storage | `login_screen.dart`, `portal_selection_screen.dart` |
| `mobile/lib/core/storage/sqlite_visit_database.dart` | Offline storage | Persistent local table `local_field_visits`, reset stale in-flight sync states | `local_visit_queue.dart`, `offline_sync_manager.dart` |
| `mobile/lib/core/sync/offline_sync_manager.dart` | Sync orchestrator | Exponential backoff ($2^n$ sec), concurrency debounce lock, storage health check | `employee_dashboard_screen.dart` |
| `mobile/lib/core/storage/cloudinary_upload_service.dart` | Media uploader | Two-step signed authorization or direct multipart upload, thumbnail generation | `record_visit_screen.dart` |
| `mobile/lib/core/services/app_update_service.dart` | Version guard | Pre-login version probe against `/api/v1/system/version`, modal force-update dialog | All main dashboard screens |
| `mobile/lib/data/repositories/real_visit_repository.dart` | Live API access | HTTP client calling `/api/v1/employee/dashboard-summary`, `/api/v1/visits` | `employee_dashboard_screen.dart`, `performance_screen.dart` |

---

## 3. Excluded Directories and Rationale

The following directories were detected in the filesystem but excluded from static code inspection:
- `.git/`: Version control metadata.
- `mobile/build/` and `mobile/.dart_tool/`: Generated Flutter/Dart compilation artifacts.
- `mobile/android/.gradle/`: Gradle build cache.
- `backend/__pycache__/` and `.pytest_cache/`: Python bytecode and test run cache.
- `admin/node_modules/` and `admin/dist/`: NPM packages and compiled web bundle.
- OS-specific Flutter folders (`ios/`, `web/`, `windows/`, `linux/`, `macos/`): PhytoDoctor is exclusively targeted and configured for Android field devices.
