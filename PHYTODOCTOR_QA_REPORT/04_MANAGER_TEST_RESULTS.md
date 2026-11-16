# 04 – MANAGER (REGIONAL ADMIN) ROLE TEST RESULTS

**Test Account:** `admin.tahasajjad` (Regional Manager)  
**Assigned Territory:** Punjab Field Team  
**Portal:** Admin Portal (`portal: 'admin'`)  
**Security Scoping:** Restricted to supervised team (`manager_id == user.id`)  

---

## 1. Authentication & Team Scoping
- **Login:** Successfully authenticated via `POST /api/v1/auth/login`.
- **Scoping Verification:**
  - Manager only receives field visits from employees where `FieldVisit.employee_id.in_(team_subquery)`.
  - Calling `GET /api/v1/visits` returns only visits from supervised agronomists (`emp.zain`, etc.).

---

## 2. Verification Queue & Inspection
- **Bug Fixed (PHY-QA-01):** Screen previously rendered a grey container when pending visits were returned due to null type cast exceptions on `distance_to_shop` and `officer`.
- **Retest Result:** Visit card renders with client name, officer name, capture timestamp, and real-time GPS coordinates.
- **Location Verification:** "Check Location now" launches Google Maps URL with exact coordinates.

---

## 3. Verification Approval / Rejection Workflow
- **Bug Fixed (PHY-QA-02):** `_verifyVisit()` previously sent `{"decision": "VERIFIED"}` which caused HTTP 422.
- **Retest Result:** Approval sends `{"status": "VERIFIED", "review_reason": "Verified on-site by supervisor"}`.
- **Status Change:** Visit status transitioned from `PENDING` -> `VERIFIED`.
- **Quota Impact:** Employee's verified count immediately increased from 0 to 1, and remaining visits decreased from 6 to 5.

---

## 4. Supervised Staff Roster
- **Live Integration:** `manager_dashboard_screen.dart` now loads the real roster from `GET /api/v1/attendance/admin/roster`.
- **Display:** Displays each supervised employee with `@username`, designation, and active duty badge (**ON DUTY** / **OFFLINE**).
- **History Link:** Tapping any agronomist opens their individual `VisitHistoryScreen`.
- **Verdict:** **PASS**.
