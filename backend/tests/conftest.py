import os
import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from app.core.database import Base, get_db
from app.core.rate_limit import login_rate_limiter
from app.core.security import get_password_hash
from app.main import app
from app.models.user import User, UserRole

# Shared test database file for thread/connection safety across async test clients
TEST_DB_FILE = "./test_phytodoctor.db"
TEST_DATABASE_URL = f"sqlite+aiosqlite:///{TEST_DB_FILE}"

test_engine = create_async_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False}
)
TestAsyncSessionLocal = async_sessionmaker(
    bind=test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False
)

async def override_get_db():
    async with TestAsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

app.dependency_overrides[get_db] = override_get_db

@pytest_asyncio.fixture(autouse=True)
async def setup_test_db():
    login_rate_limiter.reset()
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)

    async with TestAsyncSessionLocal() as session:
        users = [
            User(
                id="owner-uuid-1",
                full_name="Dr. Tariq Malik (Owner)",
                email="owner@phytodoctor.com",
                username="owner",
                hashed_password=get_password_hash("owner123"),
                role=UserRole.OWNER.value,
                is_active=True,
            ),
            User(
                id="manager-uuid-2",
                full_name="Farhan Qureshi (Manager)",
                email="manager@phytodoctor.com",
                username="manager.punjab",
                hashed_password=get_password_hash("manager123"),
                role=UserRole.MANAGER.value,
                is_active=True,
                manager_id="owner-uuid-1",
            ),
            User(
                id="employee-uuid-3",
                full_name="John Doe (Agronomist)",
                email="employee@phytodoctor.com",
                username="emp.john",
                hashed_password=get_password_hash("emp123"),
                role=UserRole.EMPLOYEE.value,
                is_active=True,
                manager_id="manager-uuid-2",
            ),
            User(
                id="inactive-uuid-4",
                full_name="Inactive Officer",
                email="inactive@phytodoctor.com",
                username="emp.inactive",
                hashed_password=get_password_hash("emp123"),
                role=UserRole.EMPLOYEE.value,
                is_active=False,
                manager_id="manager-uuid-2",
            ),
        ]
        session.add_all(users)
        await session.commit()

    yield

    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

    # Clean up test database file if needed
    if os.path.exists(TEST_DB_FILE):
        try:
            os.remove(TEST_DB_FILE)
        except Exception:
            pass
