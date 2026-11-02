from datetime import datetime, timedelta, timezone
import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app

@pytest.mark.asyncio
async def test_visit_missing_mandatory_fields():
    """VALIDATION TEST: Missing client name, photo, or coordinates must return 422."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Login as employee
        login = await client.post("/api/v1/auth/login", json={"username_or_email": "emp.john", "password": "emp123"})
        token = login.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        now = datetime.now(timezone.utc)

        # 1. Missing client name
        res1 = await client.post(
            "/api/v1/visits/",
            headers=headers,
            json={
                "client_name": " ",  # Blank client name
                "latitude": 31.5204,
                "longitude": 74.3587,
                "gps_accuracy": 12.4,
                "device_capture_time": now.isoformat(),
                "photo_asset_id": "photo_101",
            }
        )
        assert res1.status_code == 422

        # 2. Missing photo_asset_id
        res2 = await client.post(
            "/api/v1/visits/",
            headers=headers,
            json={
                "client_name": "Valid Client",
                "latitude": 31.5204,
                "longitude": 74.3587,
                "gps_accuracy": 12.4,
                "device_capture_time": now.isoformat(),
                "photo_asset_id": "",
            }
        )
        assert res2.status_code == 422

        # 3. Missing coordinates
        res3 = await client.post(
            "/api/v1/visits/",
            headers=headers,
            json={
                "client_name": "Valid Client",
                "gps_accuracy": 12.4,
                "device_capture_time": now.isoformat(),
                "photo_asset_id": "photo_103",
            }
        )
        assert res3.status_code == 422

@pytest.mark.asyncio
async def test_visit_invalid_coordinates():
    """VALIDATION TEST: Latitude out of [-90, 90] or Longitude out of [-180, 180] rejected."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        login = await client.post("/api/v1/auth/login", json={"username_or_email": "emp.john", "password": "emp123"})
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
        now = datetime.now(timezone.utc)

        # Latitude 95.0 is invalid
        res1 = await client.post(
            "/api/v1/visits/",
            headers=headers,
            json={
                "client_name": "Test Client",
                "latitude": 95.0,
                "longitude": 74.3587,
                "gps_accuracy": 12.0,
                "device_capture_time": now.isoformat(),
                "photo_asset_id": "photo_invalid_lat",
            }
        )
        assert res1.status_code == 422

        # Latitude -95.0 is invalid
        res1_neg = await client.post(
            "/api/v1/visits/",
            headers=headers,
            json={
                "client_name": "Test Client",
                "latitude": -95.0,
                "longitude": 74.3587,
                "gps_accuracy": 12.0,
                "device_capture_time": now.isoformat(),
                "photo_asset_id": "photo_invalid_lat_neg",
            }
        )
        assert res1_neg.status_code == 422

        # Longitude 195.0 is invalid
        res2 = await client.post(
            "/api/v1/visits/",
            headers=headers,
            json={
                "client_name": "Test Client",
                "latitude": 31.5204,
                "longitude": 195.0,
                "gps_accuracy": 12.0,
                "device_capture_time": now.isoformat(),
                "photo_asset_id": "photo_invalid_lng",
            }
        )
        assert res2.status_code == 422

        # Longitude -195.0 is invalid
        res2_neg = await client.post(
            "/api/v1/visits/",
            headers=headers,
            json={
                "client_name": "Test Client",
                "latitude": 31.5204,
                "longitude": -195.0,
                "gps_accuracy": 12.0,
                "device_capture_time": now.isoformat(),
                "photo_asset_id": "photo_invalid_lng_neg",
            }
        )
        assert res2_neg.status_code == 422

@pytest.mark.asyncio
async def test_gps_accuracy_threshold_and_flags():
    """FRAUD-AWARE TEST: GPS accuracy exceeding 50m threshold flags visit for supervisor review."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        login = await client.post("/api/v1/auth/login", json={"username_or_email": "emp.john", "password": "emp123"})
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
        now = datetime.now(timezone.utc)

        # Accuracy = 78.5 meters (> 50m threshold)
        resp = await client.post(
            "/api/v1/visits/",
            headers=headers,
            json={
                "client_name": "Rural Farmhouse Shop",
                "latitude": 31.5204,
                "longitude": 74.3587,
                "gps_accuracy": 78.5,
                "device_capture_time": now.isoformat(),
                "photo_asset_id": "photo_low_accuracy_123",
            }
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["is_flagged_for_review"] is True
        assert "LOW_GPS_ACCURACY" in data["review_signals"]

@pytest.mark.asyncio
async def test_mock_location_and_clock_drift_detection():
    """FRAUD-AWARE TEST: Detects mock location signal and suspicious upload delay (> 24 hours)."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        login = await client.post("/api/v1/auth/login", json={"username_or_email": "emp.john", "password": "emp123"})
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
        stale_time = datetime.now(timezone.utc) - timedelta(hours=36)  # 36 hours ago

        resp = await client.post(
            "/api/v1/visits/",
            headers=headers,
            json={
                "client_name": "Test Mock Detection",
                "latitude": 31.5204,
                "longitude": 74.3587,
                "gps_accuracy": 15.0,
                "is_mock_location": True,  # Reported mock location
                "device_capture_time": stale_time.isoformat(),
                "photo_asset_id": "photo_mock_stale_123",
            }
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["is_flagged_for_review"] is True
        assert "REPORTED_MOCK_LOCATION" in data["review_signals"]
        assert "SUSPICIOUS_UPLOAD_DELAY" in data["review_signals"]

@pytest.mark.asyncio
async def test_evidence_immutability_duplicate_prevention():
    """EVIDENCE TEST: Cannot submit visit with duplicate photo_asset_id or silently replace evidence."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        login = await client.post("/api/v1/auth/login", json={"username_or_email": "emp.john", "password": "emp123"})
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
        now = datetime.now(timezone.utc)

        # 1. First submission succeeds
        resp1 = await client.post(
            "/api/v1/visits/",
            headers=headers,
            json={
                "client_name": "First Visit",
                "latitude": 31.5204,
                "longitude": 74.3587,
                "gps_accuracy": 12.0,
                "device_capture_time": now.isoformat(),
                "photo_asset_id": "unique_photo_asset_777",
            }
        )
        assert resp1.status_code == 201

        # 2. Resubmitting with the same photo_asset_id rejected with 409 Conflict
        resp2 = await client.post(
            "/api/v1/visits/",
            headers=headers,
            json={
                "client_name": "Attempted Duplicate",
                "latitude": 31.5204,
                "longitude": 74.3587,
                "gps_accuracy": 12.0,
                "device_capture_time": now.isoformat(),
                "photo_asset_id": "unique_photo_asset_777",
            }
        )
        assert resp2.status_code == 409
        assert "Duplicate photo evidence" in resp2.json()["detail"]

@pytest.mark.asyncio
async def test_evidence_policy_disclosure_endpoint():
    """POLICY TEST: Verifies evidence policy and background tracking disclaimer."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/api/v1/visits/evidence-policy")
        assert resp.status_code == 200
        policy = resp.json()
        assert policy["background_tracking_enabled"] is False
        assert policy["gps_accuracy_threshold_meters"] == 50.0
        assert "exclusively during visit submission" in policy["evidence_disclosure"]
        assert "signals" in policy["disclaimer"].lower()

@pytest.mark.asyncio
async def test_visit_creation_success_with_optional_fields():
    """VISIT CREATION TEST: Successfully records visit with all fields, verifies separate timestamps and status."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        login = await client.post("/api/v1/auth/login", json={"username_or_email": "emp.john", "password": "emp123"})
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
        capture_time = datetime.now(timezone.utc)

        resp = await client.post(
            "/api/v1/visits/",
            headers=headers,
            json={
                "client_name": "Al-Madina Agro Chemicals",
                "client_phone": "03001234567",
                "notes": "[DEALER - PRODUCT_PITCH] Booked 20 cartons of Trichoderma bio-fungicide",
                "latitude": 31.5204,
                "longitude": 74.3587,
                "gps_accuracy": 14.5,
                "is_mock_location": False,
                "device_capture_time": capture_time.isoformat(),
                "photo_asset_id": "photo_full_success_999",
                "photo_url": "https://res.cloudinary.com/phytodoctor/image/upload/v1/visits/sample.jpg",
            }
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["id"] is not None
        assert data["client_name"] == "Al-Madina Agro Chemicals"
        assert data["client_phone"] == "03001234567"
        assert "Trichoderma" in data["notes"]
        assert data["latitude"] == 31.5204
        assert data["longitude"] == 74.3587
        assert data["gps_accuracy"] == 14.5
        assert data["photo_asset_id"] == "photo_full_success_999"
        assert data["status"] == "PENDING"
        assert data["is_flagged_for_review"] is False
        assert data["device_capture_time"] is not None
        assert data["server_receipt_time"] is not None
        # Verify device timestamp and server receipt timestamp are both stored
        assert data["device_capture_time"] != data["server_receipt_time"] or abs(data["clock_drift_seconds"]) < 5

@pytest.mark.asyncio
async def test_visit_unauthorized_permission_failure():
    """PERMISSION FAILURE TEST: Unauthenticated requests and unauthorized role actions are rejected."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Unauthenticated request to submit visit returns 401
        resp_unauth = await client.post(
            "/api/v1/visits/",
            json={
                "client_name": "Anonymous Visit",
                "latitude": 31.5204,
                "longitude": 74.3587,
                "gps_accuracy": 12.0,
                "device_capture_time": datetime.now(timezone.utc).isoformat(),
                "photo_asset_id": "photo_unauth_123",
            }
        )
        assert resp_unauth.status_code == 401

        # 2. Employee cannot verify or approve visits (requires Admin/Manager)
        login = await client.post("/api/v1/auth/login", json={"username_or_email": "emp.john", "password": "emp123"})
        emp_headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

        resp_forbidden = await client.post(
            "/api/v1/visits/fake-visit-uuid/verify",
            headers=emp_headers,
            json={"status": "VERIFIED", "review_reason": "Attempted self-approval"}
        )
        assert resp_forbidden.status_code == 403

