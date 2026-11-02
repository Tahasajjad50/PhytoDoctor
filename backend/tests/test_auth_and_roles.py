import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app

@pytest.mark.asyncio
async def test_employee_login_success():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Test login via username
        response = await client.post(
            "/api/v1/auth/login",
            json={
                "username_or_email": "emp.john",
                "password": "emp123",
                "portal": "employee"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["user"]["role"] == "EMPLOYEE"
        assert data["user"]["username"] == "emp.john"

        # Test login via email
        response2 = await client.post(
            "/api/v1/auth/login",
            json={
                "username_or_email": "employee@phytodoctor.com",
                "password": "emp123",
                "portal": "employee"
            }
        )
        assert response2.status_code == 200

@pytest.mark.asyncio
async def test_admin_login_success_for_owner_and_manager():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Owner login in admin portal
        owner_resp = await client.post(
            "/api/v1/auth/login",
            json={
                "username_or_email": "owner@phytodoctor.com",
                "password": "owner123",
                "portal": "admin"
            }
        )
        assert owner_resp.status_code == 200
        assert owner_resp.json()["user"]["role"] == "OWNER"

        # Manager login in admin portal
        mgr_resp = await client.post(
            "/api/v1/auth/login",
            json={
                "username_or_email": "manager.punjab",
                "password": "manager123",
                "portal": "admin"
            }
        )
        assert mgr_resp.status_code == 200
        assert mgr_resp.json()["user"]["role"] == "MANAGER"

@pytest.mark.asyncio
async def test_employee_forbidden_from_admin_login():
    """
    SECURITY TEST: An employee must NOT be able to log in through the Admin Login portal.
    Backend must actively reject with HTTP 403 Forbidden.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/api/v1/auth/login",
            json={
                "username_or_email": "emp.john",
                "password": "emp123",
                "portal": "admin"
            }
        )
        assert response.status_code == 403
        data = response.json()
        assert "Access denied" in data["detail"]
        assert "Administrator" in data["detail"]

@pytest.mark.asyncio
async def test_incorrect_login_attempts():
    """
    SECURITY TEST: Incorrect password or non-existent user must return 401.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Wrong password
        resp1 = await client.post(
            "/api/v1/auth/login",
            json={
                "username_or_email": "emp.john",
                "password": "wrong_password",
                "portal": "employee"
            }
        )
        assert resp1.status_code == 401
        assert "Incorrect" in resp1.json()["detail"]

        # Non-existent user
        resp2 = await client.post(
            "/api/v1/auth/login",
            json={
                "username_or_email": "nonexistent@phytodoctor.com",
                "password": "emp123",
                "portal": "employee"
            }
        )
        assert resp2.status_code == 401

@pytest.mark.asyncio
async def test_inactive_account_blocked():
    """
    SECURITY TEST: Inactive accounts must be blocked from logging in.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post(
            "/api/v1/auth/login",
            json={
                "username_or_email": "inactive@phytodoctor.com",
                "password": "emp123",
                "portal": "employee"
            }
        )
        assert resp.status_code == 403
        assert "deactivated" in resp.json()["detail"].lower()

@pytest.mark.asyncio
async def test_backend_endpoint_role_enforcement():
    """
    SECURITY TEST: Even if an employee obtains a token, backend endpoints
    requiring admin privileges must enforce role checking and return 403.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Log in as employee to get employee token
        emp_login = await client.post(
            "/api/v1/auth/login",
            json={"username_or_email": "emp.john", "password": "emp123", "portal": "employee"}
        )
        emp_token = emp_login.json()["access_token"]
        emp_headers = {"Authorization": f"Bearer {emp_token}"}

        # 2. Employee accesses employee dashboard summary -> 200 OK
        emp_summary = await client.get("/api/v1/employee/dashboard-summary", headers=emp_headers)
        assert emp_summary.status_code == 200
        assert emp_summary.json()["role"] == "EMPLOYEE"

        # 3. Employee attempts to access admin dashboard -> 403 Forbidden!
        admin_attempt = await client.get("/api/v1/admin/dashboard-stats", headers=emp_headers)
        assert admin_attempt.status_code == 403
        assert "Access denied" in admin_attempt.json()["detail"]

        # 4. Log in as manager to get admin token
        mgr_login = await client.post(
            "/api/v1/auth/login",
            json={"username_or_email": "manager.punjab", "password": "manager123", "portal": "admin"}
        )
        mgr_token = mgr_login.json()["access_token"]
        mgr_headers = {"Authorization": f"Bearer {mgr_token}"}

        # 5. Manager accesses admin dashboard -> 200 OK
        admin_stats = await client.get("/api/v1/admin/dashboard-stats", headers=mgr_headers)
        assert admin_stats.status_code == 200
        assert admin_stats.json()["role"] == "MANAGER"

@pytest.mark.asyncio
async def test_unauthenticated_request_rejected():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/api/v1/auth/me")
        assert resp.status_code == 401

@pytest.mark.asyncio
async def test_login_rate_limiting_lockout_after_consecutive_failures():
    """
    SECURITY TEST: Rate limiter must reject excessive failed login attempts with HTTP 429 Too Many Requests.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        target_username = "emp.john"
        
        # 1-5. First 5 failed attempts return 401 Unauthorized
        for i in range(5):
            resp = await client.post(
                "/api/v1/auth/login",
                json={
                    "username_or_email": target_username,
                    "password": f"incorrect_guess_{i}",
                    "portal": "employee"
                }
            )
            assert resp.status_code == 401

        # 6. The 6th attempt must be blocked by rate limiter with 429 Too Many Requests
        resp_blocked = await client.post(
            "/api/v1/auth/login",
            json={
                "username_or_email": target_username,
                "password": "emp123",  # Even with correct password, user is locked out!
                "portal": "employee"
            }
        )
        assert resp_blocked.status_code == 429
        assert "Too many failed login attempts" in resp_blocked.json()["detail"]
        assert "Retry-After" in resp_blocked.headers

