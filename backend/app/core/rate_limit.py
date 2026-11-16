import os
import sqlite3
import tempfile
import time
from typing import Optional
from fastapi import HTTPException, status
from app.core.config import settings

try:
    import redis
except ImportError:
    redis = None


class LoginRateLimiter:
    """
    Production-grade distributed / cross-worker sliding window rate limiter for login.
    Supports:
      1. Redis when REDIS_URL is configured and redis-py is installed.
      2. File-backed SQLite database (default) shared across all Uvicorn worker processes.
    """
    def __init__(
        self,
        max_attempts: int = 5,
        window_seconds: int = 900,
        db_path: Optional[str] = None
    ):
        self.max_attempts = max_attempts
        self.window_seconds = window_seconds
        self._redis_client = None
        self._init_redis()
        
        if db_path is None:
            self.db_path = os.path.join(tempfile.gettempdir(), "phyto_rate_limits.sqlite3")
        else:
            self.db_path = db_path
            
        self._init_sqlite()

    def _init_redis(self):
        if settings.REDIS_URL and redis is not None:
            try:
                self._redis_client = redis.Redis.from_url(settings.REDIS_URL, decode_responses=True)
                self._redis_client.ping()
            except Exception:
                self._redis_client = None

    def _get_sqlite_conn(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, timeout=10.0)
        conn.execute("PRAGMA journal_mode=WAL")
        return conn

    def _init_sqlite(self):
        try:
            with self._get_sqlite_conn() as conn:
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS login_attempts (
                        identifier TEXT NOT NULL,
                        timestamp REAL NOT NULL
                    )
                    """
                )
                conn.execute(
                    "CREATE INDEX IF NOT EXISTS idx_login_ident_ts ON login_attempts(identifier, timestamp)"
                )
        except Exception as e:
            print(f"[RateLimiter Warning] Failed to initialize SQLite store: {e}")

    def check_rate_limit(self, key: str) -> None:
        key = key.strip().lower()
        now = time.time()
        cutoff = now - self.window_seconds

        if self._redis_client:
            try:
                redis_key = f"ratelimit:login:{key}"
                self._redis_client.zremrangebyscore(redis_key, "-inf", cutoff)
                count = self._redis_client.zcard(redis_key)
                if count >= self.max_attempts:
                    oldest_items = self._redis_client.zrange(redis_key, 0, 0, withscores=True)
                    oldest_ts = oldest_items[0][1] if oldest_items else cutoff
                    retry_after_seconds = max(1, int(oldest_ts + self.window_seconds - now))
                    retry_minutes = max(1, (retry_after_seconds + 59) // 60)
                    raise HTTPException(
                        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                        detail=f"Too many failed login attempts. Account temporarily locked for {retry_minutes} minute(s).",
                        headers={"Retry-After": str(retry_after_seconds)},
                    )
                return
            except HTTPException:
                raise
            except Exception as e:
                print(f"[RateLimiter Warning] Redis check failed: {e}")

        # Fallback to shared SQLite store across all processes
        try:
            with self._get_sqlite_conn() as conn:
                conn.execute("DELETE FROM login_attempts WHERE identifier = ? AND timestamp <= ?", (key, cutoff))
                cursor = conn.execute(
                    "SELECT timestamp FROM login_attempts WHERE identifier = ? AND timestamp > ? ORDER BY timestamp ASC",
                    (key, cutoff)
                )
                rows = cursor.fetchall()
                if len(rows) >= self.max_attempts:
                    oldest_ts = rows[0][0]
                    retry_after_seconds = max(1, int(oldest_ts + self.window_seconds - now))
                    retry_minutes = max(1, (retry_after_seconds + 59) // 60)
                    raise HTTPException(
                        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                        detail=f"Too many failed login attempts. Account temporarily locked for {retry_minutes} minute(s).",
                        headers={"Retry-After": str(retry_after_seconds)},
                    )
        except HTTPException:
            raise
        except Exception as e:
            print(f"[RateLimiter Warning] SQLite check failed: {e}")

    def record_failed_attempt(self, key: str) -> None:
        key = key.strip().lower()
        now = time.time()
        cutoff = now - self.window_seconds

        if self._redis_client:
            try:
                redis_key = f"ratelimit:login:{key}"
                self._redis_client.zadd(redis_key, {str(now): now})
                self._redis_client.expire(redis_key, self.window_seconds + 60)
                return
            except Exception as e:
                print(f"[RateLimiter Warning] Redis record failed: {e}")

        try:
            with self._get_sqlite_conn() as conn:
                conn.execute(
                    "INSERT INTO login_attempts (identifier, timestamp) VALUES (?, ?)",
                    (key, now)
                )
                conn.execute("DELETE FROM login_attempts WHERE identifier = ? AND timestamp <= ?", (key, cutoff))
        except Exception as e:
            print(f"[RateLimiter Warning] SQLite record failed: {e}")

    def record_successful_attempt(self, key: str) -> None:
        key = key.strip().lower()
        if self._redis_client:
            try:
                self._redis_client.delete(f"ratelimit:login:{key}")
                return
            except Exception as e:
                print(f"[RateLimiter Warning] Redis clear failed: {e}")

        try:
            with self._get_sqlite_conn() as conn:
                conn.execute("DELETE FROM login_attempts WHERE identifier = ?", (key,))
        except Exception as e:
            print(f"[RateLimiter Warning] SQLite clear failed: {e}")

    def reset(self) -> None:
        if self._redis_client:
            try:
                keys = self._redis_client.keys("ratelimit:login:*")
                if keys:
                    self._redis_client.delete(*keys)
            except Exception as e:
                print(f"[RateLimiter Warning] Redis reset failed: {e}")

        try:
            with self._get_sqlite_conn() as conn:
                conn.execute("DELETE FROM login_attempts")
        except Exception as e:
            print(f"[RateLimiter Warning] SQLite reset failed: {e}")


login_rate_limiter = LoginRateLimiter(max_attempts=5, window_seconds=900)
