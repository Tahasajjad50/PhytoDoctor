import asyncio
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import httpx
from sqlalchemy import text
from app.api.v1 import admin, attendance, auth, chat, customers, employee, media, performance, system, targets, users, visits
import app.models  # Ensure all model tables are registered in Base.metadata
from app.core.config import settings
from app.core.database import Base, engine

async def _keep_alive_pinger():
    """Background task to keep Render server awake by pinging public endpoint every 10 minutes."""
    # Wait 60s after boot before starting pings
    await asyncio.sleep(60)
    target_url = "https://phytodoctor-api.onrender.com/api/v1/health"
    while True:
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                res = await client.get(target_url)
                print(f"[Keep-Alive] Ping {target_url} -> Status {res.status_code}")
        except Exception as e:
            print(f"[Keep-Alive] Ping notice: {e}")
        # Ping every 10 minutes (600s). Render sleeps after 15 minutes of inactivity.
        await asyncio.sleep(600)

def _run_sqlite_column_migrations(conn):
    """Safely adds missing columns to existing SQLite tables if not present."""
    if conn.dialect.name != "sqlite":
        return
    try:
        res = conn.execute(text("PRAGMA table_info(users)")).fetchall()
        existing_cols = {row[1] for row in res}
        if "created_by_id" not in existing_cols:
            conn.execute(text("ALTER TABLE users ADD COLUMN created_by_id VARCHAR(36)"))
            print("[Migration] Added created_by_id to users")
        if "assigned_password" not in existing_cols:
            conn.execute(text("ALTER TABLE users ADD COLUMN assigned_password VARCHAR(255)"))
            print("[Migration] Added assigned_password to users")
        if "phone" not in existing_cols:
            conn.execute(text("ALTER TABLE users ADD COLUMN phone VARCHAR(50)"))
            print("[Migration] Added phone to users")
        if "designation" not in existing_cols:
            conn.execute(text("ALTER TABLE users ADD COLUMN designation VARCHAR(100)"))
            print("[Migration] Added designation to users")
    except Exception as e:
        print(f"[Migration Warning] {e}")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Ensure all database tables exist
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await conn.run_sync(_run_sqlite_column_migrations)
    # Seed initial accounts if database is empty
    from app.seed import seed_data
    try:
        await seed_data()
    except Exception as e:
        print(f"Initial seed status: {e}")

    # Keep-alive pinger disabled during development to preserve free tier hours
    pinger_task = None
    # if settings.ENVIRONMENT != "test":
    #     pinger_task = asyncio.create_task(_keep_alive_pinger())

    yield
    # Shutdown: Clean up background tasks and database resources
    if pinger_task:
        pinger_task.cancel()
    await engine.dispose()

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan
)

# CORS configuration: strict standard compliance (no wildcard credentials)
cors_has_wildcard = "*" in settings.BACKEND_CORS_ORIGINS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=not cors_has_wildcard,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register API v1 Routers
app.include_router(auth.router, prefix=settings.API_V1_STR)
app.include_router(users.router, prefix=settings.API_V1_STR)
app.include_router(visits.router, prefix=settings.API_V1_STR)
app.include_router(targets.router, prefix=settings.API_V1_STR)
app.include_router(performance.router, prefix=settings.API_V1_STR)
app.include_router(admin.router, prefix=settings.API_V1_STR)
app.include_router(employee.router, prefix=settings.API_V1_STR)
app.include_router(media.router, prefix=settings.API_V1_STR)
app.include_router(chat.router, prefix=settings.API_V1_STR)
app.include_router(customers.router, prefix=settings.API_V1_STR)
app.include_router(attendance.router, prefix=settings.API_V1_STR)
app.include_router(system.router, prefix=settings.API_V1_STR)


@app.get("/")
async def root():
    return {
        "app": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT,
        "status": "online"
    }

@app.get("/api/v1/health")
async def health_check():
    """System health check verifying database ping and UTC clock."""
    db_healthy = False
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
            db_healthy = True
    except Exception:
        db_healthy = False

    return {
        "status": "healthy" if db_healthy else "degraded",
        "database_connected": db_healthy,
        "utc_timestamp": datetime.now(timezone.utc).isoformat(),
        "version": settings.VERSION,
    }
