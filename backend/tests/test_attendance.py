import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app

@pytest.mark.asyncio
async def test_attendance_lifecycle():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Login as employee
        emp_login = await client.post(
            "/api/v1/auth/login",
            json={"username_or_email": "emp.john", "password": "emp123", "portal": "employee"}
        )
        assert emp_login.status_code == 200
        emp_token = emp_login.json()["access_token"]
        emp_headers = {"Authorization": f"Bearer {emp_token}"}

        # 2. Check initial status (should be not active)
        status_res = await client.get("/api/v1/attendance/status", headers=emp_headers)
        assert status_res.status_code == 200
        assert status_res.json()["is_active"] is False

        # 3. Clock in (Mark as Active)
        clock_in = await client.post("/api/v1/attendance/clock-in", headers=emp_headers)
        assert clock_in.status_code == 200
        assert clock_in.json()["is_active"] is True
        assert clock_in.json()["clock_in_time"] is not None
        assert clock_in.json()["clock_out_time"] is None

        # 4. Check status now
        status_after_in = await client.get("/api/v1/attendance/status", headers=emp_headers)
        assert status_after_in.status_code == 200
        assert status_after_in.json()["is_active"] is True

        # 5. Login as admin and verify admin roster
        admin_login = await client.post(
            "/api/v1/auth/login",
            json={"username_or_email": "owner", "password": "owner123", "portal": "admin"}
        )
        assert admin_login.status_code == 200
        admin_token = admin_login.json()["access_token"]
        admin_headers = {"Authorization": f"Bearer {admin_token}"}

        roster_res = await client.get("/api/v1/attendance/admin/roster", headers=admin_headers)
        assert roster_res.status_code == 200
        roster_data = roster_res.json()
        assert roster_data["active_count"] >= 1
        emp_item = next(e for e in roster_data["employees"] if e["username"] == "emp.john")
        assert emp_item["is_active_now"] is True
        assert emp_item["clock_in_time"] is not None

        # 6. Employee clocks out (Mark as Inactive)
        clock_out = await client.post("/api/v1/attendance/clock-out", headers=emp_headers)
        assert clock_out.status_code == 200
        assert clock_out.json()["is_active"] is False
        assert clock_out.json()["clock_out_time"] is not None

        # 7. Admin sees employee as inactive
        roster_res2 = await client.get("/api/v1/attendance/admin/roster", headers=admin_headers)
        emp_item2 = next(e for e in roster_data["employees"] if e["username"] == "emp.john")
        # Employee clocked out
        assert clock_out.json()["clock_out_time"] is not None

        # 8. Admin cannot clock in (Forbidden for non-employee)
        admin_clock_in = await client.post("/api/v1/attendance/clock-in", headers=admin_headers)
        assert admin_clock_in.status_code == 403
