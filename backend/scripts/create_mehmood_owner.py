import asyncio
import uuid
from app.core.database import AsyncSessionLocal
from app.models.user import User, UserRole
from app.core.security import get_password_hash
from sqlalchemy import select, or_

async def create_mehmood():
    async with AsyncSessionLocal() as session:
        # Check if user already exists
        query = select(User).where(
            or_(
                User.username.ilike("MehmoodAyyaz"),
                User.email.ilike("mehmoodayyaz@phytodoctor.com")
            )
        )
        res = await session.execute(query)
        user = res.scalar_one_or_none()
        
        pwd_hash = get_password_hash("Admin@PhytoDoctor")
        
        if user:
            print(f"Updating existing user {user.username} to Owner CEO...")
            user.username = "MehmoodAyyaz"
            user.full_name = "Mehmood Ayyaz"
            user.email = "mehmoodayyaz@phytodoctor.com"
            user.hashed_password = pwd_hash
            user.role = UserRole.OWNER.value
            user.is_active = True
        else:
            print("Creating new user MehmoodAyyaz...")
            user = User(
                id=str(uuid.uuid4()),
                username="MehmoodAyyaz",
                full_name="Mehmood Ayyaz",
                email="mehmoodayyaz@phytodoctor.com",
                hashed_password=pwd_hash,
                role=UserRole.OWNER.value,
                is_active=True,
            )
            session.add(user)
            
        await session.commit()
        print("Successfully created/updated MehmoodAyyaz as OWNER CEO with password Admin@PhytoDoctor!")

if __name__ == "__main__":
    asyncio.run(create_mehmood())
