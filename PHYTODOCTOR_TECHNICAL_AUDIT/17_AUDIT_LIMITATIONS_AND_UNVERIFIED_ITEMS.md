# PhytoDoctor Technical Audit: 17 - Audit Limitations & Unverified Items

> **Inspection Scope:** Explicit documentation of audit boundaries, unverified runtime parameters, assumptions, and required live verification tasks prior to production deployment.

---

## 1. Audit Scope & Methodology Boundaries

This technical audit was conducted via **deep static source code inspection**, dependency manifest analysis, build configuration verification, and architectural discovery across the complete PhytoDoctor repository.

In strict compliance with the audit constraints:
- **Zero Modifications:** No source files, configurations, database records, or environment keys were modified, refactored, or deleted.
- **Secrets Protection:** No raw private keys, passwords, or Cloudinary API secrets have been exposed in documentation.
- **Evidence-Based Discovery:** All architectural conclusions are directly anchored to source code references.

---

## 2. Categorization of Findings: Confirmed vs. Inferred

| Category | Definition | Examples in this Audit |
|----------|------------|------------------------|
| **Confirmed Fact** | Directly evidenced by source code, configurations, or reproducible local execution. | - SQLite database model definitions<br>- 12 FastAPI routers mounted in `main.py`<br>- 50m GPS accuracy threshold in `visits.py`<br>- Plaintext password in `User.assigned_password`<br>- 24h JWT access token expiration |
| **Architectural Risk** | Potential failure mode logically resulting from evidenced configuration under production load. | - Data loss on Render free tier redeploy<br>- SQLite file locking under 20 concurrent submissions<br>- Cold-start timeouts on 15m idle sleep |
| **Unverified Runtime Item** | Operating condition that depends on live cloud host environment or physical hardware sensors. | - Actual live values of Render environment variables<br>- Exact remaining monthly Cloudinary credit balance<br>- Real hardware GPS accuracy under tin-roof warehouses in Multan |

---

## 3. Register of Unverified Runtime Items

The following items could not be verified by static repository inspection alone and must be confirmed dynamically:

### 3.1. Live Render Cloud Environment Variables
- **Status:** Unverified from code alone.
- **Risk:** If `SECRET_KEY` is not explicitly set in the Render web dashboard, the backend defaults to the insecure fallback secret documented in `09_AUTHENTICATION_AND_SECURITY.md`.
- **Verification Action Required:** The DevOps engineer or business owner must inspect the Render Dashboard (`Dashboard > phytodoctor-api > Environment`) and confirm that `SECRET_KEY` is set to a cryptographically random 64-character string.

### 3.2. Cloudinary Production Quota & API Credentials
- **Status:** Unverified.
- **Risk:** Static code verifies that the application is architected to operate within Cloudinary's 25 monthly free credits. However, live credit consumption on the active Cloudinary account cannot be determined without logging into the Cloudinary management console.
- **Verification Action Required:** Log into `cloudinary.com/console` and check current monthly credit utilization.

### 3.3. Physical Android Hardware GNSS Precision Under Rural Conditions
- **Status:** Partially verified via emulator and unit tests.
- **Risk:** Emulator GPS mocking delivers synthetic accuracy values (e.g., ±12.4m). Actual rural Android devices in Southern Punjab may experience multipath interference near dense orchard foliage or metal agricultural sheds.
- **Verification Action Required:** Execute field acceptance testing on physical Android devices in targeted rural locations (Multan/Khanewal) to evaluate real satellite lock times.

### 3.4. Local SQLite Persistence Across Operating System Process Death
- **Status:** Source inspection identified that `sqlite_visit_database.dart` currently buffers rows in a Dart memory map (`_tableRows`).
- **Risk:** If the Android OS aggressively reclaims RAM while the app is in the background, queued visits might not persist across device restarts unless `sqflite` is fully hooked up to disk storage.
- **Verification Action Required:** Perform a physical device test: log a visit in airplane mode, force-kill the app from Android Settings (`Force Stop`), reboot the phone, reopen the app, and verify if the pending draft still appears.

---

## 4. Pre-Testing Strategy Recommendations

Prior to executing the comprehensive testing strategy, the engineering team should address these items in order of priority:

1. **Provision Persistent Database:** Migrate from ephemeral SQLite to a managed PostgreSQL instance on Render or Supabase before conducting multi-user field trials.
2. **Remove Plaintext Password Column:** Refactor `User.assigned_password` out of the database schema and transition to one-time invitation links.
3. **Configure Live Environment Secrets:** Ensure `SECRET_KEY`, `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, and `CLOUDINARY_API_SECRET` are securely injected into Render.
4. **Execute End-to-End Test Suite:** Run the automated Pytest and Flutter test suites in an isolated staging environment using the test commands detailed in `14_EXISTING_TESTING_INFRASTRUCTURE.md`.
