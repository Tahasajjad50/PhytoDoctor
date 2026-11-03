@echo off
title Phyto Doctor - One-Click App Update Publisher
echo ===================================================
echo   PHYTO DOCTOR - ONE-CLICK IN-APP UPDATE PUBLISHER
echo ===================================================
echo.
echo This tool will:
echo 1. Increment app version and build number
echo 2. Build production Android APK
echo 3. Commit and push tags to GitHub
echo 4. Trigger cloud deployment to Render
echo 5. Enforce mandatory in-app update popup for all users
echo.
echo Press any key to start...
pause >nul
echo.

python "%~dp0scripts\publish_update.py"

echo.
pause

