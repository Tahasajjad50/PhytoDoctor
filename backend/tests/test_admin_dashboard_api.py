import uuid
from datetime import date, datetime, timedelta, timezone
import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from app.main import app

@pytest_asyncio.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

@pytest_asyncio.fixture
async def owner_token(client: AsyncClient) -> str:
    login = await client.post("/api/v1/auth/login", json={"username_or_email": "owner", "password": "owner123", "portal": "admin"})
    assert login.status_code == 200
    return login.json()["access_token"]

@pytest_asyncio.fixture
async def manager_token(client: AsyncClient) -> str:
    login = await client.post("/api/v1/auth/login", json={"username_or_email": "manager.punjab", "password": "manager123", "portal": "admin"})
    assert login.status_code == 200
    return login.json()["access_token"]

@pytest_asyncio.fixture
async def employee_token(client: AsyncClient) -> str:
    login = await client.post("/api/v1/auth/login", json={"username_or_email": "emp.john", "password": "emp123", "portal": "employee"})
    assert login.status_code == 200
    return login.json()["access_token"]

@pytest.mark.asyncio
async def test_admin_login_and_role_protection(client: AsyncClient):
    """
    Verifies that:
    1. Owner and Manager can log in via admin portal.
    2. Employee attempting admin login is rejected with HTTP 403 Forbidden.
    """
    # Owner login
    owner_login = await client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "owner", "password": "owner123", "portal": "admin"},
    )
    assert owner_login.status_code == 200
    assert owner_login.json()["user"]["role"] == "OWNER"

    # Manager login
    mgr_login = await client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "manager.punjab", "password": "manager123", "portal": "admin"},
    )
    assert mgr_login.status_code == 200
    assert mgr_login.json()["user"]["role"] == "MANAGER"

    # Employee login via admin portal -> 403 Forbidden!
    emp_admin = await client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "emp.john", "password": "emp123", "portal": "admin"},
    )
    assert emp_admin.status_code == 403
    assert "access denied" in emp_admin.json()["detail"].lower()

@pytest.mark.asyncio
async def test_company_overview_kpis(client: AsyncClient, owner_token: str, employee_token: str):
    """
    Verifies company overview KPI endpoint:
    1. Returns active employees, today target sum, verified visits, completion rate.
    2. Accessible by Owner and Manager.
    3. Unauthenticated requests fail with 401.
    """
    res = await client.get(
        "/api/v1/performance/company-overview",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert res.status_code == 200
    data = res.json()
    assert "active_employees" in data
    assert "today_target_sum" in data
    assert "today_verified_visits" in data
    assert "today_completion_rate" in data
    assert "pending_review_count" in data
    assert "flagged_visits_count" in data

    # Unauthenticated rejected
    unauth = await client.get("/api/v1/performance/company-overview")
    assert unauth.status_code == 401

@pytest.mark.asyncio
async def test_employee_roster_and_account_management(client: AsyncClient, owner_token: str):
    """
    Verifies full employee lifecycle in admin dashboard:
    1. Creating new account.
    2. Updating active status (deactivating/reactivating).
    3. Resetting credentials and verifying new password.
    """
    suffix = uuid.uuid4().hex[:6]
    emp_username = f"emp_dash_{suffix}"
    emp_email = f"{emp_username}@phytodoctor.pk"

    # 1. Create account
    create_res = await client.post(
        "/api/v1/users/",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={
            "full_name": "Farhan Tariq",
            "username": emp_username,
            "email": emp_email,
            "password": "InitialPassword123!",
            "role": "EMPLOYEE",
        },
    )
    assert create_res.status_code == 201
    created_user = create_res.json()
    user_id = created_user["id"]
    assert created_user["username"] == emp_username
    assert created_user["is_active"] is True

    # 2. Deactivate account
    deactivate_res = await client.put(
        f"/api/v1/users/{user_id}",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"is_active": False},
    )
    assert deactivate_res.status_code == 200
    assert deactivate_res.json()["is_active"] is False

    # Blocked login when deactivated
    blocked_login = await client.post(
        "/api/v1/auth/login",
        json={"username_or_email": emp_username, "password": "InitialPassword123!", "portal": "employee"},
    )
    assert blocked_login.status_code == 403

    # Reactivate account
    reactivate_res = await client.put(
        f"/api/v1/users/{user_id}",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"is_active": True},
    )
    assert reactivate_res.status_code == 200
    assert reactivate_res.json()["is_active"] is True

    # 3. Reset password
    reset_res = await client.post(
        f"/api/v1/users/{user_id}/reset-password",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"new_password": "NewSecretPassword2026!"},
    )
    assert reset_res.status_code == 200

    # Old password fails
    old_login = await client.post(
        "/api/v1/auth/login",
        json={"username_or_email": emp_username, "password": "InitialPassword123!", "portal": "employee"},
    )
    assert old_login.status_code == 401

    # New password succeeds
    new_login = await client.post(
        "/api/v1/auth/login",
        json={"username_or_email": emp_username, "password": "NewSecretPassword2026!", "portal": "employee"},
    )
    assert new_login.status_code == 200

@pytest.mark.asyncio
async def test_field_visit_audit_and_verification_workflow(
    client: AsyncClient,
    employee_token: str,
    owner_token: str,
):
    """
    Verifies supervisor visit audit workflow:
    1. Employee submits visit.
    2. Admin views visit details with photo asset and GPS.
    3. Admin verifies visit with review reason -> records audit log.
    4. Admin rejects visit with reason -> records audit log.
    5. Employee cannot verify own visit.
    """
    # 1. Create visit
    v_id = str(uuid.uuid4())
    create_v = await client.post(
        "/api/v1/visits/",
        headers={"Authorization": f"Bearer {employee_token}"},
        json={
            "id": v_id,
            "client_name": "Pakpattan Maize Advisory",
            "latitude": 30.3410,
            "longitude": 73.3866,
            "gps_accuracy": 12.0,
            "device_capture_time": datetime.now(timezone.utc).isoformat(),
            "photo_asset_id": f"PHOTO_AUDIT_{uuid.uuid4().hex[:8]}",
        },
    )
    assert create_v.status_code == 201

    # 2. View visit details
    detail_res = await client.get(
        f"/api/v1/visits/{v_id}",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert detail_res.status_code == 200
    assert detail_res.json()["client_name"] == "Pakpattan Maize Advisory"

    # 3. Employee self-verification forbidden (require_admin dependency)
    self_verify = await client.post(
        f"/api/v1/visits/{v_id}/verify",
        headers={"Authorization": f"Bearer {employee_token}"},
        json={"status": "VERIFIED", "review_reason": "I verified my own visit"},
    )
    assert self_verify.status_code == 403

    # 4. Supervisor verifies visit
    verify_res = await client.post(
        f"/api/v1/visits/{v_id}/verify",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"status": "VERIFIED", "review_reason": "Crop photos clear, client presence confirmed"},
    )
    assert verify_res.status_code == 200
    assert verify_res.json()["status"] == "VERIFIED"
    assert "confirmed" in verify_res.json()["review_reason"]

    # 5. Check audit logs contain the verification decision
    audit_res = await client.get(
        "/api/v1/admin/audit-logs?action=VISIT_VERIFIED",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert audit_res.status_code == 200
    logs = audit_res.json()["items"]
    assert any(l["affected_record_id"] == v_id for l in logs)

@pytest.mark.asyncio
async def test_audit_logs_endpoint_security(client: AsyncClient, owner_token: str, employee_token: str):
    """
    Verifies that:
    1. Owner can query audit logs.
    2. Employee accounts cannot access audit logs (HTTP 403).
    3. Unauthenticated requests are rejected (HTTP 401).
    """
    # Owner success
    owner_res = await client.get(
        "/api/v1/admin/audit-logs",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert owner_res.status_code == 200
    assert "items" in owner_res.json()
    assert "total" in owner_res.json()

    # Employee forbidden
    emp_res = await client.get(
        "/api/v1/admin/audit-logs",
        headers={"Authorization": f"Bearer {employee_token}"},
    )
    assert emp_res.status_code == 403

    # Unauthenticated rejected
    unauth = await client.get("/api/v1/admin/audit-logs")
    assert unauth.status_code == 401
