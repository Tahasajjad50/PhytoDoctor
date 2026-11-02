@echo off
title Phyto Doctor - Android Emulator Launcher
echo ===================================================
echo   Phyto Doctor - Launching Visible Android Emulator
echo ===================================================
echo.

echo Checking existing background emulator instances...
taskkill /F /IM qemu-system-x86_64.exe >nul 2>&1
taskkill /F /IM emulator.exe >nul 2>&1
timeout /t 2 /nobreak >nul

echo Starting Android Phone Emulator window on your desktop...
set "EMU_EXE=%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe"
set "ADB_EXE=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"

set "AVD_NAME=Medium_Phone_API_36.1"
if exist "%USERPROFILE%\.android\avd\PhytoDoctor_Pixel.avd" set "AVD_NAME=PhytoDoctor_Pixel"

set "ADB_VENDOR_KEYS=%USERPROFILE%\.android\adbkey;C:\Android\.android\adbkey"

start "" "%EMU_EXE%" -avd %AVD_NAME% -gpu host -no-boot-anim

echo Waiting for device to be ready...
echo (If an 'Allow USB debugging' popup appears on the phone screen, please click 'Allow')
"%ADB_EXE%" wait-for-device

echo.
echo Checking and installing Phyto Doctor Field Application...
set "APK_PATH=%~dp0mobile\build\app\outputs\flutter-apk\app-debug.apk"
if not exist "%APK_PATH%" set "APK_PATH=%~dp0mobile\build\app\outputs\apk\debug\app-debug.apk"
if exist "%APK_PATH%" (
    echo Installing: %APK_PATH%
    "%ADB_EXE%" install -r "%APK_PATH%"
)

echo Checking backend API server status...
netstat -ano | findstr :8000 >nul 2>&1
if errorlevel 1 (
    echo Starting FastAPI backend server in background on port 8000...
    start "Phyto Doctor Backend" /min cmd /c "cd /d "%~dp0backend" && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000"
    timeout /t 3 /nobreak >nul
)

"%ADB_EXE%" reverse tcp:8000 tcp:8000 >nul 2>&1

echo Launching Phyto Doctor Field Application...
timeout /t 3 /nobreak >nul
"%ADB_EXE%" shell am start -n com.phytodoctor.fieldapp/.MainActivity

echo.
echo ===================================================
echo   Emulator and Backend are active!
echo ===================================================
timeout /t 4
