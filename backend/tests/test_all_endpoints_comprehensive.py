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
# Comprehensive Endpoint Verification Suite (48 Registered Endpoints)
# ==============================================================================

@pytest.mark.asyncio
async def test_health_and_root(client: AsyncClient):
    r1 = await client.get("/api/v1/health")
    assert r1.status_code == 200
    assert r1.json()["status"] == "healthy"

    r2 = await client.get("/")
    assert r2.status_code == 200

@pytest.mark.asyncio
async def test_auth_endpoints(client: AsyncClient):
    # 1. Login Valid
    r = await client.post("/api/v1/auth/login", json={
        "username_or_email": "owner",
        "password": "owner123",
        "portal": "admin"
    })
    assert r.status_code == 200
    tokens = r.json()
    assert "access_token" in tokens
    
    # 2. Login Invalid Password
    r_bad = await client.post("/api/v1/auth/login", json={
        "username_or_email": "owner",
        "password": "WrongPassword",
        "portal": "admin"
    })
    assert r_bad.status_code == 401

    # 3. /auth/me Valid
    r_me = await client.get("/api/v1/auth/me", headers=auth_headers(OWNER_ID, "OWNER"))
    assert r_me.status_code == 200
    assert r_me.json()["username"] == "owner"

    # 4. /auth/me Unauthenticated
    r_me_unauth = await client.get("/api/v1/auth/me")
    assert r_me_unauth.status_code == 401

    # 5. /auth/refresh
    r_ref = await client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert r_ref.status_code == 200

    # 6. /auth/logout
    r_logout = await client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": tokens["refresh_token"]},
        headers={"Authorization": f"Bearer {tokens['access_token']}"}
    )
    assert r_logout.status_code == 200

@pytest.mark.asyncio
async def test_attendance_endpoints(client: AsyncClient):
    # 1. Clock In (Employee)
    r_in = await client.post("/api/v1/attendance/clock-in", headers=auth_headers(EMPLOYEE_ID, "EMPLOYEE"))
    assert r_in.status_code == 200
    assert r_in.json()["is_active"] is True

    # 2. Status (Employee)
    r_stat = await client.get("/api/v1/attendance/status", headers=auth_headers(EMPLOYEE_ID, "EMPLOYEE"))
    assert r_stat.status_code == 200
    assert r_stat.json()["is_active"] is True

    # 3. Manager Roster (Manager)
    r_roster = await client.get("/api/v1/attendance/admin/roster", headers=auth_headers(MANAGER_ID, "MANAGER"))
    assert r_roster.status_code == 200
    assert "employees" in r_roster.json()

    # 4. Employee calling Roster -> 403 Forbidden
    r_roster_emp = await client.get("/api/v1/attendance/admin/roster", headers=auth_headers(EMPLOYEE_ID, "EMPLOYEE"))
    assert r_roster_emp.status_code == 403

    # 5. Clock Out (Employee)
    r_out = await client.post("/api/v1/attendance/clock-out", headers=auth_headers(EMPLOYEE_ID, "EMPLOYEE"))
    assert r_out.status_code == 200
    assert r_out.json()["is_active"] is False

@pytest.mark.asyncio
async def test_visit_endpoints(client: AsyncClient):
    now_str = datetime.now(timezone.utc).isoformat()
    asset_id = f"ASSET_{uuid.uuid4().hex[:8]}"

    # 1. Evidence Policy
    r_pol = await client.get("/api/v1/visits/evidence-policy")
    assert r_pol.status_code == 200

    # 2. Create Visit Valid (Employee)
    visit_payload = {
        "client_name": "Al-Madina Farm",
        "latitude": 30.1575,
        "longitude": 71.5249,
        "gps_accuracy": 12.0,
        "is_mock_location": False,
        "device_capture_time": now_str,
        "photo_asset_id": asset_id,
        "notes": "Testing field visit creation"
    }
    r_create = await client.post("/api/v1/visits", json=visit_payload, headers=auth_headers(EMPLOYEE_ID, "EMPLOYEE"))
    assert r_create.status_code == 201
    visit_id = r_create.json()["id"]

    # 3. Create Visit Missing Fields -> 422
    r_bad = await client.post("/api/v1/visits", json={"client_name": ""}, headers=auth_headers(EMPLOYEE_ID, "EMPLOYEE"))
    assert r_bad.status_code == 422

    # 4. List Visits (Manager)
    r_list = await client.get("/api/v1/visits", headers=auth_headers(MANAGER_ID, "MANAGER"))
    assert r_list.status_code == 200
    assert r_list.json()["total"] >= 1

    # 5. Get Visit Details
    r_det = await client.get(f"/api/v1/visits/{visit_id}", headers=auth_headers(MANAGER_ID, "MANAGER"))
    assert r_det.status_code == 200

    # 6. Verify Visit (Manager)
    r_ver = await client.post(f"/api/v1/visits/{visit_id}/verify", json={
        "status": "VERIFIED",
        "review_reason": "Verified on site by supervisor"
    }, headers=auth_headers(MANAGER_ID, "MANAGER"))
    assert r_ver.status_code == 200
    assert r_ver.json()["status"] == "VERIFIED"

    # 7. Employee trying to verify visit -> 403 Forbidden
    r_ver_emp = await client.post(f"/api/v1/visits/{visit_id}/verify", json={
        "status": "VERIFIED"
    }, headers=auth_headers(EMPLOYEE_ID, "EMPLOYEE"))
    assert r_ver_emp.status_code == 403

@pytest.mark.asyncio
async def test_targets_and_performance_endpoints(client: AsyncClient):
    # 1. Employee Dashboard Summary
    r_dash = await client.get("/api/v1/employee/dashboard-summary", headers=auth_headers(EMPLOYEE_ID, "EMPLOYEE"))
    assert r_dash.status_code == 200
    assert "target_visits" in r_dash.json()

    # 2. Performance Employee Summary
    r_summary = await client.get(f"/api/v1/performance/employee/{EMPLOYEE_ID}/summary", headers=auth_headers(EMPLOYEE_ID, "EMPLOYEE"))
    assert r_summary.status_code == 200

    # 3. Performance Employee Analytics
    r_ana = await client.get(f"/api/v1/performance/employee/{EMPLOYEE_ID}/analytics", headers=auth_headers(EMPLOYEE_ID, "EMPLOYEE"))
    assert r_ana.status_code == 200

    # 4. Performance Team Comparison (Manager)
    r_team = await client.get("/api/v1/performance/team-comparison", headers=auth_headers(MANAGER_ID, "MANAGER"))
    assert r_team.status_code == 200

    # 5. Performance Company Overview (Owner)
    r_comp = await client.get("/api/v1/performance/company-overview", headers=auth_headers(OWNER_ID, "OWNER"))
    assert r_comp.status_code == 200

    # 6. Quotas (Owner)
    r_quotas = await client.get("/api/v1/targets/quotas", headers=auth_headers(OWNER_ID, "OWNER"))
    assert r_quotas.status_code == 200

    # 7. Current Target for Employee
    r_curr_tar = await client.get(f"/api/v1/targets/employee/{EMPLOYEE_ID}/current", headers=auth_headers(MANAGER_ID, "MANAGER"))
    assert r_curr_tar.status_code == 200

@pytest.mark.asyncio
async def test_admin_and_users_management(client: AsyncClient):
    # 1. Admin Dashboard Stats (Owner)
    r_stats = await client.get("/api/v1/admin/dashboard-stats", headers=auth_headers(OWNER_ID, "OWNER"))
    assert r_stats.status_code == 200

    # 2. Audit Logs (Owner)
    r_audit = await client.get("/api/v1/admin/audit-logs", headers=auth_headers(OWNER_ID, "OWNER"))
    assert r_audit.status_code == 200

    # 3. Created Accounts Directory
    r_created = await client.get("/api/v1/users/created-accounts", headers=auth_headers(MANAGER_ID, "MANAGER"))
    assert r_created.status_code == 200

    # 4. Supervision List
    r_sup_list = await client.get("/api/v1/users/supervision/list", headers=auth_headers(OWNER_ID, "OWNER"))
    assert r_sup_list.status_code == 200

    # 5. Supervision Transfer (Owner)
    r_trans = await client.post("/api/v1/users/supervision/transfer", json={
        "employee_id": EMPLOYEE_ID,
        "new_manager_id": MANAGER_ID,
        "notes": "Testing transfer endpoint"
    }, headers=auth_headers(OWNER_ID, "OWNER"))
    assert r_trans.status_code == 200

    # 6. List Users (Owner)
    r_users = await client.get("/api/v1/users/", headers=auth_headers(OWNER_ID, "OWNER"))
    assert r_users.status_code == 200

    # 7. Get User by ID
    r_user = await client.get(f"/api/v1/users/{EMPLOYEE_ID}", headers=auth_headers(OWNER_ID, "OWNER"))
    assert r_user.status_code == 200

    # 8. Deactivate & Activate User
    r_deact = await client.post(f"/api/v1/users/{EMPLOYEE_ID}/deactivate", headers=auth_headers(OWNER_ID, "OWNER"))
    assert r_deact.status_code == 200
    r_act = await client.post(f"/api/v1/users/{EMPLOYEE_ID}/activate", headers=auth_headers(OWNER_ID, "OWNER"))
    assert r_act.status_code == 200

@pytest.mark.asyncio
async def test_customers_chat_system_and_media(client: AsyncClient):
    # 1. Customers List & Create
    r_cust_list = await client.get("/api/v1/customers/", headers=auth_headers(MANAGER_ID, "MANAGER"))
    assert r_cust_list.status_code == 200

    r_cust_create = await client.post("/api/v1/customers/", json={
        "name": "Chaudhry Farm Dealership",
        "customer_type": "DEALER",
        "phone": "03001234567",
        "address": "Khanewal Road, Multan",
        "territory": "Multan",
        "assigned_employee_id": EMPLOYEE_ID
    }, headers=auth_headers(MANAGER_ID, "MANAGER"))
    assert r_cust_create.status_code in (200, 201)

    # 2. Chat Contacts & Admins
    r_chat_cont = await client.get("/api/v1/chat/contacts", headers=auth_headers(EMPLOYEE_ID, "EMPLOYEE"))
    assert r_chat_cont.status_code == 200

    r_chat_admins = await client.get("/api/v1/chat/admins", headers=auth_headers(EMPLOYEE_ID, "EMPLOYEE"))
    assert r_chat_admins.status_code == 200

    # 3. Chat Rooms List & Create
    r_rooms = await client.get("/api/v1/chat/rooms", headers=auth_headers(EMPLOYEE_ID, "EMPLOYEE"))
    assert r_rooms.status_code == 200

    r_create_room = await client.post("/api/v1/chat/rooms", json={
        "target_user_id": MANAGER_ID
    }, headers=auth_headers(EMPLOYEE_ID, "EMPLOYEE"))
    assert r_create_room.status_code in (200, 201)
    room_id = r_create_room.json()["id"]

    # 4. Chat Send Message & Get Messages
    r_send_msg = await client.post(f"/api/v1/chat/rooms/{room_id}/messages", json={
        "content": "Hello supervisor, visit completed!"
    }, headers=auth_headers(EMPLOYEE_ID, "EMPLOYEE"))
    assert r_send_msg.status_code in (200, 201)

    r_get_msgs = await client.get(f"/api/v1/chat/rooms/{room_id}/messages", headers=auth_headers(EMPLOYEE_ID, "EMPLOYEE"))
    assert r_get_msgs.status_code == 200

    # 5. System Version (Get & Update)
    r_ver_get = await client.get("/api/v1/system/version")
    assert r_ver_get.status_code == 200

    from app.core.config import settings
    r_ver_upd = await client.post("/api/v1/system/version", json={
        "latest_version": "1.0.1",
        "latest_build_number": 2,
        "min_required_build_number": 1,
        "force_update": False,
        "release_notes": "Phase 2 Quality Improvement Release"
    }, headers={"X-Admin-Key": settings.SECRET_KEY})
    assert r_ver_upd.status_code == 200

    # 6. Media Usage & Cost
    r_media_cost = await client.get("/api/v1/media/usage-and-costs", headers=auth_headers(OWNER_ID, "OWNER"))
    assert r_media_cost.status_code == 200
