# PhytoDoctor Technical Audit: 12 - Server, Deployment & DevOps

> **Infrastructure Environment:** Render.com Cloud Platform (Free Tier, Oregon Region)  
> **CI/CD Pipeline:** GitHub Actions (`.github/workflows/production-release.yml`)  
> **Repository:** `https://github.com/Tahasajjad50/PhytoDoctor.git`

---

## 1. Hosting Architecture & Service Specification

Declared in `render.yaml`:

```yaml
services:
  - type: web
    name: phytodoctor-api
    runtime: python
    rootDir: backend
    plan: free
    region: oregon
    buildCommand: pip install --upgrade pip && pip install -r requirements.txt
    startCommand: python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT
    envVars:
      - key: PYTHON_VERSION
        value: 3.11.9
      - key: ENVIRONMENT
        value: production
      - key: SECRET_KEY
        generateValue: true
      - key: DATABASE_URL
        value: sqlite+aiosqlite:///./phyto_doctor.db
      - key: CLOUDINARY_CLOUD_NAME
        sync: false
      - key: CLOUDINARY_API_KEY
        sync: false
      - key: CLOUDINARY_API_SECRET
        sync: false
```

---

## 2. Infrastructure Characteristics & Constraints

| Characteristic | Status / Specification | Impact on Application Lifecycle |
|----------------|------------------------|---------------------------------|
| **Plan Tier** | Render.com Free Tier | Monthly limit of 750 free instance hours. |
| **Inactivity Sleeping**| Spins down after 15 minutes of zero traffic | Cold-start latency of **30 to 50 seconds** on subsequent requests. |
| **Storage Persistence**| **Ephemeral Container Storage** | **CRITICAL:** `phyto_doctor.db` is stored on the local container disk. Every redeployment, manual restart, or crash completely wipes the database file. |
| **TLS / SSL** | Edge-terminated Let's Encrypt | Automatic certificate renewal; client connects via `https://phytodoctor-api.onrender.com`. |
| **Concurrency / Worker Model** | Single Uvicorn process | Bound to container memory limits (~512MB RAM). |
| **Network Egress** | Unrestricted HTTPS | Direct outbound communication with Cloudinary media endpoints. |

---

## 3. Keep-Alive Strategy & Mitigation

Because Render free instances spin down after 15 minutes of inactivity, field agronomists attempting to log visits in the morning would experience severe request timeouts. PhytoDoctor has three distinct keep-alive mechanisms:

1. **GitHub Actions Scheduled Pinger (`render_keep_alive.yml`):**
   - Configured with cron `*/10 * * * *` to ping `/api/v1/health`.
   - *Status:* Currently paused (commented out) in the workflow file to conserve monthly Render free instance hours.
2. **Local Windows Keep-Alive Script (`Keep_Server_Awake.bat`):**
   - Executes an infinite curl loop from local development machines every 600 seconds.
3. **Internal Async Lifespan Pinger (`_keep_alive_pinger` in `main.py`):**
   - An async loop scheduled with `asyncio.create_task` to self-ping its own public URL every 10 minutes.
   - *Status:* Commented out during local development.

---

## 4. Continuous Integration & Deployment (CI/CD)

The production release workflow is defined in `.github/workflows/production-release.yml` and triggers on `workflow_dispatch` or git push of semantic tags (`v*`):

```
+-------------------------------------------------------------------------------+
|             GITHUB ACTIONS CI/CD PIPELINE (production-release.yml)            |
+-------------------------------------------------------------------------------+
                                        │
                    ┌───────────────────┼───────────────────┐
                    ▼                   ▼                   ▼
            [ Job 1: Backend ]   [ Job 2: Admin ]    [ Job 3: Mobile ]
            - Python 3.12        - Node.js 20.x      - Java 17 + Flutter
            - pip install        - npm install       - flutter test
            - pytest -v          - npm run build     - Inject keystore
            - DR Drill           - Upload dist       - Build Release APK
                                                     - Build Release AAB
                                                     - Upload Artifacts
```

### Build Artifacts Produced:
- `phytodoctor-release-apk`: Production APK ready for direct field distribution.
- `phytodoctor-release-aab`: Android App Bundle configured for Google Play Console submission.
- `admin-dashboard-dist`: Static HTML/JS distribution for the web admin panel.

---

## 5. Automated Release & In-App Publisher Tooling

A dedicated automation utility exists at `scripts/publish_update.py`:

```
User runs: python scripts/publish_update.py
   │
   ├── 1. Auto-increments appVersion in app_config.dart and pubspec.yaml (e.g. 1.0.0 -> 1.0.1)
   ├── 2. Runs Flutter release build: flutter build apk --release --dart-define=API_URL=...
   ├── 3. Copies compiled APK to backend/app/static/PhytoDoctor-release.apk
   ├── 4. Commits changes and pushes git tag: git push origin main --tags
   └── 5. Triggers Render deploy hook via Render CLI: render deploys create srv-dbl3hk08v5cc73ak1tc0
```

---

## 6. Disaster Recovery & Database Backup Utility

Declared in `backend/scripts/backup_restore.py`:
- **Functions:** Snapshot backup of SQLite database, SHA-256 integrity verification, and recovery validation drills.
- **CI Drill:** Executed in GitHub Actions (`python scripts/backup_restore.py --drill`) to verify that the database can be backed up and restored without data corruption.

---

## 7. Critical DevOps & Server Vulnerabilities

| Issue | Severity | Impact Description |
|-------|:--------:|--------------------|
| **Ephemeral Database Disk** | **CRITICAL** | Production data is stored in SQLite on Render's ephemeral disk. Re-deploying code resets all accounts and field records. |
| **No PostgreSQL Configured** | **HIGH** | `render.yaml` does not provision a managed PostgreSQL instance, despite the application code possessing full `asyncpg` support. |
| **Render Free Tier Cold Starts** | **MEDIUM** | Inactivity sleep results in 30-50 second latency for initial requests, causing user confusion and socket timeouts. |
| **Self-Hosted APK Bandwidth** | **MEDIUM** | Distributing 40MB+ APKs directly from the Render web service consumes free bandwidth and memory. |
