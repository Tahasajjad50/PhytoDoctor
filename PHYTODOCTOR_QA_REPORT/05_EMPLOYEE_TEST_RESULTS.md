# 05 – EMPLOYEE (FIELD AGRONOMIST) TEST RESULTS

**Test Account:** `emp.zain` (Field Agronomist)  
**Portal:** Field Employee Mobile App (`portal: 'employee'`)  
**Assigned Manager:** `admin.tahasajjad`  

---

## 1. Authentication & Security Lockout
- **Login:** Authenticated successfully via `POST /api/v1/auth/login`.
- **Security Lockout Verification (Image 1):**
  - Deliberately entered incorrect password 5 times.
  - Server returned `HTTP 429 Too Many Requests: Too many failed login attempts. Account temporarily locked for 15 minute(s).`
  - Account lockout verified to clear after the cooldown window.

---

## 2. Attendance Tracking (Clock-in / Clock-out)
- **Clock-In Endpoint:** `POST /api/v1/attendance/clock-in`
- **Result:** `{"is_active": true, "clock_in_time": "2026-11-16T00:30:00Z", "message": "Marked as Active (Clocked In)."}`
- **Roster Reflection:** Manager portal immediately marked `emp.zain` as **ON DUTY**.

---

## 3. Field Visit Submission
- **Capture Simulation:** Submitted visit for client `Chaudhry Farm Multan` with GPS: `(30.1575, 71.5249)`, accuracy `8.5m`, asset ID `PH_ZAIN_20261116_01`.
- **Initial Status:** Returned `status: "PENDING"`, `is_flagged_for_review: false`.
- **Supervisor Audit:** After manager approved, status transitioned to `VERIFIED`.

---

## 4. Quota Achievement & Target Breakdown
- **Target Progress Card:** Accurately calculated `1 / 6 Visits` (16.7% completed, 5 remaining).
- **Navigation:** Tapping the 6 Visits card opens `EmployeeTargetDetailScreen` showing:
  - Daily assigned quota: 6
  - Completed today: 1
  - Verified on site: 1
  - Remaining: 5
  - Filter tabs: All, Admin Updated, Pending, Remaining.
- **Verdict:** **PASS**.
