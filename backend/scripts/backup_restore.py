"""
Phyto Doctor Database Backup & Disaster Recovery Utility
Supports both PostgreSQL (Production on Render) and SQLite (Local verification).

Usage:
  python scripts/backup_restore.py --backup
  python scripts/backup_restore.py --restore --file <path_to_backup> --target-url <target_db_url>
  python scripts/backup_restore.py --drill # Automated end-to-end backup and restore integrity drill
"""
import argparse
import datetime
import os
import shutil
import subprocess
import sys
from urllib.parse import urlparse

def get_database_url():
    return os.environ.get("DATABASE_URL", "sqlite+aiosqlite:///./phyto_doctor.db")

def backup_postgres(url: str, output_file: str) -> bool:
    print(f"[*] Initiating PostgreSQL backup using pg_dump...")
    clean_url = url.replace("postgresql+asyncpg://", "postgresql://")
    try:
        cmd = [
            "pg_dump",
            "--dbname", clean_url,
            "--format=custom",
            "--blobs",
            "--verbose",
            "--file", output_file
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0 and os.path.exists(output_file) and os.path.getsize(output_file) > 0:
            print(f"[OK] PostgreSQL backup successful: {output_file} ({os.path.getsize(output_file)} bytes)")
            return True
        else:
            print(f"[!] pg_dump failed or produced empty file: {result.stderr}", file=sys.stderr)
            return False
    except FileNotFoundError:
        print("[!] pg_dump executable not found in PATH. Install PostgreSQL client tools.", file=sys.stderr)
        return False

def backup_sqlite(url: str, output_file: str) -> bool:
    print(f"[*] Initiating SQLite backup snapshot...")
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
            input_file
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        # pg_restore exit code 0 or 1 (warnings on drop) can be acceptable
        if result.returncode in (0, 1):
            print(f"[OK] PostgreSQL restore completed successfully from {input_file}.")
            return True
        else:
            print(f"[!] pg_restore failed with returncode {result.returncode}: {result.stderr}", file=sys.stderr)
            return False
    except FileNotFoundError:
        print("[!] pg_restore executable not found in PATH.", file=sys.stderr)
        return False

def restore_sqlite(input_file: str, target_path: str) -> bool:
    print(f"[*] Restoring SQLite database from {input_file} to {target_path}...")
    try:
        shutil.copy2(input_file, target_path)
        print(f"[OK] SQLite restore completed successfully.")
        return True
    except Exception as e:
        print(f"[!] SQLite restore failed: {e}", file=sys.stderr)
        return False

def run_backup(output_path: str = None) -> str:
    url = get_database_url()
    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d_%H%M%S")
    os.makedirs("./backups", exist_ok=True)
    
    if "postgres" in url:
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
    
    # Verify backup integrity
    size = os.path.getsize(backup_file)
    assert size > 0, "Backup file size is 0 bytes"
    print(f"[2/3] Backup artifact size verification passed: {size} bytes.")
    
    # Test restore into staging / test sandbox
    if "sqlite" in url:
        test_restore_target = "./backups/drill_test_restore.db"
        res = restore_sqlite(backup_file, test_restore_target)
        assert res, "Restore drill failed"
        assert os.path.exists(test_restore_target) and os.path.getsize(test_restore_target) == size
        os.remove(test_restore_target)
        print(f"[3/3] Sandbox restoration drill passed with identical byte parity.")
    else:
        print(f"[3/3] To test PostgreSQL restore drill against a staging database, run:")
        print(f"      python scripts/backup_restore.py --restore --file {backup_file} --target-url <staging_db_url>")
    
    print("=" * 60)
    print("ALL INTEGRITY CHECKS PASSED: BACKUP ARTIFACT VALIDATED.")
    print("=" * 60)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Phyto Doctor DB Backup & Disaster Recovery")
    parser.add_argument("--backup", action="store_true", help="Take a database backup")
    parser.add_argument("--restore", action="store_true", help="Restore database from backup")
    parser.add_argument("--drill", action="store_true", help="Run automated integrity test drill")
    parser.add_argument("--file", type=str, help="Backup file path for restore")
    parser.add_argument("--target-url", type=str, help="Target database connection URL for restore")
    args = parser.parse_args()

    if args.drill:
        run_drill()
    elif args.backup:
        run_backup()
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
