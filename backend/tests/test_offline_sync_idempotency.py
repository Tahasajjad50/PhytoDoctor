from datetime import datetime, timezone
import uuid
import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app

@pytest.mark.asyncio
async def test_uuid_idempotency_duplicate_requests():
    """IDEMPOTENCY TEST: Submitting the same visit with client-generated UUID returns the existing record idempotently."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Login as employee
        login = await client.post("/api/v1/auth/login", json={"username_or_email": "emp.john", "password": "emp123"})
        token = login.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        client_visit_uuid = str(uuid.uuid4())
        photo_asset_id = f"photo_{uuid.uuid4().hex[:12]}"
        now = datetime.now(timezone.utc)

        visit_data = {
            "id": client_visit_uuid,
            "client_name": "Kisan Fertilizer & Agro Services",
            "client_phone": "03009876543",
            "notes": "[DEALER - PRODUCT_PITCH] Idempotent visit test",
            "latitude": 31.5204,
            "longitude": 74.3587,
            "gps_accuracy": 15.0,
            "is_mock_location": False,
            "device_capture_time": now.isoformat(),
            "photo_asset_id": photo_asset_id,
            "photo_url": f"https://res.cloudinary.com/phytodoctor/image/upload/v1/visits/{photo_asset_id}.jpg",
        }

        # 2. First submission (simulating initial online sync)
        resp1 = await client.post("/api/v1/visits/", headers=headers, json=visit_data)
        assert resp1.status_code == 201
        data1 = resp1.json()
        assert data1["id"] == client_visit_uuid
        assert data1["client_name"] == "Kisan Fertilizer & Agro Services"
        assert data1["photo_asset_id"] == photo_asset_id

        # 3. Second submission with identical UUID (simulating repeated Sync Now, network drop recovery, or retry)
        resp2 = await client.post("/api/v1/visits/", headers=headers, json=visit_data)
        assert resp2.status_code in (200, 201)
        data2 = resp2.json()
        # Must return the SAME visit record without error or duplicate creation
        assert data2["id"] == client_visit_uuid
        assert data2["photo_asset_id"] == photo_asset_id
        assert data2["created_at"] == data1["created_at"]

@pytest.mark.asyncio
async def test_expired_authentication_rejection():
    """AUTH REJECTION TEST: Expired or invalid token is rejected with 401 without affecting server state."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Invalid / expired token
        headers = {"Authorization": "Bearer expired_or_tampered_jwt_token"}
        visit_data = {
            "id": str(uuid.uuid4()),
            "client_name": "Test Client",
            "latitude": 31.5204,
            "longitude": 74.3587,
            "gps_accuracy": 12.0,
            "device_capture_time": datetime.now(timezone.utc).isoformat(),
            "photo_asset_id": f"photo_{uuid.uuid4().hex[:12]}",
        }
        resp = await client.post("/api/v1/visits/", headers=headers, json=visit_data)
        assert resp.status_code == 401

@pytest.mark.asyncio
async def test_uuid_collision_from_different_user_rejected():
    """SECURITY TEST: Attempting to use another employee's visit UUID is rejected with 409 Conflict."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Employee 1 submits visit with UUID
        login1 = await client.post("/api/v1/auth/login", json={"username_or_email": "emp.john", "password": "emp123"})
        token1 = login1.json()["access_token"]
        
        shared_uuid = str(uuid.uuid4())
        photo_asset_id1 = f"photo_{uuid.uuid4().hex[:12]}"
        now = datetime.now(timezone.utc)

        resp1 = await client.post(
            "/api/v1/visits/",
            headers={"Authorization": f"Bearer {token1}"},
            json={
                "id": shared_uuid,
                "client_name": "Client of Emp 1",
                "latitude": 31.5204,
                "longitude": 74.3587,
                "gps_accuracy": 14.0,
                "device_capture_time": now.isoformat(),
                "photo_asset_id": photo_asset_id1,
            }
        )
        assert resp1.status_code == 201

        # 2. Manager tries to submit with same UUID
        login2 = await client.post("/api/v1/auth/login", json={"username_or_email": "manager.punjab", "password": "manager123"})
        token2 = login2.json()["access_token"]
        photo_asset_id2 = f"photo_{uuid.uuid4().hex[:12]}"

        resp2 = await client.post(
            "/api/v1/visits/",
            headers={"Authorization": f"Bearer {token2}"},
            json={
                "id": shared_uuid,
                "client_name": "Client of Manager",
                "latitude": 31.5204,
                "longitude": 74.3587,
                "gps_accuracy": 14.0,
                "device_capture_time": now.isoformat(),
                "photo_asset_id": photo_asset_id2,
            }
        )
        assert resp2.status_code == 409
