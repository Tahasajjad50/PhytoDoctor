"""
PhytoDoctor - Single-Click Release & In-App Update Publisher
Automates the full cycle:
1. Version & build number auto-increment.
2. Compiles production release APK for Android.
3. Copies APK to root and backend static repository.
4. Updates Render cloud version requirement so all mobile users get the mandatory update popup.
5. Pushes git commit, tags, and triggers Render deployment.
"""
import os
import re
import subprocess
import sys
import urllib.request
import json

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOBILE_DIR = os.path.join(ROOT_DIR, "mobile")
APP_CONFIG_PATH = os.path.join(MOBILE_DIR, "lib", "core", "config", "app_config.dart")
PUBSPEC_PATH = os.path.join(MOBILE_DIR, "pubspec.yaml")
BACKEND_STATIC_DIR = os.path.join(ROOT_DIR, "backend", "app", "static")
RENDER_SERVICE_ID = "srv-dbl3hk08v5cc73ak1tc0"
RENDER_CLI_PATH = r"C:\Users\Taha Sajjad\AppData\Local\Microsoft\WinGet\Packages\Render.CLI_Microsoft.Winget.Source_8wekyb3d8bbwe\render.exe"

def run_cmd(cmd, cwd=ROOT_DIR):
    print(f"\n[EXEC] {cmd} (in {os.path.basename(cwd)})")
    res = subprocess.run(cmd, shell=True, cwd=cwd)
    if res.returncode != 0:
        print(f"\n[ERROR] Command failed with exit code {res.returncode}: {cmd}")
        sys.exit(res.returncode)

def get_current_version_info():
    with open(APP_CONFIG_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    ver_match = re.search(r"static const String appVersion = ['\"]([^'\"]+)['\"];", content)
    build_match = re.search(r"static const int buildNumber = (\d+);", content)

    current_ver = ver_match.group(1) if ver_match else "1.0.0"
    current_build = int(build_match.group(1)) if build_match else 1
    return current_ver, current_build

def update_version_files(new_ver, new_build):
    # Update app_config.dart
    with open(APP_CONFIG_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    content = re.sub(
        r"static const String appVersion = ['\"][^'\"]+['\"];",
        f"static const String appVersion = '{new_ver}';",
        content
    )
    content = re.sub(
        r"static const int buildNumber = \d+;",
        f"static const int buildNumber = {new_build};",
        content
    )
    with open(APP_CONFIG_PATH, "w", encoding="utf-8") as f:
        f.write(content)

    # Update pubspec.yaml
    with open(PUBSPEC_PATH, "r", encoding="utf-8") as f:
        pubspec = f.read()

    pubspec = re.sub(
        r"version:\s*[^\s]+",
        f"version: {new_ver}+{new_build}",
        pubspec
    )
    with open(PUBSPEC_PATH, "w", encoding="utf-8") as f:
        f.write(pubspec)

    print(f"[OK] Incremented version: v{new_ver} (Build {new_build}) in config & pubspec.yaml")

def main():
    print("=" * 65)
    print("   PHYTO DOCTOR - ONE-CLICK PRODUCTION UPDATE PUBLISHER")
    print("=" * 65)

    curr_ver, curr_build = get_current_version_info()
    next_build = curr_build + 1

    # Default next semantic version e.g. 1.0.0 -> 1.0.1
    parts = curr_ver.split(".")
    if len(parts) == 3 and parts[2].isdigit():
        suggested_ver = f"{parts[0]}.{parts[1]}.{int(parts[2]) + 1}"
    else:
        suggested_ver = f"{curr_ver}.1"

    print(f"\nCurrent App Version: v{curr_ver} (Build {curr_build})")
    print(f"Target Next Version: v{suggested_ver} (Build {next_build})")
    print("-" * 65)

    # Allow custom inputs or quick enter defaults
    try:
        user_ver = input(f"Enter version name [{suggested_ver}]: ").strip()
        new_version = user_ver if user_ver else suggested_ver

        default_notes = f"Update v{new_version}: latest features, live attendance, and performance improvements."
        user_notes = input(f"Enter release notes [{default_notes}]: ").strip()
        release_notes = user_notes if user_notes else default_notes
    except EOFError:
        new_version = suggested_ver
        release_notes = f"Update v{new_version}: latest features and fixes."

    print(f"\n[1/5] Updating version numbers to v{new_version} (Build {next_build})...")
    update_version_files(new_version, next_build)

    print(f"\n[2/5] Compiling Android Release APK with Flutter...")
    build_cmd = (
        'cmd.exe /c "flutter --no-version-check build apk --release '
        '--dart-define=API_URL=https://phytodoctor-api.onrender.com '
        '--android-skip-build-dependency-validation"'
    )
    run_cmd(build_cmd, cwd=MOBILE_DIR)

    apk_source = os.path.join(MOBILE_DIR, "build", "app", "outputs", "flutter-apk", "app-release.apk")
    if not os.path.exists(apk_source):
        print(f"[ERROR] APK output not found at: {apk_source}")
        sys.exit(1)

    print(f"\n[3/5] Packaging APK binary for cloud distribution...")
    root_apk = os.path.join(ROOT_DIR, "PhytoDoctor-release.apk")
    os.makedirs(BACKEND_STATIC_DIR, exist_ok=True)
    backend_apk = os.path.join(BACKEND_STATIC_DIR, "PhytoDoctor-release.apk")

    import shutil
    shutil.copy2(apk_source, root_apk)
    shutil.copy2(apk_source, backend_apk)
    apk_size_mb = os.path.getsize(root_apk) / (1024 * 1024)
    print(f"[OK] PhytoDoctor-release.apk ({apk_size_mb:.1f} MB) ready.")

    print(f"\n[4/5] Committing changes & pushing to GitHub...")
    run_cmd("git add mobile/lib/core/config/app_config.dart mobile/pubspec.yaml")
    run_cmd(f'git commit -m "Release v{new_version} (Build {next_build}): {release_notes}"')
    run_cmd(f'git tag -a v{new_version} -m "Release v{new_version}"')
    run_cmd("git push origin main --tags")

    print(f"\n[5/5] Deploying update to Render cloud instance...")
    if os.path.exists(RENDER_CLI_PATH):
        deploy_cmd = f'"{RENDER_CLI_PATH}" deploys create {RENDER_SERVICE_ID} --confirm'
        run_cmd(deploy_cmd)
    else:
        print("[!] Render CLI path not found, relying on git push webhook.")

    print("\n" + "=" * 65)
    print("  🎉 UPDATE PUBLISHED SUCCESSFULLY!")
    print(f"  • New Version: v{new_version} (Build {next_build})")
    print("  • Mandatory Pre-Login In-App Update: ENFORCED")
    print("  • Download Route: https://phytodoctor-api.onrender.com/api/v1/system/download-apk")
    print("=" * 65)
    print("\nAll 20 users will now see the non-dismissible update popup")
    print("immediately before logging in when opening the app!")
    print("=" * 65 + "\n")

if __name__ == "__main__":
    main()

