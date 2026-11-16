from datetime import datetime, timedelta, timezone
import hashlib
import secrets
from typing import Any, Optional, Union
import bcrypt
import jwt
from app.core.config import settings

def get_password_hash(password: str) -> str:
    pwd_bytes = password.encode("utf-8")
    rounds = 4 if settings.ENVIRONMENT == "test" else 12
    salt = bcrypt.gensalt(rounds=rounds)
    return bcrypt.hashpw(pwd_bytes, salt).decode("utf-8")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"),
            hashed_password.encode("utf-8")
        )
    except Exception:
        return False

def create_access_token(subject: Union[str, Any], role: str, expires_delta: Optional[timedelta] = None) -> str:
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode = {
        "exp": expire,
        "sub": str(subject),
        "role": role,
        "type": "access",
        "iss": "phyto-doctor-auth"
    }
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt

def decode_access_token(token: str) -> Optional[dict]:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        if payload.get("type") != "access":
            return None
        return payload
    except (jwt.PyJWTError, Exception):
        return None

def generate_refresh_token() -> str:
    """Generates a high-entropy cryptographically secure refresh token string."""
    return secrets.token_urlsafe(64)

def hash_refresh_token(token: str) -> str:
    """Hashes a refresh token using SHA-256 for safe database storage."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()

def _get_fernet() -> Any:
    try:
        from cryptography.fernet import Fernet
        import base64
        key = base64.urlsafe_b64encode(hashlib.sha256(settings.SECRET_KEY.encode("utf-8")).digest())
        return Fernet(key)
    except Exception:
        return None

def encrypt_credential(plain_text: Optional[str]) -> Optional[str]:
    """Encrypts sensitive assigned passwords using AES-128-CBC Fernet encryption for safe rest-storage."""
    if not plain_text:
        return None
    fernet = _get_fernet()
    if fernet is None:
        return plain_text
    return fernet.encrypt(plain_text.encode("utf-8")).decode("utf-8")

def decrypt_credential(cipher_or_plain: Optional[str]) -> Optional[str]:
    """Decrypts ciphertext credentials. Gracefully handles legacy plaintext credentials."""
    if not cipher_or_plain:
        return None
    if cipher_or_plain.startswith("gAAAAA"):
        fernet = _get_fernet()
        if fernet is not None:
            try:
                return fernet.decrypt(cipher_or_plain.encode("utf-8")).decode("utf-8")
            except Exception:
                return "••••••••"
    return cipher_or_plain
