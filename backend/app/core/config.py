from typing import List, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    PROJECT_NAME: str = "Phyto Doctor Field Tracking API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    # Environment
    ENVIRONMENT: str = "development"
    
    # Security Secrets (Override in production via environment variables)
    SECRET_KEY: str = "phyto_doctor_jwt_secret_key_production_override_required_2026"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 24 hours for testing/dev
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7     # Secure refresh token strategy
    
    # Database Configuration (PostgreSQL in production; SQLite for local testing)
    DATABASE_URL: str = "sqlite+aiosqlite:///./phyto_doctor.db"
    
    @property
    def ASYNC_DATABASE_URL(self) -> str:
        url = self.DATABASE_URL
        if url.startswith("postgres://"):
            return url.replace("postgres://", "postgresql+asyncpg://", 1)
        elif url.startswith("postgresql://"):
            return url.replace("postgresql://", "postgresql+asyncpg://", 1)
        return url
    
    # CORS Configuration
    BACKEND_CORS_ORIGINS: List[str] = ["*"]
    
    # Cloudinary Image Storage (Optional in dev, configured in prod)
    CLOUDINARY_CLOUD_NAME: Optional[str] = None
    CLOUDINARY_API_KEY: Optional[str] = None
    CLOUDINARY_API_SECRET: Optional[str] = None
    CLOUDINARY_FOLDER: str = "phytodoctor/visits"
    CLOUDINARY_MAX_FILE_SIZE_BYTES: int = 10 * 1024 * 1024  # 10 MB maximum
    CLOUDINARY_ALLOWED_EXTENSIONS: List[str] = ["jpg", "jpeg", "png", "webp"]
    CLOUDINARY_ALLOWED_MIME_TYPES: List[str] = ["image/jpeg", "image/png", "image/webp"]

    
    model_config = SettingsConfigDict(
        case_sensitive=True,
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()
