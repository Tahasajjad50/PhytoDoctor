"""
PhytoDoctor Password Encryption Migration Script.
Scans all User records in the SQLite database, identifies any unencrypted legacy plaintext
assigned_password entries (not starting with Fernet prefix 'gAAAAA'), encrypts them
using AES-128-CBC Fernet encryption, and commits the changes.
"""
import sys
import os
import sqlite3
import argparse

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from app.core.security import encrypt_credential

def migrate_passwords_sqlite(db_path: str):
    print(f"[*] Scanning database at: {db_path}")
    if not os.path.exists(db_path):
        print(f"[!] Database file does not exist: {db_path}")
        return
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check if assigned_password column exists
    cursor.execute("PRAGMA table_info(users)")
    cols = [col[1] for col in cursor.fetchall()]
    if "assigned_password" not in cols:
        print("[!] Column 'assigned_password' does not exist in 'users' table.")
        conn.close()
        return
    
    cursor.execute("SELECT id, username, assigned_password FROM users")
    rows = cursor.fetchall()
    
    migrated_count = 0
    already_encrypted = 0
    null_count = 0
    
    for user_id, username, raw_pwd in rows:
        if not raw_pwd:
            null_count += 1
            continue
        
        if str(raw_pwd).startswith("gAAAAA"):
            already_encrypted += 1
        else:
            encrypted_pwd = encrypt_credential(str(raw_pwd))
            cursor.execute(
                "UPDATE users SET assigned_password = ? WHERE id = ?",
                (encrypted_pwd, user_id)
            )
            migrated_count += 1
            print(f"    [+] Encrypted credentials for user: {username} (len={len(raw_pwd)} -> {len(encrypted_pwd)})")
    
    conn.commit()
    conn.close()
    
    print("=" * 60)
    print(f"[OK] Migration Complete for {db_path}:")
    print(f"     Total users scanned: {len(rows)}")
    print(f"     Migrated to ciphertext: {migrated_count}")
    print(f"     Already encrypted: {already_encrypted}")
    print(f"     Null/Unassigned: {null_count}")

def main():
    parser = argparse.ArgumentParser(description="Migrate legacy passwords to Fernet ciphertext.")
    parser.add_argument("--db-path", type=str, default=None, help="Path to SQLite DB file")
    args = parser.parse_args()
    
    target_paths = [args.db_path] if args.db_path else [
        "backend/phyto_doctor.db",
        "phyto_doctor.db",
    ]
    
    for path in target_paths:
        if os.path.exists(path):
            migrate_passwords_sqlite(path)

if __name__ == "__main__":
    main()
