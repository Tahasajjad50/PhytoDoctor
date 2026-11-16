# PhytoDoctor Technical Audit: 07 - Complete API Reference

> **API Base URL:** `https://phytodoctor-api.onrender.com`  
> **API Version Prefix:** `/api/v1`  
> **Protocol:** HTTPS / JSON REST  
> **Total Endpoints Documented:** 38 endpoints across 12 feature domains

---

## 1. System Health & Root Endpoints

### 1.1. `GET /`
- **File / Handler:** `app/main.py:root`
- **Authentication:** Public (None)
- **Role Requirement:** None
- **Purpose:** Service identification and runtime environment verification.
- **Response Structure (200 OK):**
  ```json
  {
    "app": "Phyto Doctor Field Tracking API",
    "version": "1.0.0",
    "environment": "production",
    "status": "online"
  }
  ```

### 1.2. `GET /api/v1/health`
- **File / Handler:** `app/main.py:health_check`
- **Authentication:** Public (None)
- **Role Requirement:** None
- **Purpose:** Keep-alive ping target and database connection health check (`SELECT 1`).
- **Response Structure (200 OK):**
  ```json
  {
    "status": "healthy",
    "database_connected": true,
    "utc_timestamp": "2026-11-16T02:30:00.000000Z",
    "version": "1.0.0"
  }
  ```

---

## 2. Authentication Domain (`/api/v1/auth`)

### 2.1. `POST /api/v1/auth/login`
- **File / Handler:** `app/api/v1/auth.py:login`
- **Authentication:** Public (None)
- **Rate Limiting:** In-memory check (5 failed attempts locks identifier for 15 minutes)
- **Request Body (`LoginRequest`):**
  ```json
  {
    "username_or_email": "emp.zain",
    "password": "Emp@Password123",
    "portal": "employee"
  }
  ```
- **Business Logic:**
  - Case-insensitive lookup by `username` OR `email`.
  - Verifies bcrypt hashed password.
  - Validates `user.is_active`.
  - Enforces portal authorization: if `portal="admin"`, requires `role in ['OWNER', 'MANAGER']`.
  - Generates 24-hour HS256 access token.
  - Generates high-entropy 64-character refresh token and stores SHA-256 hash in `refresh_tokens`.
- **Response Structure (200 OK):**
  ```json
  {
    "access_token": "eyJhbGciOi...",
    "refresh_token": "uY7x_...",
    "token_type": "bearer",
    "expires_in_seconds": 86400,
    "user": {
      "id": "c138f6d8-...",
      "full_name": "Zain Ul Abideen",
      "email": "zain@phytodoctor.com",
      "username": "emp.zain",
      "role": "EMPLOYEE",
      "is_active": true,
      "manager_id": "b248e5c7-...",
      "created_at": "2026-10-15T08:00:00Z"
    }
  }
  ```
- **Status Codes:** `200 OK`, `401 Unauthorized`, `403 Forbidden` (deactivated/wrong portal), `429 Too Many Requests`.

### 2.2. `POST /api/v1/auth/refresh`
- **File / Handler:** `app/api/v1/auth.py:refresh_access_token`
- **Authentication:** Public (Accepts opaque refresh token string)
- **Request Body (`RefreshTokenRequest`):** `{"refresh_token": "string"}`
- **Business Logic:**
  - Computes SHA-256 hash of submitted token; looks up unexpired, unrevoked record.
  - Revokes matched refresh token (token rotation).
  - Issues fresh access token and fresh refresh token.
- **Response Structure (200 OK):** Same as `TokenResponse`.

### 2.3. `POST /api/v1/auth/logout`
- **File / Handler:** `app/api/v1/auth.py:logout`
- **Authentication:** Bearer JWT required
- **Request Body (`LogoutRequest`):** `{"refresh_token": "optional_string"}`
- **Business Logic:** Revokes submitted refresh token and logs `LOGOUT` audit event.

### 2.4. `GET /api/v1/auth/me`
- **File / Handler:** `app/api/v1/auth.py:get_my_profile`
- **Authentication:** Bearer JWT required
- **Response Structure (200 OK):** `UserSummary` object.

---

## 3. Field Visits Domain (`/api/v1/visits`)

### 3.1. `GET /api/v1/visits/evidence-policy`
- **File / Handler:** `app/api/v1/visits.py:get_evidence_policy`
- **Authentication:** Public (None)
- **Response (200 OK):** Evidence transparency disclosure stating no background tracking is performed; GPS threshold is 50.0m.

### 3.2. `POST /api/v1/visits`
- **File / Handler:** `app/api/v1/visits.py:create_visit`
- **Authentication:** Bearer JWT required (All roles)
- **Request Body (`VisitCreate`):**
  ```json
  {
    "id": "e4b6c8a2-...",
    "client_name": "Chaudhry Farm & Seeds",
    "client_phone": "03001234567",
    "notes": "Severe whitefly infestation noticed in quadrant B.",
    "latitude": 30.1575,
    "longitude": 71.5249,
    "gps_accuracy": 12.4,
    "is_mock_location": false,
    "device_capture_time": "2026-11-16T02:15:00Z",
    "photo_asset_id": "ASSET_1731723300000",
    "photo_url": "https://res.cloudinary.com/..."
  }
  ```
- **Business Logic:**
  - Idempotency check: If `id` already exists for current user, returns existing record (`200 OK`).
  - Immutability check: If `photo_asset_id` already exists, rejects with `409 Conflict`.
  - Fraud checks: Flags for supervisor review if accuracy > 50m, mock location is true, clock drift > 5m future, or clock drift > 24h past.
- **Response Structure (201 Created):** Full `VisitResponse` entity with `status="PENDING"`.

### 3.3. `GET /api/v1/visits`
- **File / Handler:** `app/api/v1/visits.py:list_visits`
- **Authentication:** Bearer JWT required
- **Query Parameters:** `skip` (int), `limit` (int), `status` (PENDING/VERIFIED/REJECTED), `is_flagged` (bool), `employee_id` (str)
- **Scoping Logic:**
  - `EMPLOYEE`: Filtered strictly to `employee_id == current_user.id`.
  - `MANAGER`: Filtered to `employee_id in (current_user.id + subordinates)`.
  - `OWNER`: Full company visibility.

### 3.4. `GET /api/v1/visits/{visit_id}`
- **File / Handler:** `app/api/v1/visits.py:get_visit_details`
- **Authentication:** Bearer JWT required (Role-scoped access)
- **Response Structure (200 OK):** `VisitResponse`.

### 3.5. `POST /api/v1/visits/{visit_id}/verify`
- **File / Handler:** `app/api/v1/visits.py:verify_or_reject_visit`
- **Authentication:** Bearer JWT (`require_admin`: `OWNER`, `MANAGER`)
- **Request Body (`VisitVerifyRequest`):**
  ```json
  {
    "status": "VERIFIED",
    "review_reason": "GPS coordinates and crop leaf photo verified on site."
  }
  ```
- **Business Logic:** Updates visit status to `VERIFIED` or `REJECTED`, stores reviewer ID and timestamp, and writes an immutable `AuditEvent`.

---

## 4. Quotas & Target Management (`/api/v1/targets`)

### 4.1. `POST /api/v1/targets/`
- **File / Handler:** `app/api/v1/targets.py:create_target`
- **Role:** `OWNER`, `MANAGER` (Managers restricted to their supervised subordinates)
- **Request Body (`TargetCreate`):** `employee_id`, `target_count` (int, 1-1000), `period_type` (`DAILY`/`WEEKLY`/`MONTHLY`), `start_date`, `end_date`.

### 4.2. `POST /api/v1/targets/batch`
- **File / Handler:** `app/api/v1/targets.py:create_batch_targets`
- **Role:** `OWNER`, `MANAGER` (Managers restricted to own team members)
- **Request Body (`BatchTargetCreate`):** `employee_ids` (List[str]), `target_count`, `period_type`, `start_date`, `end_date`.

### 4.3. `GET /api/v1/targets/quotas`
- **File / Handler:** `app/api/v1/targets.py:get_company_quotas`
- **Role:** Authenticated
- **Response Structure (200 OK):** Returns company-wide defaults (`{"daily_visits": 6, "monthly_sales_pkr": 500000, "month": "Current Month"}`).

---

## 5. Performance & Analytics (`/api/v1/performance`)

### 5.1. `GET /api/v1/performance/employee/{employee_id}/summary`
- **File / Handler:** `app/api/v1/performance.py:get_employee_performance_summary`
- **Query Parameter:** `period` (`DAILY`, `WEEKLY`, `MONTHLY`)
- **Business Rule:** Only `VERIFIED` visits count towards completed targets; drafts and pending visits do not inflate progress.

### 5.2. `GET /api/v1/performance/employee/{employee_id}/analytics`
- **File / Handler:** `app/api/v1/performance.py:get_employee_performance_analytics`
- **Query Parameters:** `timeframe` (`DAILY`, `WEEKLY`, `MONTHLY`), `as_of_date` (optional date)
- **Response Structure (200 OK):**
  - Aggregated metrics: `target_visits`, `submitted_visits`, `verified_visits`, `remaining_visits`, `completion_percentage`.
  - `trend_points`: List of date-by-date target vs verified completion stats.
  - `recent_reviews`: Recent supervisor feedback items with audit reasons.

### 5.3. `GET /api/v1/performance/team-comparison`
- **File / Handler:** `app/api/v1/performance.py:get_team_comparison`
- **Role:** `OWNER`, `MANAGER`
- **Query Parameters:** `timeframe`, `date_from`, `date_to`
- **Response:** Ranks team members by completion percentage descending.

### 5.4. `GET /api/v1/performance/company-overview`
- **File / Handler:** `app/api/v1/performance.py:get_company_performance_overview`
- **Role:** `OWNER`, `MANAGER`
- **Response:** High-level company statistics (active workforce, total visits logged today, company-wide verification rate).

---

## 6. User Management & Directory (`/api/v1/users`)

### 6.1. `GET /api/v1/users/created-accounts`
- **File / Handler:** `app/api/v1/users.py:get_created_accounts`
- **Role:** `OWNER`, `MANAGER`
- **Response:** List of subordinate accounts including cleartext `assigned_password` for initial dispatch.

### 6.2. `PUT /api/v1/users/{user_id}/credentials`
- **File / Handler:** `app/api/v1/users.py:update_account_credentials`
- **Role:** `OWNER` (Any user), `MANAGER` (Only employees they created or supervise)
- **Request Body (`UpdateCredentialsRequest`):** Allows updating full name, phone, designation, username, email, active status, or password.

### 6.3. `GET /api/v1/users/supervision/list`
- **File / Handler:** `app/api/v1/users.py:get_supervision_list`
- **Role:** `OWNER`
- **Response:** List of all employees, current supervisors, and available managers for transfer.

### 6.4. `POST /api/v1/users/supervision/transfer`
- **File / Handler:** `app/api/v1/users.py:transfer_supervision`
- **Role:** `OWNER` only
- **Request Body (`TransferSupervisorRequest`):** `{"employee_id": "...", "new_manager_id": "..."}`.

---

## 7. Customer & Territory Management (`/api/v1/customers`)

### 7.1. `POST /api/v1/customers/`
- **File / Handler:** `app/api/v1/customers.py:create_customer`
- **Role:** `OWNER`, `MANAGER`
- **Business Logic:** If `assigned_employee_id` is omitted, automatically finds the nearest active agronomist whose name or designation matches the territory string.

### 7.2. `GET /api/v1/customers/`
- **File / Handler:** `app/api/v1/customers.py:list_customers`
- **Scoping:** Employees see customers in their territory or assigned to them; managers/owners see all.

---

## 8. Attendance & Shift Tracking (`/api/v1/attendance`)

### 8.1. `POST /api/v1/attendance/clock-in`
- **File / Handler:** `app/api/v1/attendance.py:clock_in`
- **Role:** `EMPLOYEE` only
- **Business Logic:** Marks attendance record for current date as `is_active=True`, logs UTC clock-in time.

### 8.2. `POST /api/v1/attendance/clock-out`
- **File / Handler:** `app/api/v1/attendance.py:clock_out`
- **Role:** `EMPLOYEE` only
- **Business Logic:** Sets `is_active=False`, logs UTC clock-out time.

### 8.3. `GET /api/v1/attendance/admin/roster`
- **File / Handler:** `app/api/v1/attendance.py:get_admin_attendance_roster`
- **Role:** `OWNER`, `MANAGER`
- **Response:** Full roster of agronomists, their current live status (On Duty / Off Duty), and clock in/out times.

---

## 9. Media & Cloudinary Storage (`/api/v1/media`)

### 9.1. `POST /api/v1/media/visits/{visit_id}/photo`
- **File / Handler:** `app/api/v1/media.py:upload_visit_photo`
- **Authentication:** Bearer JWT required
- **Request:** Multipart form upload (`file`). Max 10MB; JPG/PNG/WEBP.
- **Business Logic:** Uploads file to Cloudinary folder `phytodoctor/visits`, updates `FieldVisit` record with `photo_url`, `photo_asset_id`, and `photo_metadata`.

---

## 10. Chat & Communications (`/api/v1/chat`)

### 10.1. `GET /api/v1/chat/rooms` & `POST /api/v1/chat/rooms`
- **File / Handler:** `app/api/v1/chat.py`
- **Types:** `ANNOUNCEMENT` (CEO Broadcast), `MANAGEMENT` (Leadership Channel), `DIRECT` (1-on-1).

### 10.2. `GET /api/v1/chat/rooms/{room_id}/messages` & `POST /api/v1/chat/rooms/{room_id}/messages`
- **File / Handler:** `app/api/v1/chat.py`
- **Polling Parameter:** Accepts `?after=<iso_timestamp>` for bandwidth-efficient polling.

---

## 11. System Version & Updates (`/api/v1/system`)

### 11.1. `GET /api/v1/system/version`
- **File / Handler:** `app/api/v1/system.py:get_app_version`
- **Authentication:** Public (None)
- **Response Structure (200 OK):**
  ```json
  {
    "latest_version": "1.0.0",
    "latest_build_number": 1,
    "min_required_build_number": 1,
    "force_update": true,
    "title": "Update Required",
    "message": "A newer version of PhytoDoctor is available.",
    "download_url": "https://phytodoctor-api.onrender.com/api/v1/system/download-apk"
  }
  ```

### 11.2. `GET /api/v1/system/download-apk`
- **File / Handler:** `app/api/v1/system.py:download_apk`
- **Authentication:** Public (None)
- **Response:** Direct binary stream (`application/vnd.android.package-archive`) serving `PhytoDoctor-release.apk`.
