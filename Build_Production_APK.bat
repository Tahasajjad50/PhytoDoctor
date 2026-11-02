@echo off
title Phyto Doctor - Build Production APK for Testers
echo ===================================================
echo   PHYTO DOCTOR - PRODUCTION APK BUILDER
echo ===================================================
echo.

set /p RENDER_URL="Enter your live Render backend URL (e.g. https://phytodoctor-api.onrender.com): "

if "%RENDER_URL%"=="" (
    echo.
    echo [ERROR] Backend URL cannot be empty!
    pause
    exit /b 1
)

:: Strip trailing slashes
if "%RENDER_URL:~-1%"=="/" set "RENDER_URL=%RENDER_URL:~0,-1%"

echo.
echo [1/2] Building optimized Release APK pointing to: %RENDER_URL% ...
echo.

cd /d "%~dp0mobile"
call flutter build apk --release --dart-define=API_URL=%RENDER_URL%

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Flutter APK build failed. Please check errors above.
    pause
    exit /b %errorlevel%
)

echo.
echo ===================================================
echo   BUILD SUCCESSFUL!
echo ===================================================
echo.
echo Your production APK is ready at:
echo %~dp0mobile\build\app\outputs\flutter-apk\app-release.apk
echo.
echo You can now send this file to your testers via:
echo 1. WhatsApp / Google Drive / Email
echo 2. Upload to https://www.installonair.com for QR code install
echo ===================================================
echo.

:: Open folder with the generated APK
explorer "%~dp0mobile\build\app\outputs\flutter-apk"

pause
