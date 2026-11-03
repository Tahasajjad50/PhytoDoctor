@echo off
title Phyto Doctor - Render Server Keep-Alive
echo ===================================================
echo   PHYTO DOCTOR - RENDER KEEP-ALIVE DAEMON
echo ===================================================
echo.
echo Pinging https://phytodoctor-api.onrender.com every 10 minutes
echo to ensure your server never sleeps.
echo.
echo Press Ctrl+C to stop.
echo.

python "%~dp0backend\scripts\keep_alive_ping.py"

pause
