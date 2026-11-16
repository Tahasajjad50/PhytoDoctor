# PhytoDoctor Technical Audit: 16 - Technical Issues & Risk Register

> **Audit Objective:** Complete, prioritized register of architectural defects, security vulnerabilities, and operational risks identified during static code inspection.  
> **Note:** Strictly documentation and risk analysis. No application code has been modified.

---

## 1. Prioritized Risk Matrix (Likelihood × Impact)

```
       ▲
       │   HIGH IMPACT               HIGH IMPACT               CRITICAL IMPACT
       │   [SEC-02] Default JWT      [SEC-01] Cleartext Pwd    [DB-01] Ephemeral DB
IMPACT │   [DB-02] No Migrations     [INF-01] Render Sleep     [SEC-03] CORS Wildcard
       │   ────────────────────────────────────────────────────────────────────
       │   MED IMPACT                MED IMPACT                HIGH IMPACT
       │   [FE-01] SQLite Cache      [FE-02] Mock Repo Path    [SEC-04] Memory RateLimit
       │   [BE-01] PKT Midnight      [SEC-05] No MFA           [INF-02] Large APK Stream
       │
       └────────────────────────────────────────────────────────────────────────►
                  LOW LIKELIHOOD           MEDIUM LIKELIHOOD           HIGH LIKELIHOOD
```

---

## 2. Critical Severity Risks (`CRITICAL`)

### [DB-01] Ephemeral SQLite Database on Render.com Free Tier
- **Category:** Database / Infrastructure
- **Evidence:** `render.yaml` sets `DATABASE_URL: sqlite+aiosqlite:///./phyto_doctor.db`; Render service plan is `free`.
- **Problem Analysis:** Render free tier instances operate on stateless, ephemeral virtual machines. Any redeployment, git push, manual service restart, or container relocation completely wipes the filesystem.
- **Production Impact:** All production user accounts, historical field visit records, GPS telemetry, supervisor audit logs, and shift attendances are permanently deleted on every deploy.
- **Recommended Remediation:** Provision a managed PostgreSQL database (e.g., Render Managed PostgreSQL, Supabase, or AWS RDS) and update `DATABASE_URL` to `postgresql+asyncpg://...`.

---

### [SEC-01] Plaintext Password Storage in `users.assigned_password`
- **Category:** Application Security / Compliance
- **Evidence:** `backend/app/models/user.py`:
  ```python
  assigned_password: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
  ```
  `backend/app/api/v1/users.py:update_account_credentials`:
  ```python
  target_user.assigned_password = req.password
  ```
- **Problem Analysis:** When a supervisor creates or updates an agronomist account, the plaintext password is stored in `assigned_password` to enable WhatsApp sharing via `account_directory_screen.dart`.
- **Production Impact:** Any SQL injection vulnerability, database backup leak, or unauthorized read access compromises the credentials of every user in the company.
- **Recommended Remediation:** Eliminate `assigned_password`. Implement secure one-time activation links or cryptographically signed password setup tokens dispatched directly to the employee's phone number.

---

### [SEC-03] Permissive CORS Wildcard (`"*"`) with Credentials
- **Category:** Application Security
- **Evidence:** `backend/app/main.py`:
  ```python
  app.add_middleware(
      CORSMiddleware,
      allow_origins=settings.BACKEND_CORS_ORIGINS, # ["*"]
      allow_credentials=True,
      allow_methods=["*"],
      allow_headers=["*"],
  )
  ```
- **Problem Analysis:** `allow_origins=["*"]` combined with `allow_credentials=True` allows arbitrary third-party web domains to make cross-origin authenticated requests to the backend if the victim has a valid session.
- **Recommended Remediation:** Restrict allowed CORS origins strictly to trusted administrative web domains (`https://admin.phytodoctor.pk`).

---

## 3. High Severity Risks (`HIGH`)

### [SEC-02] Hardcoded Fallback JWT Secret Key
- **Category:** Security / Cryptography
- **Evidence:** `backend/app/core/config.py`:
  ```python
  SECRET_KEY: str = "phyto_doctor_jwt_secret_key_production_override_required_2026"
  ```
- **Problem Analysis:** If the `SECRET_KEY` environment variable is not explicitly injected into the Render dashboard, tokens are signed using a publicly visible secret.
- **Production Impact:** Anyone inspecting the open-source repository can forge valid JWT tokens with `role="OWNER"` and take complete administrative control of the system.
- **Recommended Remediation:** Enforce a startup check in `main.py` that raises an exception if `ENVIRONMENT == "production"` and `SECRET_KEY` equals the default fallback string.

---

### [DB-02] Absence of Database Migration Tracking (No Alembic)
- **Category:** Database Architecture
- **Evidence:** Tables are created solely via `Base.metadata.create_all` in `main.py`. No migration scripts exist in `backend/alembic/versions/`.
- **Problem Analysis:** `create_all` only creates *new* tables; it never adds new columns, alters types, or updates constraints on existing tables.
- **Production Impact:** Any future schema refactoring requires manual raw SQL execution or dropping tables and losing data.
- **Recommended Remediation:** Initialize Alembic (`alembic init alembic`) and generate baseline migration revisions.

---

### [INF-01] Inactivity Sleeping & 40-Second Cold Starts on Render Free Tier
- **Category:** Infrastructure / User Experience
- **Evidence:** Render Free tier spins down after 15 minutes of zero traffic. Keep-alive cron jobs in `.github/workflows/render_keep_alive.yml` are commented out.
- **Problem Analysis:** Field agronomists initiating their first visit of the day experience request timeouts because the server takes 30-50 seconds to boot from cold.
- **Production Impact:** High rate of `SocketException: Connection timed out` on mobile handhelds.
- **Recommended Remediation:** Activate the keep-alive workflow cron or upgrade the Render web service to an "Individual" or "Starter" paid tier ($7/month) to disable spinning down.

---

## 4. Medium Severity Risks (`MEDIUM`)

### [FE-01] Local SQLite Database Relies on In-Memory Cache
- **Category:** Mobile Offline Storage
- **Evidence:** `mobile/lib/core/storage/sqlite_visit_database.dart`:
  ```python
  final Map<String, Map<String, dynamic>> _tableRows = {};
  ```
- **Problem Analysis:** `sqlite_visit_database.dart` contains SQL table creation definitions, but query reads and writes operate against `_tableRows` in memory rather than disk-backed `sqflite`.
- **Production Impact:** If an agronomist logs visits offline and the Android OS terminates the process due to low RAM, queued visits may be lost before synchronization.
- **Recommended Remediation:** Connect `sqlite_visit_database.dart` directly to `sqflite` so records are physically committed to flash memory.

---

### [FE-02] Mock Repository Fallback in Production Path
- **Category:** Frontend Data Integrity
- **Evidence:** `AppConfig.useMockDataWhenOffline = true` and presence of `mock_visit_repository.dart`.
- **Problem Analysis:** If an unexpected exception occurs during offline fallback, the app could instantiate `MockVisitRepository`, showing synthetic zero counts or fake data.
- **Recommended Remediation:** Remove `mock_visit_repository.dart` from release builds or wrap in `#if DEBUG` guards.

---

### [SEC-04] In-Memory Rate Limiting Not Distributed
- **Category:** Security / Scalability
- **Evidence:** `backend/app/core/rate_limit.py:LoginRateLimiter` uses in-memory dictionary.
- **Problem Analysis:** Tracking failed logins in process memory means restarting the process resets the lockouts, and multi-worker Uvicorn setups do not share lockout state.
- **Recommended Remediation:** Use Redis or database-backed rate limiting.

---

### [BE-01] Timezone Edge Cases Around PKT Midnight
- **Category:** Backend Business Logic
- **Evidence:** `PKT_OFFSET = timezone(timedelta(hours=5))` defined in `performance.py`, but database queries compare against UTC boundaries without full localized shifting in some trend queries.
- **Problem Analysis:** Visits submitted between 12:00 AM and 5:00 AM PKT fall on the previous calendar date in UTC, potentially misattributing daily quota progress.
- **Recommended Remediation:** Explicitly convert device capture timestamps to `Asia/Karachi` before aggregating by day.

---

### [INF-02] Serving Large Release APK Binaries via Web Server
- **Category:** Performance / Resource Exhaustion
- **Evidence:** `GET /api/v1/system/download-apk` streams a ~45MB APK file directly from the Uvicorn process.
- **Problem Analysis:** If 20 field agronomists download the update simultaneously, the single Render container process can exhaust its 512MB RAM limit and crash.
- **Recommended Remediation:** Host the release APK on Cloudinary, an S3 bucket, or GitHub Releases, and redirect clients to the CDN URL.

---

## 5. Prioritized Testing Strategy Implications

These identified risks dictate the required end-to-end testing matrix:

1. **Test Recovery from Cold Starts:** Mobile test suites must simulate a 45-second backend response delay to verify that the app does not crash or corrupt session states.
2. **Test Ephemeral DB Recovery:** Test scripts must verify that running `seed_data()` on a freshly reset database restores the core operational accounts without crashing the app.
3. **Test Concurrent Submissions:** Automated load tests must verify that simultaneous visit submissions do not trigger SQLite database lock errors.
4. **Test Force-Update Blocking:** Testing must confirm that when `min_required_build_number` is bumped, outdated clients cannot bypass the modal and cannot access protected API routes.
