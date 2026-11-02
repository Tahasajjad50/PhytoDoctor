import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app

@pytest.mark.asyncio
async def test_chat_announcements_and_permissions():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Login as Owner (CEO)
        owner_login = await client.post(
            "/api/v1/auth/login",
            json={"username_or_email": "owner", "password": "owner123", "portal": "admin"}
        )
        assert owner_login.status_code == 200
        owner_token = owner_login.json()["access_token"]
        owner_headers = {"Authorization": f"Bearer {owner_token}"}

        # 2. Login as Manager (Admin)
        mgr_login = await client.post(
            "/api/v1/auth/login",
            json={"username_or_email": "manager.punjab", "password": "manager123", "portal": "admin"}
        )
        assert mgr_login.status_code == 200
        mgr_token = mgr_login.json()["access_token"]
        mgr_headers = {"Authorization": f"Bearer {mgr_token}"}

        # 3. Login as Employee
        emp_login = await client.post(
            "/api/v1/auth/login",
            json={"username_or_email": "emp.john", "password": "emp123", "portal": "employee"}
        )
        assert emp_login.status_code == 200
        emp_token = emp_login.json()["access_token"]
        emp_headers = {"Authorization": f"Bearer {emp_token}"}

        # 4. Owner lists rooms (should ensure announcement and leadership rooms exist)
        rooms_res = await client.get("/api/v1/chat/rooms", headers=owner_headers)
        assert rooms_res.status_code == 200
        rooms = rooms_res.json()
        assert len(rooms) >= 2
        ann_room = next(r for r in rooms if r["room_type"] == "ANNOUNCEMENT")
        lead_room = next(r for r in rooms if r["room_type"] == "MANAGEMENT")

        # 5. Owner broadcasts an announcement
        broadcast_res = await client.post(
            f"/api/v1/chat/rooms/{ann_room['id']}/messages",
            json={"content": "Welcome to PhytoDoctor Q4 targets! Stay safe and log your GPS visits."},
            headers=owner_headers
        )
        assert broadcast_res.status_code == 201
        msg_data = broadcast_res.json()
        assert msg_data["is_announcement"] is True

        # 6. Employee reads announcement
        emp_read_res = await client.get(
            f"/api/v1/chat/rooms/{ann_room['id']}/messages",
            headers=emp_headers
        )
        assert emp_read_res.status_code == 200
        emp_messages = emp_read_res.json()
        assert len(emp_messages) == 1
        assert "Q4 targets" in emp_messages[0]["content"]

        # 7. Employee cannot post announcements (forbidden)
        emp_post_res = await client.post(
            f"/api/v1/chat/rooms/{ann_room['id']}/messages",
            json={"content": "Can I broadcast to company?"},
            headers=emp_headers
        )
        assert emp_post_res.status_code == 403

        # 8. Employee cannot access management/leadership room
        emp_lead_res = await client.get(
            f"/api/v1/chat/rooms/{lead_room['id']}/messages",
            headers=emp_headers
        )
        assert emp_lead_res.status_code == 403

@pytest.mark.asyncio
async def test_employee_direct_chat_with_admin_and_ceo_full_access():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Logins
        owner_token = (await client.post("/api/v1/auth/login", json={"username_or_email": "owner", "password": "owner123", "portal": "admin"})).json()["access_token"]
        mgr_token = (await client.post("/api/v1/auth/login", json={"username_or_email": "manager.punjab", "password": "manager123", "portal": "admin"})).json()["access_token"]
        emp_token = (await client.post("/api/v1/auth/login", json={"username_or_email": "emp.john", "password": "emp123", "portal": "employee"})).json()["access_token"]

        owner_headers = {"Authorization": f"Bearer {owner_token}"}
        mgr_headers = {"Authorization": f"Bearer {mgr_token}"}
        emp_headers = {"Authorization": f"Bearer {emp_token}"}

        # 1. Employee lists available admins
        admins_res = await client.get("/api/v1/chat/admins", headers=emp_headers)
        assert admins_res.status_code == 200
        admin_contacts = admins_res.json()
        assert len(admin_contacts) >= 2
        assigned_admin = next(a for a in admin_contacts if a["is_assigned"] is True)
        assert assigned_admin["id"] == "manager-uuid-2"

        # 2. Employee starts direct chat with assigned manager
        open_room_res = await client.post(
            "/api/v1/chat/rooms",
            json={"target_user_id": assigned_admin["id"]},
            headers=emp_headers
        )
        assert open_room_res.status_code == 201
        direct_room = open_room_res.json()
        room_id = direct_room["id"]
        assert direct_room["room_type"] == "DIRECT"

        # 3. Employee sends a question to manager
        send_res = await client.post(
            f"/api/v1/chat/rooms/{room_id}/messages",
            json={"content": "Hello Manager, having an issue with shop geofence verification on Multan route."},
            headers=emp_headers
        )
        assert send_res.status_code == 201
        m1 = send_res.json()

        # 4. Manager replies
        reply_res = await client.post(
            f"/api/v1/chat/rooms/{room_id}/messages",
            json={"content": "Understood John, please submit high-accuracy GPS sample and I will verify it."},
            headers=mgr_headers
        )
        assert reply_res.status_code == 201
        m2 = reply_res.json()

        # 5. CEO (OWNER) has access to EVERY chatroom: can view the private conversation
        ceo_room_messages = await client.get(
            f"/api/v1/chat/rooms/{room_id}/messages",
            headers=owner_headers
        )
        assert ceo_room_messages.status_code == 200
        ceo_view = ceo_room_messages.json()
        assert len(ceo_view) == 2
        assert "Multan route" in ceo_view[0]["content"]
        assert "high-accuracy GPS" in ceo_view[1]["content"]

        # 6. CEO can also send a message / intervene in the conversation
        ceo_send_res = await client.post(
            f"/api/v1/chat/rooms/{room_id}/messages",
            json={"content": "Noted by CEO office. Farhan, please prioritize this approval."},
            headers=owner_headers
        )
        assert ceo_send_res.status_code == 201

        # 7. Test lightweight polling with `after` parameter
        poll_res = await client.get(
            f"/api/v1/chat/rooms/{room_id}/messages?after={m2['created_at']}",
            headers=emp_headers
        )
        assert poll_res.status_code == 200
        new_msgs = poll_res.json()
        assert len(new_msgs) == 1
        assert "CEO office" in new_msgs[0]["content"]
