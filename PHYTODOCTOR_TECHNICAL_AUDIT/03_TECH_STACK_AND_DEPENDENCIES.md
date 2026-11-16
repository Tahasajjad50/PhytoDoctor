# PhytoDoctor Technical Audit: 03 - Technology Stack & Dependencies

> **Verification Method:** Direct file inspection of `mobile/pubspec.yaml`, `backend/requirements.txt`, `render.yaml`, `mobile/android/app/build.gradle`, and CI/CD configuration files.

---

## 1. Frontend Technology Stack (Mobile - Android)

| Category | Component / Library | Declared Version | Purpose & Usage in PhytoDoctor |
|----------|---------------------|------------------|--------------------------------|
| **Language** | Dart | `>=3.0.0 <4.0.0` | Core programming language for Flutter client |
| **Framework** | Flutter SDK | Stable Channel | Cross-platform framework (targeted for Android) |
| **UI Library** | Google Fonts | `^6.1.0` | Custom typography (`Plus Jakarta Sans`) |
| **Icons** | Lucide Icons | `^0.257.0` | Modern vector icon pack |
| **HTTP Client** | `http` | `^1.2.0` | REST API networking with timeout and header injection |
| **Secure Storage** | `flutter_secure_storage` | `^9.0.0` | Android KeyStore-backed storage (`encryptedSharedPreferences`) |
| **State Management** | `provider` / `ChangeNotifier` | `^6.1.1` | Local state notifications (`LocalVisitQueue`, `OfflineSyncManager`) |
| **Local Storage** | Custom In-Memory / SQLite wrapper | Custom | `local_field_visits` persistent storage table |
| **URL Launcher** | `url_launcher` | `^6.3.1` | External Google Maps intents (`geo:` / `https://maps.google.com`) |
| **Hardware Platform** | `MethodChannel` (`native_platform_service`) | Custom Native | Bridge for Android Camera shutter, storage, and share intents |
| **Build Target** | Android SDK | `minSdkVersion: 21`, `targetSdkVersion: 34` | Android 5.0 (Lollipop) through Android 14 |
| **Application ID** | `com.phytodoctor.fieldapp` | `1.0.0+1` | Package identifier declared in Gradle and Manifest |
| **Build System** | Flutter CLI / Gradle | Gradle 8.x | Compiles release APK and AAB with `--dart-define=API_URL` |

### Frontend Testing Dependencies (`dev_dependencies`)
- `flutter_test`: Flutter Unit & Widget testing SDK
- `flutter_lints`: `^3.0.0` (Dart official code style rules)
- `mockito`: `^5.4.4` (Mock generation for repository testing)

---

## 2. Backend Technology Stack

| Category | Technology / Library | Declared Version | Purpose & Usage in PhytoDoctor |
|----------|----------------------|------------------|--------------------------------|
| **Language** | Python | `3.11.9` (Render) / `3.12` (CI) | Asynchronous backend language |
| **Web Framework** | FastAPI | `>=0.110.0` | High-performance asynchronous REST API framework |
| **ASGI Server** | Uvicorn | `>=0.28.0` | Asynchronous server implementation |
| **Data Validation** | Pydantic v2 | `>=2.6.0` | Schema validation, type enforcement, data serialization |
| **Settings Management**| `pydantic-settings` | `>=2.2.0` | Environment configuration reading `.env` and system variables |
| **Email Validation** | `email-validator` | `>=2.0.0` | Validates email syntax in User schemas |
| **Database ORM** | SQLAlchemy | `>=2.0.0` | Modern Async Declarative ORM |
| **Async SQLite Driver**| `aiosqlite` | `>=0.20.0` | Async driver for `sqlite+aiosqlite:///./phyto_doctor.db` |
| **Async Postgres Driver**| `asyncpg` | `>=0.29.0` | Driver provisioned for production PostgreSQL migration |
| **Database Migrations**| Alembic | `>=1.13.0` | Provisioned in requirements; **not yet actively executing migrations** |
| **Password Hashing** | `bcrypt` | `==4.0.1` | Secure password hashing (`rounds=12` in prod, `4` in test) |
| **Authentication Tokens**| PyJWT | `>=2.8.0` | HS256 JWT encoding, claims verification, role checks |
| **HTTP Client** | `httpx` | `>=0.27.0` | Async internal HTTP client (used for keep-alive pings) |
| **Media Cloud Storage**| `cloudinary` | `>=1.39.0` | Cloudinary Python SDK for image management |
| **Form Multipart** | `python-multipart` | `>=0.0.9` | Multipart form parsing for direct file uploads |
| **Concurrency Helper** | `greenlet` | `>=3.0.0` | Asyncio bridge for SQLAlchemy async engine |

### Backend Testing Dependencies
- `pytest`: `>=8.0.0`
- `pytest-asyncio`: `>=0.23.0`

---

## 3. Database Technology Stack

| Layer | Implementation | Notes / Findings |
|-------|----------------|------------------|
| **Database Engine** | SQLite 3 | Embedded file `phyto_doctor.db` located at backend root |
| **Driver Interface** | `sqlite+aiosqlite` | Non-blocking async execution via worker threads |
| **Production Target** | Configured for PostgreSQL (`asyncpg`) | `ASYNC_DATABASE_URL` property converts `postgres://` URLs automatically |
| **Schema Initialization**| `Base.metadata.create_all` | Executed in `main.py` lifespan; idempotent table creation |
| **Migration Tool** | Alembic (Installed, Unused) | No Alembic migration scripts exist in the repository |
| **Concurrency / Locks**| SQLite file-level locking | `check_same_thread: False` flag enabled in engine configuration |
| **Persistence Status** | **Ephemeral** on Render.com free tier | Storage is destroyed whenever Render restarts or redeploys |

---

## 4. Hosting, Infrastructure & Cloud Services

| Infrastructure Layer | Provider / Service | Configuration Details | Source Evidence |
|----------------------|--------------------|-----------------------|-----------------|
| **Backend Web Service**| Render.com | Free Plan, Oregon (US West) region | `render.yaml` |
| **Backend Domain** | `onrender.com` | `https://phytodoctor-api.onrender.com` | `app_config.dart`, `render.yaml` |
| **HTTPS / TLS** | Render Managed SSL | Let's Encrypt TLS termination at edge proxy | Verified via live endpoint |
| **Cloud Media Storage**| Cloudinary | Programmable Media (Free Tier, 25 monthly credits) | `render.yaml`, `app/schemas/media.py` |
| **Cloudinary Folder** | `phytodoctor/visits` | Maximum file size 10 MB, allowed formats: JPG, PNG, WEBP | `app/core/config.py` |
| **Version Control** | GitHub | Private repository `Tahasajjad50/PhytoDoctor` | Git remote origin |
| **CI/CD Platform** | GitHub Actions | Workflows: `production-release.yml`, `render_keep_alive.yml` | `.github/workflows/` |
| **APK Distribution** | Self-hosted backend / Manual | Route: `/api/v1/system/download-apk` | `app/api/v1/system.py` |
| **Monitoring / Logging**| Render Dashboard Logs | Stdout/Stderr log streaming; in-database `audit_events` | `app/services/audit_service.py` |
| **Keep-Alive System** | GitHub Actions / Script | Workflow executes periodic HTTP ping to `/api/v1/health` | `render_keep_alive.yml` |

---

## 5. Web Admin Dashboard Technology Stack (`/admin`)

| Category | Component | Declared Version |
|----------|-----------|------------------|
| **Language** | TypeScript | `~5.5.3` |
| **Framework** | React | `^18.3.1` |
| **Bundler** | Vite | `^5.4.2` |
| **Routing** | React Router DOM | `^6.26.1` |
| **Icons** | Lucide React | `^0.441.0` |
| **HTTP Client** | Axios | `^1.7.7` |
| **Linter** | Oxlint / ESLint | `.oxlintrc.json` |
