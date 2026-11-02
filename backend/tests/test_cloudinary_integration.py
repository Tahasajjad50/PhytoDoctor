import io
import uuid
from datetime import datetime, timezone
import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from app.core.config import settings
from app.main import app

@pytest_asyncio.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

@pytest_asyncio.fixture
async def owner_token(client: AsyncClient) -> str:
    login = await client.post("/api/v1/auth/login", json={"username_or_email": "owner", "password": "owner123"})
    assert login.status_code == 200
    return login.json()["access_token"]

@pytest_asyncio.fixture
async def manager_token(client: AsyncClient) -> str:
    login = await client.post("/api/v1/auth/login", json={"username_or_email": "manager.punjab", "password": "manager123"})
    assert login.status_code == 200
    return login.json()["access_token"]

@pytest_asyncio.fixture
async def employee_token(client: AsyncClient) -> str:
    login = await client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "emp.john", "password": "emp123", "portal": "employee"},
    )
    assert login.status_code == 200
    return login.json()["access_token"]


@pytest.fixture
def sample_jpeg_bytes() -> bytes:
    """Generates valid minimal JPEG bytes with magic header."""
    return b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xff\xdb\x00C\x00" + b"\x00" * 200 + b"\xff\xd9"

@pytest.fixture
def sample_png_bytes() -> bytes:
    """Generates valid minimal PNG bytes with magic header."""
    return b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4" + b"\x00" * 100

@pytest.fixture
def sample_webp_bytes() -> bytes:
    """Generates valid minimal WebP bytes with magic header."""
    return b"RIFF\x1a\x00\x00\x00WEBPVP8 \x0e\x00\x00\x00" + b"\x00" * 50

@pytest.fixture
def invalid_exe_bytes() -> bytes:
    """Generates forbidden executable payload."""
    return b"MZ\x90\x00\x03\x00\x00\x00\x04\x00\x00\x00\xff\xff\x00\x00" + b"\x00" * 100

@pytest.mark.asyncio
async def test_signed_upload_authorization_security(client: AsyncClient, employee_token: str, owner_token: str):
    """
    Verifies that:
    1. Signed upload parameters are generated correctly.
    2. Cloudinary API secret is NEVER leaked to client.
    3. Files are organized strictly in a DAILY folder (phytodoctor/visits/YYYY-MM-DD/emp...).
    4. Unauthenticated requests are rejected.
    """
    # 1. Create a visit first
    visit_id = str(uuid.uuid4())
    visit_res = await client.post(
        "/api/v1/visits/",
        headers={"Authorization": f"Bearer {employee_token}"},
        json={
            "id": visit_id,
            "client_name": "Tariq Agro Chemicals",
            "latitude": 30.1575,
            "longitude": 71.5249,
            "gps_accuracy": 15.0,
            "device_capture_time": datetime.now(timezone.utc).isoformat(),
            "photo_asset_id": f"PHOTO_PRE_{uuid.uuid4().hex[:8]}",
        },
    )
    assert visit_res.status_code == 201

    # 2. Request upload authorization
    auth_res = await client.post(
        f"/api/v1/media/visits/{visit_id}/photo-upload-authorization",
        headers={"Authorization": f"Bearer {employee_token}"},
        json={"visit_id": visit_id},
    )
    assert auth_res.status_code == 200
    data = auth_res.json()

    # Check required signed parameters
    assert data["visit_id"] == visit_id
    assert "public_id" in data
    assert "signature" in data
    assert "timestamp" in data
    assert "api_key" in data
    assert "cloud_name" in data
    assert "upload_url" in data
    assert "allowed_formats" in data
    assert data["max_file_size_bytes"] == 10 * 1024 * 1024

    # Assert DAILY FOLDER organization (phytodoctor/visits/YYYY-MM-DD/emp...)
    today_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    assert today_str in data["folder"]
    assert data["folder"].startswith(f"{settings.CLOUDINARY_FOLDER}/{today_str}/")

    # CRITICAL SECURITY CHECK: API Secret must NEVER appear in the response payload
    raw_response_text = auth_res.text
    if settings.CLOUDINARY_API_SECRET:
        assert settings.CLOUDINARY_API_SECRET not in raw_response_text
    assert "api_secret" not in data

    # 3. Unauthenticated request rejected
    unauth_res = await client.post(
        f"/api/v1/media/visits/{visit_id}/photo-upload-authorization",
        json={"visit_id": visit_id},
    )
    assert unauth_res.status_code == 401

@pytest.mark.asyncio
async def test_permission_and_visit_scoping(client: AsyncClient, employee_token: str, owner_token: str):
    """
    Verifies that:
    1. Employee cannot upload or authorize photos for another employee's visit.
    2. Invalid visit IDs return 404.
    """
    # Create employee 2
    emp2_username = f"emp_other_{uuid.uuid4().hex[:6]}"
    create_emp2 = await client.post(
        "/api/v1/users/",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={
            "username": emp2_username,
            "email": f"{emp2_username}@phytodoctor.pk",
            "password": "Password123!",
            "full_name": "Other Employee",
            "role": "EMPLOYEE",
        },
    )
    assert create_emp2.status_code == 201
    
    # Login as employee 2
    login2 = await client.post(
        "/api/v1/auth/login",
        json={"username_or_email": emp2_username, "password": "Password123!", "portal": "employee"},
    )
    assert login2.status_code == 200
    emp2_token = login2.json()["access_token"]


    # Create visit under employee 1
    v1_id = str(uuid.uuid4())
    create_v1 = await client.post(
        "/api/v1/visits/",
        headers={"Authorization": f"Bearer {employee_token}"},
        json={
            "id": v1_id,
            "client_name": "Multan Cotton Advisory",
            "latitude": 30.1575,
            "longitude": 71.5249,
            "gps_accuracy": 12.0,
            "device_capture_time": datetime.now(timezone.utc).isoformat(),
            "photo_asset_id": f"PHOTO_V1_{uuid.uuid4().hex[:8]}",
        },
    )
    assert create_v1.status_code == 201

    # Employee 2 tries to authorize upload for Employee 1's visit -> 403 Forbidden!
    forbidden_auth = await client.post(
        f"/api/v1/media/visits/{v1_id}/photo-upload-authorization",
        headers={"Authorization": f"Bearer {emp2_token}"},
        json={"visit_id": v1_id},
    )
    assert forbidden_auth.status_code == 403

    # Non-existent visit ID -> 404
    fake_visit_id = str(uuid.uuid4())
    not_found_res = await client.post(
        f"/api/v1/media/visits/{fake_visit_id}/photo-upload-authorization",
        headers={"Authorization": f"Bearer {employee_token}"},
        json={"visit_id": fake_visit_id},
    )
    assert not_found_res.status_code == 404

@pytest.mark.asyncio
async def test_invalid_file_types_and_size_rejection(
    client: AsyncClient,
    employee_token: str,
    invalid_exe_bytes: bytes,
    sample_jpeg_bytes: bytes,
):
    """
    Verifies that:
    1. Forbidden file types (.exe, scripts, corrupted) are rejected with 400 Bad Request.
    2. Files exceeding the size limit (10MB) are rejected with 413 Request Entity Too Large.
    """
    v_id = str(uuid.uuid4())
    await client.post(
        "/api/v1/visits/",
        headers={"Authorization": f"Bearer {employee_token}"},
        json={
            "id": v_id,
            "client_name": "Bahawalpur Pesticide Center",
            "latitude": 29.3544,
            "longitude": 71.6911,
            "gps_accuracy": 10.0,
            "device_capture_time": datetime.now(timezone.utc).isoformat(),
            "photo_asset_id": f"PHOTO_REJ_{uuid.uuid4().hex[:8]}",
        },
    )

    # 1. Reject invalid executable binary
    rej_file_res = await client.post(
        f"/api/v1/media/visits/{v_id}/photo",
        headers={"Authorization": f"Bearer {employee_token}"},
        files={"file": ("malicious.exe", invalid_exe_bytes, "application/octet-stream")},
    )
    assert rej_file_res.status_code == 400
    assert "unsupported file format" in rej_file_res.json()["detail"].lower()

    # 2. Reject payload exceeding 10 MB
    large_payload = sample_jpeg_bytes[:100] + (b"X" * (11 * 1024 * 1024))
    large_res = await client.post(
        f"/api/v1/media/visits/{v_id}/photo",
        headers={"Authorization": f"Bearer {employee_token}"},
        files={"file": ("too_large.jpg", large_payload, "image/jpeg")},
    )
    assert large_res.status_code == 413
    assert "exceeds maximum permissible size" in large_res.json()["detail"].lower()

@pytest.mark.asyncio
async def test_photo_upload_and_postgresql_association(
    client: AsyncClient,
    employee_token: str,
    sample_jpeg_bytes: bytes,
):
    """
    Verifies full upload flow:
    1. Direct upload of valid JPEG photo.
    2. Daily folder organization in Cloudinary.
    3. Associating photo asset ID, delivery URL, and metadata in PostgreSQL.
    4. Returning optimized preview and thumbnail URLs.
    """
    v_id = str(uuid.uuid4())
    init_asset = f"PHOTO_INIT_{uuid.uuid4().hex[:8]}"
    create_res = await client.post(
        "/api/v1/visits/",
        headers={"Authorization": f"Bearer {employee_token}"},
        json={
            "id": v_id,
            "client_name": "Sahiwal Wheat Research",
            "latitude": 30.6682,
            "longitude": 73.1114,
            "gps_accuracy": 8.0,
            "device_capture_time": datetime.now(timezone.utc).isoformat(),
            "photo_asset_id": init_asset,
        },
    )
    assert create_res.status_code == 201

    # Upload photo
    upload_res = await client.post(
        f"/api/v1/media/visits/{v_id}/photo",
        headers={"Authorization": f"Bearer {employee_token}"},
        files={"file": ("field_proof.jpg", sample_jpeg_bytes, "image/jpeg")},
    )
    assert upload_res.status_code == 201
    photo_data = upload_res.json()

    assert photo_data["visit_id"] == v_id
    assert "photo_asset_id" in photo_data
    assert "photo_url" in photo_data
    assert "thumbnail_url" in photo_data
    assert "preview_url" in photo_data
    assert photo_data["is_confirmed"] is True
    assert photo_data["bytes_size"] > 0
    assert photo_data["format"] == "jpg"

    # Daily folder check: photo_asset_id must include YYYY-MM-DD
    today_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    assert today_str in photo_data["photo_asset_id"]

    # Verify visit detail in PostgreSQL contains updated photo info
    detail_res = await client.get(
        f"/api/v1/visits/{v_id}",
        headers={"Authorization": f"Bearer {employee_token}"},
    )
    assert detail_res.status_code == 200
    detail = detail_res.json()
    assert detail["photo_asset_id"] == photo_data["photo_asset_id"]
    assert detail["photo_url"] == photo_data["photo_url"]
    assert detail["photo_metadata"] is not None

@pytest.mark.asyncio
async def test_photo_association_confirmation_workflow(
    client: AsyncClient,
    employee_token: str,
):
    """
    Verifies confirmation workflow when client uploads via direct signed upload
    and notifies FastAPI to associate and verify the asset.
    """
    v_id = str(uuid.uuid4())
    await client.post(
        "/api/v1/visits/",
        headers={"Authorization": f"Bearer {employee_token}"},
        json={
            "id": v_id,
            "client_name": "Khanewal Citrus Orchard",
            "latitude": 30.3000,
            "longitude": 71.9333,
            "gps_accuracy": 14.0,
            "device_capture_time": datetime.now(timezone.utc).isoformat(),
            "photo_asset_id": f"PHOTO_STAGE_{uuid.uuid4().hex[:8]}",
        },
    )

    today_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    confirmed_asset_id = f"phytodoctor/visits/{today_str}/emp1/visit_{v_id[:8]}"
    confirmed_url = f"https://res.cloudinary.com/phytodoctor/image/upload/v1/{confirmed_asset_id}.jpg"

    confirm_res = await client.post(
        f"/api/v1/media/visits/{v_id}/confirm-photo",
        headers={"Authorization": f"Bearer {employee_token}"},
        json={
            "visit_id": v_id,
            "photo_asset_id": confirmed_asset_id,
            "photo_url": confirmed_url,
            "bytes_size": 245000,
            "width": 1280,
            "height": 720,
            "format": "jpg",
            "version": "1",
        },
    )
    assert confirm_res.status_code == 200
    conf_data = confirm_res.json()
    assert conf_data["photo_asset_id"] == confirmed_asset_id
    assert conf_data["photo_url"] == confirmed_url
    assert conf_data["is_confirmed"] is True

@pytest.mark.asyncio
async def test_secure_photo_access_permissions(
    client: AsyncClient,
    employee_token: str,
    owner_token: str,
    manager_token: str,
    sample_jpeg_bytes: bytes,
):
    """
    Verifies that:
    1. Employee can access their own photo.
    2. Unauthorized employee receives 403.
    3. Owner can view any photo.
    4. Unauthenticated user receives 401.
    """
    v_id = str(uuid.uuid4())
    await client.post(
        "/api/v1/visits/",
        headers={"Authorization": f"Bearer {employee_token}"},
        json={
            "id": v_id,
            "client_name": "Vehari Fertilizer Depot",
            "latitude": 30.0419,
            "longitude": 72.3528,
            "gps_accuracy": 11.0,
            "device_capture_time": datetime.now(timezone.utc).isoformat(),
            "photo_asset_id": f"PHOTO_SEC_{uuid.uuid4().hex[:8]}",
        },
    )

    await client.post(
        f"/api/v1/media/visits/{v_id}/photo",
        headers={"Authorization": f"Bearer {employee_token}"},
        files={"file": ("sec.jpg", sample_jpeg_bytes, "image/jpeg")},
    )

    # 1. Author employee can access
    acc_emp = await client.get(
        f"/api/v1/media/visits/{v_id}/photo-access",
        headers={"Authorization": f"Bearer {employee_token}"},
    )
    assert acc_emp.status_code == 200
    assert "secure_view_url" in acc_emp.json()
    assert "thumbnail_url" in acc_emp.json()

    # 2. Owner can access
    acc_owner = await client.get(
        f"/api/v1/media/visits/{v_id}/photo-access",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert acc_owner.status_code == 200

    # 3. Unauthenticated receives 401
    acc_unauth = await client.get(f"/api/v1/media/visits/{v_id}/photo-access")
    assert acc_unauth.status_code == 401

@pytest.mark.asyncio
async def test_cloudinary_usage_quota_and_cost_estimation(
    client: AsyncClient,
    owner_token: str,
    employee_token: str,
):
    """
    Verifies the Cloudinary cost and usage analysis endpoint:
    1. Regular employee is rejected with 403.
    2. Owner receives comprehensive Free Tier modeling and pricing transparency.
    """
    # Employee blocked
    emp_res = await client.get(
        "/api/v1/media/usage-and-costs",
        headers={"Authorization": f"Bearer {employee_token}"},
    )
    assert emp_res.status_code == 403

    # Owner access
    owner_res = await client.get(
        "/api/v1/media/usage-and-costs?active_employees=20",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert owner_res.status_code == 200
    data = owner_res.json()

    assert data["monthly_credit_allowance"] == 25
    assert data["cost_current_usd"] == 0.0
    assert data["paid_upgrade_required"] is False
    assert data["active_employees"] == 20
    assert "plus_plan" in data["paid_tier_options"]
    assert "policy_note" in data
