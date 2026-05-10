@echo off
setlocal

cd /d "%~dp0"

docker compose version >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Docker Compose v2 is not available.
    exit /b 1
)

docker compose down
if errorlevel 1 (
    echo [ERROR] Failed to stop containers.
    exit /b 1
)

echo [OK] Containers stopped.
exit /b 0

