from datetime import date, datetime, timedelta, timezone
import uuid
import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app
from app.models.visit import VisitStatus

@pytest.mark.asyncio
async def test_owner_set_single_and_batch_targets():
    """TARGET TEST: Owner sets single and batch targets with effective date ranges."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Login as owner
        login = await client.post("/api/v1/auth/login", json={"username_or_email": "owner", "password": "owner123"})
        token = login.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 1. Get employee ID
        emp_res = await client.get("/api/v1/users/", headers=headers, params={"role": "EMPLOYEE"})
        employees = emp_res.json()["items"]
        assert len(employees) >= 1
        emp1_id = employees[0]["id"]

        today = date.today()
        end_of_month = today + timedelta(days=30)

        # 2. Set single target
        target_payload = {
            "employee_id": emp1_id,
            "target_count": 8,
            "period_type": "DAILY",
            "start_date": today.isoformat(),
            "end_date": end_of_month.isoformat(),
        }
        res1 = await client.post("/api/v1/targets/", headers=headers, json=target_payload)
        assert res1.status_code == 201
        data1 = res1.json()
        assert data1["target_count"] == 8
        assert data1["employee_id"] == emp1_id

        # 3. Batch target assignment for multiple employees
        emp_ids = [e["id"] for e in employees[:3]]
        batch_payload = {
            "employee_ids": emp_ids,
            "target_count": 10,
            "period_type": "DAILY",
            "start_date": today.isoformat(),
            "end_date": end_of_month.isoformat(),
        }
        res_batch = await client.post("/api/v1/targets/batch", headers=headers, json=batch_payload)
        assert res_batch.status_code == 201
        batch_data = res_batch.json()
        assert len(batch_data) == len(emp_ids)
        for t in batch_data:
            assert t["target_count"] == 10

@pytest.mark.asyncio
async def test_manager_authorized_team_scoping():
    """ROLE SCOPING TEST: Manager can only set and view targets for assigned team members."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Login as manager
        mgr_login = await client.post("/api/v1/auth/login", json={"username_or_email": "manager.punjab", "password": "manager123"})
        mgr_token = mgr_login.json()["access_token"]
        mgr_headers = {"Authorization": f"Bearer {mgr_token}"}

        # Login as owner to check employees
        owner_login = await client.post("/api/v1/auth/login", json={"username_or_email": "owner", "password": "owner123"})
        owner_headers = {"Authorization": f"Bearer {owner_login.json()['access_token']}"}
        
        all_emps = (await client.get("/api/v1/users/", headers=owner_headers, params={"role": "EMPLOYEE"})).json()["items"]
        
        # Identify an employee not supervised by manager.punjab
        mgr_user = (await client.get("/api/v1/auth/me", headers=mgr_headers)).json()
        mgr_id = mgr_user["id"]
        
        unsupervised_emp = next((e for e in all_emps if e.get("manager_id") != mgr_id), None)
        supervised_emp = next((e for e in all_emps if e.get("manager_id") == mgr_id), None)

        today = date.today()

        # If there is a supervised employee, manager setting target succeeds
        if supervised_emp:
            res_allowed = await client.post(
                "/api/v1/targets/",
                headers=mgr_headers,
                json={
                    "employee_id": supervised_emp["id"],
                    "target_count": 7,
                    "period_type": "DAILY",
                    "start_date": today.isoformat(),
                    "end_date": (today + timedelta(days=7)).isoformat(),
                }
            )
            assert res_allowed.status_code == 201

        # If there is an unsupervised employee, manager setting target is strictly 403 FORBIDDEN
        if unsupervised_emp:
            res_forbidden = await client.post(
                "/api/v1/targets/",
                headers=mgr_headers,
                json={
                    "employee_id": unsupervised_emp["id"],
                    "target_count": 7,
                    "period_type": "DAILY",
                    "start_date": today.isoformat(),
                    "end_date": (today + timedelta(days=7)).isoformat(),
                }
            )
            assert res_forbidden.status_code == 403

@pytest.mark.asyncio
async def test_historical_target_preservation_across_dates():
    """HISTORICAL PRESERVATION TEST: Target query for past dates returns historical target, not current."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        owner_login = await client.post("/api/v1/auth/login", json={"username_or_email": "owner", "password": "owner123"})
        headers = {"Authorization": f"Bearer {owner_login.json()['access_token']}"}

        emp_res = await client.get("/api/v1/users/", headers=headers, params={"role": "EMPLOYEE"})
        emp_id = emp_res.json()["items"][0]["id"]

        past_start = date.today() - timedelta(days=60)
        past_end = date.today() - timedelta(days=30)

        # Set target of 4 visits for past period
        await client.post(
            "/api/v1/targets/",
            headers=headers,
            json={
                "employee_id": emp_id,
                "target_count": 4,
                "period_type": "DAILY",
                "start_date": past_start.isoformat(),
                "end_date": past_end.isoformat(),
            }
        )

        # Set target of 9 visits for current period
        curr_start = date.today()
        curr_end = date.today() + timedelta(days=30)
        await client.post(
            "/api/v1/targets/",
            headers=headers,
            json={
                "employee_id": emp_id,
                "target_count": 9,
                "period_type": "DAILY",
                "start_date": curr_start.isoformat(),
                "end_date": curr_end.isoformat(),
            }
        )

        # Query past date: Must preserve past target (4)
        past_check_date = past_start + timedelta(days=10)
        past_res = await client.get(
            f"/api/v1/targets/employee/{emp_id}/current",
            headers=headers,
            params={"as_of_date": past_check_date.isoformat()}
        )
        assert past_res.status_code == 200
        assert past_res.json()["target_count"] == 4

        # Query current date: Returns current target (9)
        curr_res = await client.get(
            f"/api/v1/targets/employee/{emp_id}/current",
            headers=headers,
            params={"as_of_date": curr_start.isoformat()}
        )
        assert curr_res.status_code == 200
        assert curr_res.json()["target_count"] == 9

@pytest.mark.asyncio
async def test_only_verified_visits_count_toward_performance():
    """BUSINESS RULE TEST: Only VERIFIED visits count toward quota. Drafts, pending, and rejected do NOT inflate counts."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Login as employee
        emp_login = await client.post("/api/v1/auth/login", json={"username_or_email": "emp.john", "password": "emp123"})
        emp_token = emp_login.json()["access_token"]
        emp_headers = {"Authorization": f"Bearer {emp_token}"}
        emp_id = (await client.get("/api/v1/auth/me", headers=emp_headers)).json()["id"]

        # Login as owner to verify or reject visits
        owner_login = await client.post("/api/v1/auth/login", json={"username_or_email": "owner", "password": "owner123"})
        owner_headers = {"Authorization": f"Bearer {owner_login.json()['access_token']}"}

        now = datetime.now(timezone.utc)

        # 1. Submit visit A (will be VERIFIED)
        res_a = await client.post(
            "/api/v1/visits/",
            headers=emp_headers,
            json={
                "id": str(uuid.uuid4()),
                "client_name": "Verified Farm Visit",
                "latitude": 31.5204,
                "longitude": 74.3587,
                "gps_accuracy": 12.0,
                "device_capture_time": now.isoformat(),
                "photo_asset_id": f"photo_{uuid.uuid4().hex[:10]}",
            }
        )
        visit_a_id = res_a.json()["id"]
        # Owner approves visit A
        await client.post(f"/api/v1/visits/{visit_a_id}/verify", headers=owner_headers, json={"status": "VERIFIED"})

        # 2. Submit visit B (remains PENDING)
        await client.post(
            "/api/v1/visits/",
            headers=emp_headers,
            json={
                "id": str(uuid.uuid4()),
                "client_name": "Pending Farm Visit",
                "latitude": 31.5204,
                "longitude": 74.3587,
                "gps_accuracy": 14.0,
                "device_capture_time": now.isoformat(),
                "photo_asset_id": f"photo_{uuid.uuid4().hex[:10]}",
            }
        )

        # 3. Submit visit C (will be REJECTED)
        res_c = await client.post(
            "/api/v1/visits/",
            headers=emp_headers,
            json={
                "id": str(uuid.uuid4()),
                "client_name": "Rejected Farm Visit",
                "latitude": 31.5204,
                "longitude": 74.3587,
                "gps_accuracy": 15.0,
                "device_capture_time": now.isoformat(),
                "photo_asset_id": f"photo_{uuid.uuid4().hex[:10]}",
            }
        )
        visit_c_id = res_c.json()["id"]
        # Owner rejects visit C
        await client.post(
            f"/api/v1/visits/{visit_c_id}/verify",
            headers=owner_headers,
            json={"status": "REJECTED", "review_reason": "Crop boundary not in frame"}
        )

        # 4. Fetch performance analytics for today
        analytics = await client.get(
            f"/api/v1/performance/employee/{emp_id}/analytics",
            headers=emp_headers,
            params={"timeframe": "DAILY"}
        )
        assert analytics.status_code == 200
        data = analytics.json()

        # Check business rule assertion:
        # Total submitted >= 3 (visits A, B, C)
        assert data["submitted_visits"] >= 3
        # Verified visits count MUST NOT include B (pending) or C (rejected)!
        assert data["rejected_visits"] >= 1
        assert data["pending_sync_count"] >= 1
        # Completion percentage is calculated strictly from verified visits
        expected_pct = round((data["verified_visits"] / data["target_visits"] * 100.0), 1)
        assert data["completion_percentage"] == expected_pct

        # Verify audit review history includes the rejection reason
        review_item = next((r for r in data["recent_reviews"] if r["visit_id"] == visit_c_id), None)
        assert review_item is not None
        assert review_item["status"] == "REJECTED"
        assert "Crop boundary not in frame" in review_item["review_reason"]

@pytest.mark.asyncio
async def test_team_comparison_analytics_for_authorized_users():
    """TEAM ANALYTICS TEST: Team comparison returns ranking and verified metrics for manager's team."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Login as manager
        mgr_login = await client.post("/api/v1/auth/login", json={"username_or_email": "manager.punjab", "password": "manager123"})
        mgr_token = mgr_login.json()["access_token"]
        mgr_headers = {"Authorization": f"Bearer {mgr_token}"}

        resp = await client.get("/api/v1/performance/team-comparison", headers=mgr_headers, params={"timeframe": "DAILY"})
        assert resp.status_code == 200
        data = resp.json()

        assert "team_size" in data
        assert "team_total_target" in data
        assert "team_total_verified" in data
        assert "team_average_completion_pct" in data
        assert isinstance(data["members"], list)

        # Employee cannot access team comparison (403 forbidden)
        emp_login = await client.post("/api/v1/auth/login", json={"username_or_email": "emp.john", "password": "emp123"})
        emp_headers = {"Authorization": f"Bearer {emp_login.json()['access_token']}"}
        res_emp = await client.get("/api/v1/performance/team-comparison", headers=emp_headers)
        assert res_emp.status_code == 403

@pytest.mark.asyncio
async def test_duplicate_visits_do_not_inflate_performance_metrics():
    """IDEMPOTENCY & BOUNDARY TEST: Duplicate visit submissions do not inflate verified counts or completed counts."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Login as employee
        emp_login = await client.post("/api/v1/auth/login", json={"username_or_email": "emp.john", "password": "emp123"})
        emp_headers = {"Authorization": f"Bearer {emp_login.json()['access_token']}"}
        emp_id = (await client.get("/api/v1/auth/me", headers=emp_headers)).json()["id"]

        # 2. Login as owner
        owner_login = await client.post("/api/v1/auth/login", json={"username_or_email": "owner", "password": "owner123"})
        owner_headers = {"Authorization": f"Bearer {owner_login.json()['access_token']}"}

        # Baseline summary
        base_summary = (await client.get(f"/api/v1/performance/employee/{emp_id}/summary", headers=emp_headers)).json()
        base_verified = base_summary["verified_visits"]
        base_completed = base_summary["completed_today"]

        # 3. Create a unique visit
        visit_uuid = str(uuid.uuid4())
        photo_asset_id = f"photo_{uuid.uuid4().hex[:12]}"
        now = datetime.now(timezone.utc)

        visit_data = {
            "id": visit_uuid,
            "client_name": "Unique Audit Customer",
            "latitude": 31.5204,
            "longitude": 74.3587,
            "gps_accuracy": 12.0,
            "device_capture_time": now.isoformat(),
            "photo_asset_id": photo_asset_id,
        }

        # Initial submission
        res1 = await client.post("/api/v1/visits/", headers=emp_headers, json=visit_data)
        assert res1.status_code == 201

        # Verify the visit
        verify_res = await client.post(f"/api/v1/visits/{visit_uuid}/verify", headers=owner_headers, json={"status": "VERIFIED"})
        assert verify_res.status_code == 200

        # Summary after 1 verified visit
        summary_after_one = (await client.get(f"/api/v1/performance/employee/{emp_id}/summary", headers=emp_headers)).json()
        assert summary_after_one["verified_visits"] == base_verified + 1
        assert summary_after_one["completed_today"] == base_completed + 1

        # 4. Duplicate resubmission of the exact same visit (simulating network retry or manual sync)
        res_dup = await client.post("/api/v1/visits/", headers=emp_headers, json=visit_data)
        assert res_dup.status_code in (200, 201)

        # Summary after duplicate submission: MUST NOT INCREMENT!
        summary_after_dup = (await client.get(f"/api/v1/performance/employee/{emp_id}/summary", headers=emp_headers)).json()
        assert summary_after_dup["verified_visits"] == base_verified + 1
        assert summary_after_dup["completed_today"] == base_completed + 1

