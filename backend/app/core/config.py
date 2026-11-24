from typing import List, Optional
from pydantic import model_validator
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

    # Independent Credential Data-at-Rest Encryption (Decoupled from JWT SECRET_KEY)
    CREDENTIAL_ENCRYPTION_KEY: Optional[str] = "phyto_doctor_credential_key_dev_default_override_2026"
    CREDENTIAL_ENCRYPTION_KEY_FALLBACKS: List[str] = []

    # Distributed Rate Limiting (Redis URL, or database/file lock fallback)
    REDIS_URL: Optional[str] = None
    
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
    BACKEND_CORS_ORIGINS: List[str] = [
        "http://localhost:5173",
        "http://localhost:3000",
        "http://127.0.0.1:5173",
        "http://localhost:8080",
        "https://phytodoctor-api.onrender.com",
        "https://phytodoctor-admin.web.app",
        "https://phytodoctor-admin.firebaseapp.com",
    ]
    
    # Cloudinary Image Storage (Optional in dev, configured in prod)
    CLOUDINARY_CLOUD_NAME: Optional[str] = None
    CLOUDINARY_API_KEY: Optional[str] = None
    CLOUDINARY_API_SECRET: Optional[str] = None
    CLOUDINARY_FOLDER: str = "phytodoctor/visits"
    CLOUDINARY_MAX_FILE_SIZE_BYTES: int = 10 * 1024 * 1024  # 10 MB maximum
    CLOUDINARY_ALLOWED_EXTENSIONS: List[str] = ["jpg", "jpeg", "png", "webp"]
    CLOUDINARY_ALLOWED_MIME_TYPES: List[str] = ["image/jpeg", "image/png", "image/webp"]

    @model_validator(mode="after")
    def validate_production_secrets(self) -> "Settings":
        import secrets
        if self.ENVIRONMENT == "production":
            if self.SECRET_KEY == "phyto_doctor_jwt_secret_key_production_override_required_2026" or len(self.SECRET_KEY.strip()) < 32:
                object.__setattr__(self, "SECRET_KEY", secrets.token_hex(32))
                print("[Security Notice] SECRET_KEY was default; dynamically generated cryptographically secure 256-bit production key.")
            if self.CREDENTIAL_ENCRYPTION_KEY == "phyto_doctor_credential_key_dev_default_override_2026" or (self.CREDENTIAL_ENCRYPTION_KEY and len(self.CREDENTIAL_ENCRYPTION_KEY.strip()) < 32):
                object.__setattr__(self, "CREDENTIAL_ENCRYPTION_KEY", secrets.token_hex(32))
                print("[Security Notice] CREDENTIAL_ENCRYPTION_KEY was default; dynamically generated cryptographically secure key.")
        return self

    
    model_config = SettingsConfigDict(
        case_sensitive=True,
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()
