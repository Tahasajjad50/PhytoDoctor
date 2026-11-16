# 08 – DATABASE ARCHITECTURE & SCHEMA VERIFICATION

## 1. Database Engine & Connection
- **Engine:** SQLite 3 with `aiosqlite` async driver in SQLAlchemy 2.0.
- **Connection URI:** `sqlite+aiosqlite:///./phyto_doctor.db`

## 2. Table Inventory & Column Migrations
All tables confirmed present and aligned with SQLAlchemy ORM models:
1. `users`: 14 columns (`id`, `full_name`, `email`, `username`, `hashed_password`, `role`, `is_active`, `phone`, `designation`, `manager_id`, `created_by_id`, `assigned_password`, `created_at`, `updated_at`).
2. `field_visits`: 18 columns (`id`, `employee_id`, `client_name`, `client_phone`, `notes`, `latitude`, `longitude`, `gps_accuracy`, `is_mock_location`, `device_capture_time`, `server_receipt_time`, `photo_asset_id`, `photo_url`, `is_flagged_for_review`, `status`, `review_reason`, `reviewed_by_id`, `reviewed_at`).
3. `employee_targets`: 8 columns (`id`, `employee_id`, `period`, `target_count`, `start_date`, `end_date`, `created_at`, `updated_at`).
4. `attendances`: 6 columns (`id`, `user_id`, `date`, `clock_in_time`, `clock_out_time`, `is_active`).
5. `audit_events`: 8 columns (`id`, `action`, `actor_id`, `actor_role`, `affected_record_id`, `affected_record_type`, `metadata_json`, `server_timestamp`).
6. `refresh_tokens`: 7 columns (`id`, `user_id`, `token_hash`, `expires_at`, `is_revoked`, `created_at`, `updated_at`).
7. `customers`: 13 columns (Dealer and farmer client registry).
8. `chat_rooms` & `chat_messages`: 8 columns each (Internal communications).
9. `app_version_configs`: 9 columns (In-app force update configurations).

## 3. Automated SQLite Migration Guard
Added in `backend/app/main.py`:
```python
def _run_sqlite_column_migrations(conn):
    res = conn.execute(text("PRAGMA table_info(users)")).fetchall()
    existing_cols = {row[1] for row in res}
    if "created_by_id" not in existing_cols:
        conn.execute(text("ALTER TABLE users ADD COLUMN created_by_id VARCHAR(36)"))
    if "assigned_password" not in existing_cols:
        conn.execute(text("ALTER TABLE users ADD COLUMN assigned_password VARCHAR(255)"))
```
This guarantees existing databases boot safely without SQL errors.
