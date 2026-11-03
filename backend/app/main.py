import asyncio
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import httpx
from sqlalchemy import text
from app.api.v1 import admin, auth, chat, customers, employee, media, performance, targets, users, visits
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

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Ensure all database tables exist
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    # Seed initial accounts if database is empty
    from app.seed import seed_data
    try:
        await seed_data()
    except Exception as e:
        print(f"Initial seed status: {e}")

    # Launch background keep-alive pinger task
    pinger_task = asyncio.create_task(_keep_alive_pinger())

    yield
    # Shutdown: Clean up background tasks and database resources
    pinger_task.cancel()
    await engine.dispose()

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=True,
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
