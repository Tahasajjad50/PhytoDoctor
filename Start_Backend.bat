@echo off
title Phyto Doctor - Backend ^& Database Server
echo ===================================================
echo   PHYTO DOCTOR - BACKEND ^& DATABASE LAUNCHER
echo ===================================================
echo.

cd /d "%~dp0backend"

:: Verify virtualenv or python executable
set "PYTHON_EXE=python"
if exist "%~dp0backend\venv\Scripts\python.exe" (
    set "PYTHON_EXE=%~dp0backend\venv\Scripts\python.exe"
) else if exist "%~dp0venv\Scripts\python.exe" (
    set "PYTHON_EXE=%~dp0venv\Scripts\python.exe"
)

echo [1/3] Checking Database and applying migrations...
"%PYTHON_EXE%" -c "import asyncio; from app.core.database import engine, Base; asyncio.run(engine.begin().then(lambda c: c.run_sync(Base.metadata.create_all)) if hasattr(engine, 'then') else None)" >nul 2>&1

echo [2/3] Configuring ADB reverse port 8000 for Android emulator...
set "ADB_EXE=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if exist "%ADB_EXE%" (
    "%ADB_EXE%" reverse tcp:8000 tcp:8000 >nul 2>&1
    echo       ADB reverse active (Emulator ^<--^> PC localhost:8000)
)

echo [3/3] Launching FastAPI Backend on http://0.0.0.0:8000 ...
echo       Press Ctrl+C anytime to stop server.
echo ===================================================
echo.

"%PYTHON_EXE%" -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

pause
