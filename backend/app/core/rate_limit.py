from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional
from fastapi import HTTPException, status

class LoginRateLimiter:
    """
    Sliding window in-memory rate limiter for login authentication.
    Prevents brute-force credential stuffing and unauthorized dictionary attacks.
    """
    def __init__(self, max_attempts: int = 5, window_seconds: int = 900):
        self.max_attempts = max_attempts
        self.window_seconds = window_seconds
        # key -> list of UTC failure datetimes
        self._failures: Dict[str, List[datetime]] = {}

    def _cleanup(self, key: str, now: datetime) -> List[datetime]:
        cutoff = now - timedelta(seconds=self.window_seconds)
        attempts = [t for t in self._failures.get(key, []) if t > cutoff]
        if attempts:
            self._failures[key] = attempts
        else:
            self._failures.pop(key, None)
        return attempts

    def check_rate_limit(self, key: str) -> None:
        """Check whether the given key is currently rate-limited."""
        now = datetime.now(timezone.utc)
        recent_attempts = self._cleanup(key, now)
        if len(recent_attempts) >= self.max_attempts:
            oldest_relevant = recent_attempts[0]
            retry_after_seconds = int((oldest_relevant + timedelta(seconds=self.window_seconds) - now).total_seconds())
            retry_after_seconds = max(1, retry_after_seconds)
            retry_minutes = max(1, (retry_after_seconds + 59) // 60)
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Too many failed login attempts. Account temporarily locked for {retry_minutes} minute(s).",
                headers={"Retry-After": str(retry_after_seconds)},
            )

    def record_failed_attempt(self, key: str) -> None:
        """Record a failed login attempt for the key."""
        now = datetime.now(timezone.utc)
        if key not in self._failures:
            self._failures[key] = []
        self._failures[key].append(now)

    def record_successful_attempt(self, key: str) -> None:
        """Clear failed attempts upon successful authentication."""
        self._failures.pop(key, None)

    def reset(self) -> None:
        """Clear all rate limiting state (used for testing)."""
        self._failures.clear()

login_rate_limiter = LoginRateLimiter(max_attempts=5, window_seconds=900)
