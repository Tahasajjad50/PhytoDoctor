# 07 – BACKEND API TESTS & SPECIFICATION

All endpoints verified against FastAPI OpenAPI 3.1 specification at `/api/v1/openapi.json`.

| Method | Endpoint | Authorized Roles | Expected Code | Live Verified |
|---|---|---|---|---|
| `POST` | `/api/v1/auth/login` | Public | 200 / 401 / 403 / 429 | **PASS** |
| `POST` | `/api/v1/auth/refresh` | Public | 200 / 401 | **PASS** |
| `GET` | `/api/v1/health` | Public | 200 OK | **PASS** |
| `GET` | `/api/v1/system/version` | Public | 200 OK | **PASS** |
| `POST` | `/api/v1/attendance/clock-in` | EMPLOYEE | 200 OK | **PASS** |
| `POST` | `/api/v1/attendance/clock-out`| EMPLOYEE | 200 OK | **PASS** |
| `GET` | `/api/v1/attendance/status` | EMPLOYEE | 200 OK | **PASS** |
| `GET` | `/api/v1/attendance/admin/roster` | OWNER, MANAGER | 200 OK | **PASS** |
| `GET` | `/api/v1/visits` | ALL (Scoped) | 200 OK | **PASS** |
| `POST` | `/api/v1/visits` | EMPLOYEE | 201 Created | **PASS** |
| `GET` | `/api/v1/visits/{id}` | ALL (Scoped) | 200 / 404 | **PASS** |
| `POST` | `/api/v1/visits/{id}/verify` | OWNER, MANAGER | 200 OK | **PASS** |
| `GET` | `/api/v1/admin/dashboard-stats` | OWNER, MANAGER | 200 OK | **PASS** |
| `GET` | `/api/v1/admin/audit-logs` | OWNER, MANAGER | 200 OK | **PASS** |
| `GET` | `/api/v1/users/created-accounts`| OWNER, MANAGER | 200 OK | **PASS** |
| `POST` | `/api/v1/users/supervision/transfer`| OWNER, MANAGER | 200 OK | **PASS** |
| `GET` | `/api/v1/performance/employee/{id}/analytics`| ALL (Scoped) | 200 OK | **PASS** |
