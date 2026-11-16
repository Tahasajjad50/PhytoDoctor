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

def _derive_fernet_key(raw_secret: str) -> bytes:
    import base64
    return base64.urlsafe_b64encode(hashlib.sha256(raw_secret.encode("utf-8")).digest())

def _get_primary_fernet() -> Any:
    try:
        from cryptography.fernet import Fernet
        secret = settings.CREDENTIAL_ENCRYPTION_KEY or settings.SECRET_KEY
        return Fernet(_derive_fernet_key(secret))
    except Exception:
        return None

def _get_fallback_fernets() -> list:
    """Returns list of fallback Fernet instances for key rotation and backwards compatibility."""
    fernets = []
    try:
        from cryptography.fernet import Fernet
        # 1. Any explicitly configured rotation fallback keys
        for fb_key in settings.CREDENTIAL_ENCRYPTION_KEY_FALLBACKS:
            if fb_key:
                fernets.append(Fernet(_derive_fernet_key(fb_key)))
        # 2. Legacy fallback: SECRET_KEY-derived key (Phase 2 & Phase 3 baseline)
        if settings.SECRET_KEY:
            fernets.append(Fernet(_derive_fernet_key(settings.SECRET_KEY)))
    except Exception:
        pass
    return fernets

CURRENT_CREDENTIAL_KEY_VERSION = "v1"

def encrypt_credential(plain_text: Optional[str]) -> Optional[str]:
    """
    Encrypts sensitive assigned passwords using AES-128-CBC Fernet encryption with key version prefix.
    Format: 'v1:<fernet_token>'
    """
    if not plain_text:
        return None
    fernet = _get_primary_fernet()
    if fernet is None:
        return plain_text
    cipher_bytes = fernet.encrypt(plain_text.encode("utf-8"))
    return f"{CURRENT_CREDENTIAL_KEY_VERSION}:{cipher_bytes.decode('utf-8')}"

def decrypt_credential(cipher_or_plain: Optional[str]) -> Optional[str]:
    """
    Decrypts ciphertext credentials.
    Supports:
      - Versioned tokens: 'v1:gAAAAA...'
      - Legacy unversioned tokens: 'gAAAAA...' (tries primary key then fallback keys)
      - Plaintext fallback during initial bootstrap
    """
    if not cipher_or_plain:
        return None

    raw_cipher = cipher_or_plain
    is_versioned = False
    if cipher_or_plain.startswith("v1:"):
        raw_cipher = cipher_or_plain[3:]
        is_versioned = True

    if raw_cipher.startswith("gAAAAA"):
        # 1. Try primary Fernet instance
        primary = _get_primary_fernet()
        if primary is not None:
            try:
                return primary.decrypt(raw_cipher.encode("utf-8")).decode("utf-8")
            except Exception:
                pass

        # 2. Try rotation / legacy fallback Fernet instances
        for fallback_fernet in _get_fallback_fernets():
            try:
                return fallback_fernet.decrypt(raw_cipher.encode("utf-8")).decode("utf-8")
            except Exception:
                continue

        return "••••••••"

    return cipher_or_plain

def rotate_credential(cipher_or_plain: Optional[str]) -> Optional[str]:
    """Re-encrypts a credential with the latest primary encryption key and version prefix."""
    if not cipher_or_plain:
        return None
    decrypted = decrypt_credential(cipher_or_plain)
    if decrypted and decrypted != "••••••••":
        return encrypt_credential(decrypted)
    return cipher_or_plain
