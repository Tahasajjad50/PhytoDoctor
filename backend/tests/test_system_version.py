import pytest
from httpx import ASGITransport, AsyncClient
from app.core.config import settings
from app.main import app

@pytest.mark.asyncio
async def test_system_app_version_flow():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Fetch public version info
        res = await client.get("/api/v1/system/version")
        assert res.status_code == 200
        data = res.json()
        assert "latest_version" in data
        assert "min_required_build_number" in data
        assert "download_url" in data

        # 2. Unauthorized update attempt should fail with 403
        unauth_res = await client.post("/api/v1/system/version", json={
            "min_required_build_number": 2,
            "latest_version": "1.0.1"
        })
        assert unauth_res.status_code == 403

        # 3. Authorized update with X-Admin-Key should succeed
        auth_res = await client.post(
            "/api/v1/system/version",
            headers={"X-Admin-Key": settings.SECRET_KEY},
            json={
                "latest_version": "1.0.1",
                "latest_build_number": 2,
                "min_required_build_number": 2,
                "force_update": True,
                "title": "Mandatory Update Available",
                "release_notes": "Staff Attendance feature enabled."
            }
        )
        assert auth_res.status_code == 200
        updated_data = auth_res.json()
        assert updated_data["latest_version"] == "1.0.1"
        assert updated_data["min_required_build_number"] == 2
        assert updated_data["force_update"] is True

        # 4. Verify public endpoint now reflects the mandatory update
        check_res = await client.get("/api/v1/system/version")
        assert check_res.status_code == 200
        assert check_res.json()["min_required_build_number"] == 2

        # 5. Download APK endpoint (redirects to GitHub fallback when static file absent)
        dl_res = await client.get("/api/v1/system/download-apk", follow_redirects=False)
        assert dl_res.status_code in [200, 307, 302]
