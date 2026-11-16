# PhytoDoctor Technical Audit: 06 - Backend Architecture

> **Target Codebase:** `backend/app/`  
> **Inspection Scope:** FastAPI application initialization, async database engine, dependency injection, middleware pipeline, business logic services, router hierarchy, and background tasks.

---

## 1. Backend Architecture Diagram

```
+-----------------------------------------------------------------------------------+
|                                  CLIENT LAYER                                     |
|             Flutter Mobile Client  /  Vite Admin Web  /  External HTTP            |
+-----------------------------------------------------------------------------------+
                                          |
                                          | HTTPS Request (Bearer JWT)
                                          v
+-----------------------------------------------------------------------------------+
|                             FASTAPI CORE PIPELINE                                 |
|                                                                                   |
|  [ CORS Middleware ]                                                              |
|   - allow_origins=["*"]                                                           |
|   - allow_credentials=True                                                        |
|   - allow_methods=["*"], allow_headers=["*"]                                      |
|                                                                                   |
|  [ Dependency Injection Container (app/core/deps.py) ]                             |
|   - get_db() -> AsyncSessionLocal (aiosqlite / asyncpg)                           |
|   - get_current_user() -> Decodes JWT, validates active flag                      |
|   - require_roles(OWNER, MANAGER, EMPLOYEE) -> Role-Based Access Control          |
|                                                                                   |
|  [ In-Memory Rate Limiter (app/core/rate_limit.py) ]                              |
|   - login_rate_limiter.check_rate_limit(identifier) (5 fails / 15m lockout)       |
+-----------------------------------------------------------------------------------+
                                          |
                                          | Dispatched to Routers
                                          v
+-----------------------------------------------------------------------------------+
|                             API v1 ROUTERS (/api/v1)                              |
|                                                                                   |
|  ├── /auth         (Login, Token Refresh, Logout, Profile Me)                     |
|  ├── /users        (User CRUD, Credentials Reset, Supervision Transfer)          |
|  ├── /visits       (Visit Submission, Review Signals, Manager Verify/Reject)      |
|  ├── /targets      (Quotas, Single & Batch Target Creation)                      |
|  ├── /performance  (Summary, Multi-period Trends, Team Comparison)                |
|  ├── /customers    (Farm Registration, Auto-Territory Assignment)                 |
|  ├── /attendance   (Shift Clock-In / Clock-Out, Manager Attendance Roster)        |
|  ├── /media        (Cloudinary Signed Authorization, Photo Confirmation)          |
|  ├── /chat         (Chatrooms, Messaging Thread, CEO Broadcasts)                 |
|  ├── /system       (Version Checks, Force-Update Guard, Direct APK Binary)        |
|  ├── /admin        (Aggregated Dashboard KPIs, Audit Event Explorer)              |
|  └── /employee     (Live Agronomist Dashboard Summaries)                          |
+-----------------------------------------------------------------------------------+
            |                                                   |
            | Business Logic & Domain Validations               | Audit Trail
            v                                                   v
+---------------------------------------+   +---------------------------------------+
|           DATA ACCESS LAYER           |   |            AUDIT SERVICE              |
|  SQLAlchemy 2.0 Async ORM Declarative |   |  app/services/audit_service.py        |
|  - aiosqlite (Local / Render Dev)     |   |  - log_audit_event() -> AsyncSession  |
|  - asyncpg (Production Target)        |   |  - Writes to audit_events table       |
+---------------------------------------+   +---------------------------------------+
                    |
                    v
+-----------------------------------------------------------------------------------+
|                             DATABASE STORAGE (SQLite)                             |
|  users | field_visits | employee_targets | customers | attendances                |
|  chat_rooms | chat_messages | audit_events | refresh_tokens | app_version_configs  |
+-----------------------------------------------------------------------------------+
```

---

## 2. Application Entry & Lifespan Initialization

The backend service is initialized in `backend/app/main.py` using FastAPI's modern async `lifespan` context manager:

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    # 1. Startup: Create all missing tables in the database
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        
    # 2. Seed initial required accounts if database is fresh
    from app.seed import seed_data
    try:
        await seed_data()
    except Exception as e:
        print(f"Initial seed status: {e}")

    yield

    # 3. Shutdown: Clean up database engine resources
    await engine.dispose()
```

### Observations on Lifespan Initialization:
1. **Automated Table Creation:** Running `Base.metadata.create_all` automatically creates all 10 SQL tables on startup if they do not exist.
2. **Idempotent Data Seeding:** The `seed_data()` function checks whether standard default accounts (CEO `MehmoodAyyaz`, Admin `admin.tahasajjad`, and agronomists `emp.zain`, `emp.muneeb`, `emp.salman`) exist; if missing, it hashes their passwords and links their supervisor relationships.
3. **Background Pinger:** An async background task `_keep_alive_pinger()` is present in `main.py` to prevent Render free-tier sleep by pinging `/api/v1/health` every 10 minutes, but is commented out during development to conserve free hours.

---

## 3. Dependency Injection & Authorization Pipeline

Declared in `backend/app/core/deps.py`:

### 3.1. Database Session Injection (`get_db`)
```python
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
```
Ensures every request operates within its own isolated async transaction and guarantees session closure upon response completion.

### 3.2. Bearer Token Authentication (`get_current_user`)
1. Extracts `Authorization: Bearer <token>` header via FastAPI's `HTTPBearer`.
2. Decodes JWT using `app/core/security.py` with HS256 algorithm and `settings.SECRET_KEY`.
3. Validates token claims (`type == 'access'`, expiration timestamp, issuer).
4. Queries `users` table by UUID (`sub` claim).
5. Checks `user.is_active`; raises `HTTP 403 Forbidden` if deactivated.

### 3.3. Role-Based Access Control Factory (`require_roles`)
```python
def require_roles(*allowed_roles: str) -> Callable:
    async def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied: Requires one of [{', '.join(allowed_roles)}] privileges.",
            )
        return current_user
    return role_checker

require_admin = require_roles(UserRole.OWNER.value, UserRole.MANAGER.value)
require_owner = require_roles(UserRole.OWNER.value)
require_employee = require_roles(UserRole.EMPLOYEE.value)
```

---

## 4. Request Lifecycle Trace: Field Visit Submission

A standard field visit submission follows this end-to-end processing pipeline:

```
[Mobile Device]
       │
       │ 1. POST /api/v1/visits (VisitCreate JSON + Bearer JWT)
       ▼
[FastAPI Framework]
       │
       │ 2. CORS Verification & Request Parsing
       ▼
[app/core/deps.py: get_current_user]
       │
       │ 3. Decode JWT -> Verify user exists & is_active in SQLite
       ▼
[app/api/v1/visits.py: create_visit]
       │
       │ 4. UUID Idempotency Check:
       │    If visit.id already exists for this employee -> Return HTTP 200 (Idempotent replay)
       │    If visit.id exists for different employee -> Raise HTTP 409 Conflict
       │
       │ 5. Photo Asset Immutability Check:
       │    Ensure photo_asset_id has never been used by any existing visit
       │
       │ 6. Fraud-Aware Review Signals Evaluation:
       │    - GPS accuracy > 50.0m? -> Flag LOW_GPS_ACCURACY
       │    - Device reported mock location? -> Flag REPORTED_MOCK_LOCATION
       │    - Clock drift < -300s (future)? -> Flag IMPLAUSIBLE_DEVICE_CLOCK
       │    - Clock drift > 86400s (>24h delay)? -> Flag SUSPICIOUS_UPLOAD_DELAY
       │
       │ 7. Construct FieldVisit ORM Entity (status='PENDING')
       │    Add to db session -> flush()
       ▼
[app/services/audit_service.py: log_audit_event]
       │
       │ 8. Insert AuditEvent(action="VISIT_CREATED", actor_id=employee.id)
       ▼
[SQLAlchemy AsyncSession]
       │
       │ 9. db.commit() -> db.refresh(visit)
       ▼
[FastAPI Response Formatter]
       │
       │ 10. Serialize VisitResponse via Pydantic
       ▼
[Mobile Client receives HTTP 201 Created]
```

---

## 5. Architectural Quality Attributes & Technical Deficiencies

| Architectural Attribute | Current Implementation | Identified Risk / Finding |
|-------------------------|------------------------|---------------------------|
| **Modularity & Separation of Concerns** | High. Clean separation between routes, schemas, models, and core configuration. | Routers are well structured, but business logic is directly inside route handlers rather than separate service classes. |
| **Error Handling** | Consistent. Standard `HTTPException` with informative error strings. | Internal server errors fall back to standard FastAPI 500 without custom sanitized formatting. |
| **Data Consistency** | Strong transaction boundaries (`AsyncSession` commit/rollback). | SQLite lacks robust foreign key enforcement by default unless `PRAGMA foreign_keys = ON;` is explicitly executed on every connection. |
| **Rate Limiting** | Custom in-memory implementation in `rate_limit.py`. | Tracks in process memory; restarts or multi-worker uvicorn configurations will not share state. |
| **Audit Logging** | Centralized in `audit_service.py` writing to `audit_events`. | Audit logs are stored in the same database table; if SQLite disk is lost on Render, audit history is lost as well. |
| **File Storage Decoupling** | Dedicated media router delegating to Cloudinary. | Well-designed fallback when Cloudinary credentials are not configured in local development. |
