# 03 – OWNER (CEO) ROLE TEST RESULTS

**Test Account:** `MehmoodAyyaz` (CEO / Managing Director)  
**Portal:** Administrative Web & Mobile Executive Portal (`/admin`)  
**Security Scoping:** Full Organization Visibility (`OWNER`)  

---

## 1. Authentication & Session Scoping
- **Login Credentials:** Authenticated successfully via `POST /api/v1/auth/login` with `portal: 'admin'`.
- **Portal Boundary Enforcement:** Attempting to authenticate as `MehmoodAyyaz` on `portal: 'employee'` correctly yields `HTTP 403 Forbidden: Incorrect portal. Please use the Admin / Supervisor Login portal.`
- **JWT Payload Verification:** Decoded token contains `"role": "OWNER"`, with an expiration window of 24 hours.

---

## 2. Corporate KPIs & Dashboard Stats
- **Endpoint:** `GET /api/v1/admin/dashboard-stats`
- **Response Received:**
  ```json
  {
    "status": "success",
    "admin_name": "Mehmood Ayyaz",
    "role": "OWNER",
    "active_employees": 1,
    "total_employees": 3,
    "today_field_visits": 1,
    "pending_verifications": 0,
    "verified_visits": 1,
    "verified_percentage": 100.0,
    "total_sales_value": 0
  }
  ```
- **Verification:** CEO sees aggregate stats across all regions and employees.

---

## 3. Reporting Hierarchy & Supervision Transfer
- **Endpoint:** `POST /api/v1/users/supervision/transfer`
- **Test Execution:** Forcefully transferred `emp.zain` from regional manager `admin.tahasajjad` to alternate supervisor and back.
- **Audit Verification:** Audit event `SUPERVISOR_TRANSFERRED` recorded in `audit_events` with actor `MehmoodAyyaz`.
- **Verdict:** **PASS**.

---

## 4. Credential Provisioning & Plaintext Security
- **Feature:** Provisioning new regional managers and field employees.
- **Finding & Fix:** The credential sharing text previously appended `Server Address: https://phytodoctor-api.onrender.com`. This was permanently removed in `owner_admin_dashboard_screen.dart:1015`.
- **Verdict:** **PASS**.
