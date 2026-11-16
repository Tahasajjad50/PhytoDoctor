import pytest
from httpx import AsyncClient, ASGITransport
from datetime import datetime, timezone
import uuid

from app.main import app
from app.core.security import create_access_token

@pytest.fixture(scope="function")
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as ac:
        yield ac

def auth_headers(user_id: str, role: str) -> dict:
    token = create_access_token(subject=user_id, role=role)
    return {"Authorization": f"Bearer {token}"}

OWNER_ID = "owner-uuid-1"
MANAGER_ID = "manager-uuid-2"
EMPLOYEE_ID = "employee-uuid-3"

# ==============================================================================
# PHASE 3: END-TO-END BUSINESS ACCEPTANCE WORKFLOW SUITE
# ==============================================================================

@pytest.mark.asyncio
async def test_employee_complete_field_workflow(client: AsyncClient):
    """
    Simulates the complete 13-step field agronomist daily workflow:
    Login -> Clock-In -> Status -> Record Visit -> Photo Link -> History -> Clock-Out -> Performance
    """
    # 1. Login
    r_login = await client.post("/api/v1/auth/login", json={
        "username_or_email": "emp.john",
        "password": "emp123",
        "portal": "employee"
    })
    assert r_login.status_code == 200
    token = r_login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Clock-In
    r_in = await client.post("/api/v1/attendance/clock-in", headers=headers)
    assert r_in.status_code == 200
    assert r_in.json()["is_active"] is True

    # 3. Attendance Status
    r_stat = await client.get("/api/v1/attendance/status", headers=headers)
    assert r_stat.status_code == 200
    assert r_stat.json()["is_active"] is True

    # 4. Record Visit
    now_str = datetime.now(timezone.utc).isoformat()
    asset_id = f"CLOUDINARY_ASSET_{uuid.uuid4().hex[:8]}"
    visit_data = {
        "client_name": "Rahim Yar Khan Model Cotton Farm",
        "client_phone": "03009876543",
        "latitude": 28.4212,
        "longitude": 70.3012,
        "gps_accuracy": 14.5,
        "is_mock_location": False,
        "device_capture_time": now_str,
        "photo_asset_id": asset_id,
        "notes": "Healthy boll formation observed, recommended preventive pest spray."
    }
    r_visit = await client.post("/api/v1/visits", json=visit_data, headers=headers)
    assert r_visit.status_code == 201
    visit_id = r_visit.json()["id"]

    # 5. Confirm Photo Association
    r_photo = await client.post(f"/api/v1/media/visits/{visit_id}/confirm-photo", json={
        "visit_id": visit_id,
        "photo_asset_id": asset_id,
        "photo_url": f"https://res.cloudinary.com/phytodoctor/image/upload/v17000/{asset_id}.jpg",
        "bytes_size": 245000,
        "format": "jpg",
        "width": 1920,
        "height": 1080
    }, headers=headers)
    assert r_photo.status_code == 200

    # 6. Secure Photo Access
    r_access = await client.get(f"/api/v1/media/visits/{visit_id}/photo-access", headers=headers)
    assert r_access.status_code == 200
    assert "secure_view_url" in r_access.json()

    # 7. View History
    r_hist = await client.get("/api/v1/visits", headers=headers)
    assert r_hist.status_code == 200

    # 8. Clock-Out
    r_out = await client.post("/api/v1/attendance/clock-out", headers=headers)
    assert r_out.status_code == 200
    assert r_out.json()["is_active"] is False

    # 9. View Performance
    r_perf = await client.get("/api/v1/employee/dashboard-summary", headers=headers)
    assert r_perf.status_code == 200
    assert "target_visits" in r_perf.json()


@pytest.mark.asyncio
async def test_manager_supervision_workflow(client: AsyncClient):
    """
    Simulates the 10-step regional manager field audit workflow:
    Login -> Team Roster -> Verification Queue -> GPS & Photo Audit -> Approve/Reject -> Team Performance
    """
    # 1. Login
    r_login = await client.post("/api/v1/auth/login", json={
        "username_or_email": "manager.punjab",
        "password": "manager123",
        "portal": "admin"
    })
    assert r_login.status_code == 200
    token = r_login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. View Supervised Team Roster
    r_roster = await client.get("/api/v1/attendance/admin/roster", headers=headers)
    assert r_roster.status_code == 200
    assert "employees" in r_roster.json()

    # 3. Create a Visit to Verify
    emp_token = create_access_token(subject=EMPLOYEE_ID, role="EMPLOYEE")
    now_str = datetime.now(timezone.utc).isoformat()
    asset_id = f"CLOUDINARY_MGR_{uuid.uuid4().hex[:8]}"
    r_v = await client.post("/api/v1/visits", json={
        "client_name": "Al-Rehman Agri Services",
        "latitude": 30.1575,
        "longitude": 71.5249,
        "gps_accuracy": 11.0,
        "is_mock_location": False,
        "device_capture_time": now_str,
        "photo_asset_id": asset_id,
        "notes": "Audit visit for supervisor verification"
    }, headers={"Authorization": f"Bearer {emp_token}"})
    assert r_v.status_code == 201
    visit_id = r_v.json()["id"]

    # 4. Verification Queue
    r_queue = await client.get("/api/v1/visits?status=PENDING", headers=headers)
    assert r_queue.status_code == 200

    # 5. Inspect Visit Details
    r_detail = await client.get(f"/api/v1/visits/{visit_id}", headers=headers)
    assert r_detail.status_code == 200

    # 6. Approve Visit
    r_approve = await client.post(f"/api/v1/visits/{visit_id}/verify", json={
        "status": "VERIFIED",
        "review_reason": "On-site GPS coordinates and crop condition verified."
    }, headers=headers)
    assert r_approve.status_code == 200
    assert r_approve.json()["status"] == "VERIFIED"

    # 7. Team Performance Comparison
    r_comp = await client.get("/api/v1/performance/team-comparison", headers=headers)
    assert r_comp.status_code == 200


@pytest.mark.asyncio
async def test_ceo_executive_workflow(client: AsyncClient):
    """
    Simulates the 8-step CEO/Executive Owner administrative workflow:
    Login -> Dashboard KPIs -> Account Directory -> Target Quotas -> Supervision -> Audit Logs
    """
    # 1. Login
    r_login = await client.post("/api/v1/auth/login", json={
        "username_or_email": "owner",
        "password": "owner123",
        "portal": "admin"
    })
    assert r_login.status_code == 200
    token = r_login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Executive Dashboard Stats
    r_stats = await client.get("/api/v1/admin/dashboard-stats", headers=headers)
    assert r_stats.status_code == 200
    assert "pending_verifications" in r_stats.json()

    # 3. Create New Employee Account (Password Encrypted at rest)
    rand_suffix = uuid.uuid4().hex[:6]
    r_create = await client.post("/api/v1/users/", json={
        "full_name": f"Test Agronomist {rand_suffix}",
        "email": f"agronomist.{rand_suffix}@phytodoctor.com",
        "username": f"emp.{rand_suffix}",
        "password": "TemporaryPassword123!",
        "role": "EMPLOYEE",
        "phone": "03001234567",
        "designation": "Junior Field Scout",
        "manager_id": MANAGER_ID,
        "is_active": True
    }, headers=headers)
    assert r_create.status_code == 201
    new_user_id = r_create.json()["id"]

    # 4. View Created Accounts Directory
    r_dir = await client.get("/api/v1/users/created-accounts", headers=headers)
    assert r_dir.status_code == 200

    # 5. Supervision Reassignment
    r_trans = await client.post("/api/v1/users/supervision/transfer", json={
        "employee_id": new_user_id,
        "new_manager_id": MANAGER_ID,
        "notes": "Assigned to Punjab Central Branch"
    }, headers=headers)
    assert r_trans.status_code == 200

    # 6. Update Company-wide Target Quotas
    r_quotas = await client.post("/api/v1/targets/quotas", json={
        "daily_visits": 7,
        "monthly_sales_pkr": 600000,
        "month": "November 2026"
    }, headers=headers)
    assert r_quotas.status_code == 200
    assert r_quotas.json()["quotas"]["daily_visits"] == 7

    # 7. Company Performance Overview
    r_ov = await client.get("/api/v1/performance/company-overview", headers=headers)
    assert r_ov.status_code == 200

    # 8. Audit Logs
    r_audit = await client.get("/api/v1/admin/audit-logs", headers=headers)
    assert r_audit.status_code == 200
