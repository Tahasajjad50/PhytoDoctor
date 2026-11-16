# 12 – APPLICATION SECURITY AUDIT

## 1. Authentication & JWT Hardening
- Passwords hashed using bcrypt (12 rounds) via `passlib[bcrypt]`.
- JWT access tokens signed with HMAC-SHA256 (`HS256`) and valid for 24 hours.
- Refresh tokens stored as SHA-256 hashes in `refresh_tokens` table with rotation and single-use revocation.

## 2. Rate Limiting & Brute Force Prevention
- Endpoint `/api/v1/auth/login` is governed by in-memory sliding window rate limiter in `backend/app/core/rate_limit.py`.
- **Policy:** 5 failed attempts within 5 minutes locks the username/IP for 15 minutes with HTTP 429.
- Verified on live server with `emp.zain` account lock scenario.

## 3. Role Escalation Prevention
- Endpoints strictly enforce role dependency guards:
  - `require_owner`: Only `OWNER` (CEO) can access system-wide audit logs and version configs.
  - `require_admin`: Only `OWNER` and `MANAGER` can review visits or provision employees.
  - Employees attempting administrative calls receive `HTTP 403 Forbidden`.

## 4. Credential Disclosure Remediation
- Removed server URL exposure from credentials sharing dialogs.
- Passwords in audit events are scrubbed (`***`) before database persistence.
