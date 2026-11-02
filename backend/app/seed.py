import asyncio
from datetime import date, datetime, timedelta, timezone
from sqlalchemy import select
from app.core.database import AsyncSessionLocal, Base, engine
from app.core.security import get_password_hash
from app.models.target import EmployeeTarget, TargetPeriod
from app.models.user import User, UserRole
from app.models.visit import FieldVisit, VisitStatus

async def seed_data():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        
    async with AsyncSessionLocal() as session:
        result = await session.execute(select(User))
        existing_users = result.scalars().all()
        if existing_users:
            print("Database already contains user records. Skipping seed.")
            return

        mehmood = User(
            id="owner-mehmood-1",
            full_name="Mehmood Ayyaz",
            email="mehmoodayyaz@phytodoctor.com",
            username="MehmoodAyyaz",
            hashed_password=get_password_hash("Admin@PhytoDoctor"),
            assigned_password="Admin@PhytoDoctor",
            role=UserRole.OWNER.value,
            is_active=True,
        )
        session.add(mehmood)

        admin_taha = User(
            id="admin-taha-1",
            full_name="Taha Sajjad",
            email="tahasajjad@phytodoctor.com",
            username="admin.tahasajjad",
            hashed_password=get_password_hash("Admin12345"),
            assigned_password="Admin12345",
            role=UserRole.MANAGER.value,
            phone="03106733255",
            designation="Software Developer",
            created_by_id=mehmood.id,
            is_active=True,
        )
        session.add(admin_taha)

        emp_salman = User(
            id="emp-salman-1",
            full_name="Salman",
            email="salman@phytodoctor.com",
            username="emp.salman",
            hashed_password=get_password_hash("emp.salman123"),
            assigned_password="emp.salman123",
            role=UserRole.EMPLOYEE.value,
            designation="Agronomist",
            manager_id=admin_taha.id,
            created_by_id=admin_taha.id,
            is_active=True,
        )
        session.add(emp_salman)

        await session.commit()
        print("Successfully seeded Phyto Doctor database with CEO, Admin, and Employee accounts.")

if __name__ == "__main__":
    asyncio.run(seed_data())
