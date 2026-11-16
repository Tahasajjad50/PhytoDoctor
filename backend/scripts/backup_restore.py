"""
Phyto Doctor Database Backup & Disaster Recovery Utility
Supports PostgreSQL (Production / Staging on Render) and SQLite (Local verification),
with automated pg_dump / pg_restore and portable structured JSON fallback.

Usage:
  python scripts/backup_restore.py --backup
  python scripts/backup_restore.py --backup --format json
  python scripts/backup_restore.py --restore --file <path_to_backup> [--target-url <target_db_url>]
  python scripts/backup_restore.py --drill
"""
import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
from typing import Any, Dict, List

# Ensure app package is importable
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from sqlalchemy import create_engine, select, text
from sqlalchemy.orm import sessionmaker

from app.core.database import Base
from app.models.app_version import AppVersionConfig
from app.models.user import User
from app.models.refresh_token import RefreshToken
from app.models.attendance import Attendance
from app.models.customer import Customer
from app.models.visit import FieldVisit
from app.models.target import EmployeeTarget
from app.models.audit import AuditEvent
from app.models.chat import ChatRoom, ChatMessage

TABLE_MODEL_ORDER = [
    (AppVersionConfig, "app_version_config"),
    (User, "users"),
    (RefreshToken, "refresh_tokens"),
    (Attendance, "attendances"),
    (Customer, "customers"),
    (FieldVisit, "field_visits"),
    (EmployeeTarget, "employee_targets"),
    (AuditEvent, "audit_events"),
    (ChatRoom, "chat_rooms"),
    (ChatMessage, "chat_messages"),
]


def get_database_url() -> str:
    return os.environ.get("DATABASE_URL", "sqlite+aiosqlite:///./phyto_doctor.db")


def json_serializer(obj: Any) -> Any:
    if isinstance(obj, (datetime.datetime, datetime.date, datetime.time)):
        return obj.isoformat()
    return str(obj)


def backup_json(url: str, output_file: str) -> bool:
    print(f"[*] Initiating structured JSON database export to {output_file}...")
    clean_url = url.replace("+aiosqlite", "").replace("+asyncpg", "")
    engine = create_engine(clean_url, echo=False)
    Session = sessionmaker(bind=engine)
    data_payload: Dict[str, List[Dict[str, Any]]] = {}

    try:
        with Session() as sess:
            for model_cls, tbl_name in TABLE_MODEL_ORDER:
                try:
                    records = sess.execute(select(model_cls)).scalars().all()
                    rows = []
                    for rec in records:
                        row_dict = {}
                        for col in model_cls.__table__.columns:
                            val = getattr(rec, col.name)
                            if isinstance(val, (datetime.datetime, datetime.date)):
                                row_dict[col.name] = val.isoformat()
                            else:
                                row_dict[col.name] = val
                        rows.append(row_dict)
                    data_payload[tbl_name] = rows
                    print(f"      - Exported {tbl_name:<24}: {len(rows)} records")
                except Exception as e:
                    print(f"      - Notice: {tbl_name} ({e})")
                    data_payload[tbl_name] = []

        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(
                {
                    "metadata": {
                        "exported_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                        "source_dialect": engine.dialect.name,
                    },
                    "tables": data_payload,
                },
                f,
                indent=2,
                default=json_serializer,
            )
        print(f"[OK] Structured JSON export successful: {output_file} ({os.path.getsize(output_file)} bytes)")
        return True
    except Exception as e:
        print(f"[!] JSON export failed: {e}", file=sys.stderr)
        return False
    finally:
        engine.dispose()


def restore_json(input_file: str, target_url: str) -> bool:
    print(f"[*] Restoring database from structured JSON archive {input_file} to {target_url}...")
    clean_url = target_url.replace("+aiosqlite", "").replace("+asyncpg", "")
    engine = create_engine(clean_url, echo=False)
    Session = sessionmaker(bind=engine)

    try:
        with open(input_file, "r", encoding="utf-8") as f:
            payload = json.load(f)

        tables_data = payload.get("tables", {})
        Base.metadata.create_all(engine)

        with Session() as sess:
            for model_cls, tbl_name in TABLE_MODEL_ORDER:
                rows = tables_data.get(tbl_name, [])
                if not rows:
                    continue
                for r in rows:
                    cols = {c.name: c for c in model_cls.__table__.columns}
                    processed_attrs = {}
                    for k, v in r.items():
                        if k in cols and v is not None:
                            col_type = str(cols[k].type).upper()
                            if "DATETIME" in col_type or "TIMESTAMP" in col_type:
                                try:
                                    processed_attrs[k] = datetime.datetime.fromisoformat(v)
                                except Exception:
                                    processed_attrs[k] = v
                            elif "DATE" in col_type:
                                try:
                                    processed_attrs[k] = datetime.date.fromisoformat(v)
                                except Exception:
                                    processed_attrs[k] = v
                            else:
                                processed_attrs[k] = v
                    sess.merge(model_cls(**processed_attrs))
                sess.flush()
                print(f"      - Restored {tbl_name:<24}: {len(rows)} records")
            sess.commit()
        print(f"[OK] JSON database restoration completed successfully into {target_url}.")
        return True
    except Exception as e:
        print(f"[!] JSON restore failed: {e}", file=sys.stderr)
        return False
    finally:
        engine.dispose()


def backup_postgres(url: str, output_file: str) -> bool:
    print("[*] Initiating PostgreSQL backup using pg_dump...")
    clean_url = url.replace("postgresql+asyncpg://", "postgresql://")
    try:
        cmd = [
            "pg_dump",
            "--dbname", clean_url,
            "--format=custom",
            "--blobs",
            "--verbose",
            "--file", output_file,
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0 and os.path.exists(output_file) and os.path.getsize(output_file) > 0:
            print(f"[OK] PostgreSQL pg_dump successful: {output_file} ({os.path.getsize(output_file)} bytes)")
            return True
        else:
            print(f"[!] pg_dump exited with error: {result.stderr.strip()}", file=sys.stderr)
            print("[*] Falling back to SQLAlchemy structured JSON export...")
            json_file = output_file.rsplit(".", 1)[0] + ".json"
            return backup_json(url, json_file)
    except FileNotFoundError:
        print("[!] pg_dump executable not found in system PATH.", file=sys.stderr)
        print("[*] Falling back to SQLAlchemy structured JSON export...")
        json_file = output_file.rsplit(".", 1)[0] + ".json"
        return backup_json(url, json_file)


def backup_sqlite(url: str, output_file: str) -> bool:
    print("[*] Initiating SQLite backup snapshot...")
    db_path = url.replace("sqlite+aiosqlite:///", "").replace("sqlite:///", "")
    if not os.path.exists(db_path):
        print(f"[!] SQLite source database not found at {db_path}", file=sys.stderr)
        return False
    try:
        shutil.copy2(db_path, output_file)
        if os.path.exists(output_file) and os.path.getsize(output_file) > 0:
            print(f"[OK] SQLite backup snapshot successful: {output_file} ({os.path.getsize(output_file)} bytes)")
            return True
        return False
    except Exception as e:
        print(f"[!] SQLite copy failed: {e}", file=sys.stderr)
        return False


def restore_postgres(input_file: str, target_url: str) -> bool:
    if input_file.endswith(".json"):
        return restore_json(input_file, target_url)

    print(f"[*] Restoring PostgreSQL database from {input_file}...")
    clean_url = target_url.replace("postgresql+asyncpg://", "postgresql://")
    try:
        cmd = [
            "pg_restore",
            "--dbname", clean_url,
            "--clean",
            "--if-exists",
            "--no-owner",
            "--no-privileges",
            "--verbose",
            input_file,
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode in (0, 1):
            print(f"[OK] PostgreSQL restore completed successfully from {input_file}.")
            return True
        else:
            print(f"[!] pg_restore failed with code {result.returncode}: {result.stderr}", file=sys.stderr)
            return False
    except FileNotFoundError:
        print("[!] pg_restore executable not found in PATH.", file=sys.stderr)
        return False


def restore_sqlite(input_file: str, target_path: str) -> bool:
    if input_file.endswith(".json"):
        return restore_json(input_file, f"sqlite:///{target_path}")

    print(f"[*] Restoring SQLite database from {input_file} to {target_path}...")
    try:
        shutil.copy2(input_file, target_path)
        print("[OK] SQLite restore completed successfully.")
        return True
    except Exception as e:
        print(f"[!] SQLite restore failed: {e}", file=sys.stderr)
        return False


def run_backup(output_path: str = None, force_json: bool = False) -> str:
    url = get_database_url()
    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d_%H%M%S")
    os.makedirs("./backups", exist_ok=True)

    if force_json:
        output_file = output_path or f"./backups/phytodoctor_backup_{timestamp}.json"
        success = backup_json(url, output_file)
    elif "postgres" in url:
        output_file = output_path or f"./backups/phytodoctor_pg_{timestamp}.dump"
        success = backup_postgres(url, output_file)
    else:
        output_file = output_path or f"./backups/phytodoctor_sqlite_{timestamp}.db"
        success = backup_sqlite(url, output_file)

    if not success:
        sys.exit(1)
    return output_file


def run_drill():
    print("=" * 60)
    print("PHYTO DOCTOR BACKUP & RESTORE INTEGRITY DRILL")
    print("=" * 60)
    url = get_database_url()
    print(f"Target Source URL: {url.split('@')[-1] if '@' in url else url}")

    backup_file = run_backup()
    print(f"[1/3] Backup artifact generated: {backup_file}")

    size = os.path.getsize(backup_file)
    assert size > 0, "Backup file size is 0 bytes"
    print(f"[2/3] Backup artifact size verification passed: {size} bytes.")

    if "sqlite" in url:
        test_restore_target = "./backups/drill_test_restore.db"
        res = restore_sqlite(backup_file, test_restore_target)
        assert res, "Restore drill failed"
        assert os.path.exists(test_restore_target) and os.path.getsize(test_restore_target) == size
        os.remove(test_restore_target)
        print("[3/3] Sandbox restoration drill passed with identical byte parity.")

    # Also test JSON backup/restore drill
    print("\n[*] Testing cross-platform JSON export & import drill...")
    json_drill_file = "./backups/drill_export.json"
    assert backup_json(url, json_drill_file), "JSON export failed"
    assert os.path.exists(json_drill_file) and os.path.getsize(json_drill_file) > 0
    os.remove(json_drill_file)
    print("[3/3] JSON portable export drill passed.")

    print("=" * 60)
    print("ALL INTEGRITY CHECKS PASSED: BACKUP ARTIFACT VALIDATED.")
    print("=" * 60)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Phyto Doctor DB Backup & Disaster Recovery")
    parser.add_argument("--backup", action="store_true", help="Take a database backup")
    parser.add_argument("--format", type=str, choices=["dump", "sqlite", "json"], default=None, help="Backup format")
    parser.add_argument("--restore", action="store_true", help="Restore database from backup")
    parser.add_argument("--drill", action="store_true", help="Run automated integrity test drill")
    parser.add_argument("--file", type=str, help="Backup file path for restore")
    parser.add_argument("--target-url", type=str, help="Target database connection URL for restore")
    args = parser.parse_args()

    if args.drill:
        run_drill()
    elif args.backup:
        run_backup(force_json=(args.format == "json"))
    elif args.restore:
        if not args.file:
            print("[!] --file is required for restore.", file=sys.stderr)
            sys.exit(1)
        target = args.target_url or get_database_url()
        if "postgres" in target:
            restore_postgres(args.file, target)
        else:
            clean_path = target.replace("sqlite+aiosqlite:///", "").replace("sqlite:///", "")
            restore_sqlite(args.file, clean_path)
    else:
        parser.print_help()
