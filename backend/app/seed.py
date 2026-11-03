import asyncio
from datetime import date, datetime, timedelta, timezone
from sqlalchemy import select
from app.core.database import AsyncSessionLocal, Base, engine
from app.core.security import get_password_hash
from app.models.target import EmployeeTarget, TargetPeriod
from app.models.user import User, UserRole
from app.models.visit import FieldVisit, VisitStatus
from app.models.app_version import AppVersionConfig

async def seed_data():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        
    async with AsyncSessionLocal() as session:
        # 1. Seed or ensure default AppVersionConfig exists
        res_v = await session.execute(select(AppVersionConfig).where(AppVersionConfig.id == 1))
        version_config = res_v.scalars().first()
        if not version_config:
            version_config = AppVersionConfig(
                id=1,
                latest_version="1.0.0",
                latest_build_number=1,
                min_required_build_number=1,
                force_update=True,
                title="Update Required",
                message="A newer official version of PhytoDoctor is available. Please update to continue using the application.",
                release_notes="Official release with Employee Attendance Roster, Field Clock-In/Out, and Offline Sync.",
                download_url="https://phytodoctor-api.onrender.com/api/v1/system/download-apk",
            )
            session.add(version_config)
            await session.commit()

        # 2. Seed initial core accounts idempotently
        accounts_to_seed = [
            User(
                id="owner-mehmood-1",
                full_name="Mehmood Ayyaz",
                email="mehmoodayyaz@phytodoctor.com",
                username="MehmoodAyyaz",
                hashed_password=get_password_hash("Admin@PhytoDoctor"),
                assigned_password="Admin@PhytoDoctor",
                role=UserRole.OWNER.value,
                is_active=True,
            ),
            User(
                id="admin-taha-1",
                full_name="Taha Sajjad",
                email="tahasajjad@phytodoctor.com",
                username="admin.tahasajjad",
                hashed_password=get_password_hash("Admin12345"),
                assigned_password="Admin12345",
                role=UserRole.MANAGER.value,
                phone="03106733255",
                designation="Software Developer",
                created_by_id="owner-mehmood-1",
                is_active=True,
            ),
            User(
                id="emp-salman-1",
                full_name="Salman",
                email="salman@phytodoctor.com",
                username="emp.salman",
                hashed_password=get_password_hash("emp.salman123"),
                assigned_password="emp.salman123",
                role=UserRole.EMPLOYEE.value,
                designation="Agronomist",
                manager_id="admin-taha-1",
                created_by_id="admin-taha-1",
                is_active=True,
            ),
            User(
                id="emp-muneeb-1",
                full_name="Muneeb Ur Rehman",
                email="muneeburrehman@phytodoctor.com",
                username="emp.muneeb",
                hashed_password=get_password_hash("muneeb123"),
                assigned_password="muneeb123",
                role=UserRole.EMPLOYEE.value,
                phone="03056814088",
                designation="Tester",
                manager_id="admin-taha-1",
                created_by_id="owner-mehmood-1",
                is_active=True,
            ),
        ]

        for acc in accounts_to_seed:
            existing = (await session.execute(select(User).where((User.username == acc.username) | (User.email == acc.email)))).scalars().first()
            if not existing:
                session.add(acc)

        await session.commit()
        print("Successfully seeded Phyto Doctor database with CEO, Admin, and Employee accounts.")

if __name__ == "__main__":
    asyncio.run(seed_data())
