from datetime import date, datetime, timedelta, timezone
import pytest
from httpx import ASGITransport, AsyncClient
from app.core.config import settings
from app.main import app

@pytest.mark.asyncio
async def test_auth_login_and_token_refresh_strategy():
    """Tests short-lived access token, refresh token strategy, and token rotation."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Login
        login_resp = await client.post(
            "/api/v1/auth/login",
            json={"username_or_email": "emp.john", "password": "emp123", "portal": "employee"}
        )
        assert login_resp.status_code == 200
        data = login_resp.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["expires_in_seconds"] == settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
        refresh_token_1 = data["refresh_token"]

        # 2. Token Refresh
        refresh_resp = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token_1}
        )
        assert refresh_resp.status_code == 200
        refresh_data = refresh_resp.json()
        assert "access_token" in refresh_data
        assert "refresh_token" in refresh_data
        refresh_token_2 = refresh_data["refresh_token"]
        assert refresh_token_2 != refresh_token_1  # Rotated token

        # 3. Old refresh token should now be revoked and rejected
        revoked_resp = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token_1}
        )
        assert revoked_resp.status_code == 401

@pytest.mark.asyncio
async def test_logout_revokes_refresh_token():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        login_resp = await client.post(
            "/api/v1/auth/login",
            json={"username_or_email": "emp.john", "password": "emp123"}
        )
        tokens = login_resp.json()
        access_token = tokens["access_token"]
        refresh_token = tokens["refresh_token"]

        # Logout
        logout_resp = await client.post(
            "/api/v1/auth/logout",
            headers={"Authorization": f"Bearer {access_token}"},
            json={"refresh_token": refresh_token}
        )
        assert logout_resp.status_code == 200

        # Attempt to use revoked refresh token -> 401
        ref_resp = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token}
        )
        assert ref_resp.status_code == 401

@pytest.mark.asyncio
async def test_role_enforcement_and_unauthorized_admin_rejection():
    """
    SECURITY TEST: Employee attempting Admin Login or accessing admin routes
    must be actively rejected by backend authorization.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Admin login screen rejects employee credentials
        emp_admin_login = await client.post(
            "/api/v1/auth/login",
            json={"username_or_email": "emp.john", "password": "emp123", "portal": "admin"}
        )
        assert emp_admin_login.status_code == 403
        assert "Access denied" in emp_admin_login.json()["detail"]

        # 2. Employee token cannot access user provisioning endpoint
        emp_login = await client.post(
            "/api/v1/auth/login",
            json={"username_or_email": "emp.john", "password": "emp123", "portal": "employee"}
        )
        emp_token = emp_login.json()["access_token"]
        headers = {"Authorization": f"Bearer {emp_token}"}

        create_user_resp = await client.post(
            "/api/v1/users/",
            headers=headers,
            json={
                "full_name": "Attacker",
                "email": "attacker@fake.com",
                "username": "attacker",
                "password": "password123",
                "role": "OWNER"
            }
        )
        assert create_user_resp.status_code == 403

@pytest.mark.asyncio
async def test_user_management_by_owner():
    """Owner can provision employees, deactivate them, and reset passwords."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        owner_login = await client.post(
            "/api/v1/auth/login",
            json={"username_or_email": "owner", "password": "owner123", "portal": "admin"}
        )
        owner_token = owner_login.json()["access_token"]
        headers = {"Authorization": f"Bearer {owner_token}"}

        # 1. Create new employee
        new_emp = await client.post(
            "/api/v1/users/",
            headers=headers,
            json={
                "full_name": "Ali Hassan",
                "email": "ali.hassan@phytodoctor.com",
                "username": "emp.ali",
                "password": "password123",
                "role": "EMPLOYEE",
                "manager_id": "manager-uuid-2"
            }
        )
        assert new_emp.status_code == 201
        created_id = new_emp.json()["id"]

        # 2. Deactivate employee
        deact_resp = await client.post(
            f"/api/v1/users/{created_id}/deactivate",
            headers=headers
        )
        assert deact_resp.status_code == 200

        # 3. Deactivated employee cannot log in
        blocked_login = await client.post(
            "/api/v1/auth/login",
            json={"username_or_email": "emp.ali", "password": "password123"}
        )
        assert blocked_login.status_code == 403

        # 4. Reset password
        reset_resp = await client.post(
            f"/api/v1/users/{created_id}/reset-password",
            headers=headers,
            json={"new_password": "new_secure_password_456"}
        )
        assert reset_resp.status_code == 200

@pytest.mark.asyncio
async def test_field_visit_creation_and_verification_flow():
    """
    Tests field visit submission, supervisor verification, and performance calculation:
    Only VERIFIED visits count towards performance!
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Login as employee
        emp_login = await client.post(
            "/api/v1/auth/login",
            json={"username_or_email": "emp.john", "password": "emp123"}
        )
        emp_token = emp_login.json()["access_token"]
        emp_headers = {"Authorization": f"Bearer {emp_token}"}

        # 2. Submit field visit
        capture_time = datetime.now(timezone.utc) - timedelta(minutes=5)
        visit_resp = await client.post(
            "/api/v1/visits/",
            headers=emp_headers,
            json={
                "client_name": "Al-Madina Agro Chemicals",
                "client_phone": "03001234567",
                "notes": "Discussed bio-fungicide batch distribution.",
                "latitude": 31.5204,
                "longitude": 74.3587,
                "gps_accuracy": 12.4,
                "is_mock_location": False,
                "device_capture_time": capture_time.isoformat(),
                "photo_asset_id": "cloudinary_leaf_photo_12345",
                "photo_url": "https://res.cloudinary.com/phyto/image/upload/v1/sample.webp"
            }
        )
        assert visit_resp.status_code == 201
        visit = visit_resp.json()
        assert visit["status"] == "PENDING"
        visit_id = visit["id"]

        # 3. Check performance BEFORE verification: Verified count must be 0!
        perf_before = await client.get(
            f"/api/v1/performance/employee/employee-uuid-3/summary",
            headers=emp_headers
        )
        assert perf_before.status_code == 200
        assert perf_before.json()["verified_visits"] == 0
        assert perf_before.json()["pending_sync_count"] == 1

        # 4. Employee CANNOT verify their own visit -> 403 Forbidden
        emp_verify_attempt = await client.post(
            f"/api/v1/visits/{visit_id}/verify",
            headers=emp_headers,
            json={"status": "VERIFIED"}
        )
        assert emp_verify_attempt.status_code == 403

        # 5. Login as Manager to verify
        mgr_login = await client.post(
            "/api/v1/auth/login",
            json={"username_or_email": "manager.punjab", "password": "manager123", "portal": "admin"}
        )
        mgr_token = mgr_login.json()["access_token"]
        mgr_headers = {"Authorization": f"Bearer {mgr_token}"}

        verify_resp = await client.post(
            f"/api/v1/visits/{visit_id}/verify",
            headers=mgr_headers,
            json={
                "status": "VERIFIED",
                "review_reason": "GPS coordinates and shop board photo confirmed on site."
            }
        )
        assert verify_resp.status_code == 200
        assert verify_resp.json()["status"] == "VERIFIED"

        # 6. Check performance AFTER verification: Verified count must increment to 1!
        perf_after = await client.get(
            f"/api/v1/performance/employee/employee-uuid-3/summary",
            headers=emp_headers
        )
        assert perf_after.status_code == 200
        assert perf_after.json()["verified_visits"] == 1
        assert perf_after.json()["remaining_visits"] == 5

@pytest.mark.asyncio
async def test_target_creation_and_scoping():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        mgr_login = await client.post(
            "/api/v1/auth/login",
            json={"username_or_email": "manager.punjab", "password": "manager123", "portal": "admin"}
        )
        mgr_headers = {"Authorization": f"Bearer {mgr_login.json()['access_token']}"}

        today = date.today()
        target_resp = await client.post(
            "/api/v1/targets/",
            headers=mgr_headers,
            json={
                "employee_id": "employee-uuid-3",
                "target_count": 8,
                "period_type": "DAILY",
                "start_date": today.isoformat(),
                "end_date": today.isoformat()
            }
        )
        assert target_resp.status_code == 201
        assert target_resp.json()["target_count"] == 8

@pytest.mark.asyncio
async def test_health_check_endpoint():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/api/v1/health")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "healthy"
        assert data["database_connected"] is True
        assert "utc_timestamp" in data
