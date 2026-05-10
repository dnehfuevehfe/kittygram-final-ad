@echo off
setlocal EnableExtensions EnableDelayedExpansion

cd /d "%~dp0"

if not exist ".env" (
    if exist ".env.example" (
        copy /Y ".env.example" ".env" >nul
        echo [INFO] Created .env from .env.example
    ) else (
        echo [ERROR] File .env not found.
        echo Create .env in project root and run script again.
        exit /b 1
    )
)

docker --version >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Docker is not installed or unavailable in PATH.
    exit /b 1
)

docker compose version >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Docker Compose v2 is not available.
    echo Install Docker Desktop. It includes docker compose.
    exit /b 1
)

echo [1/4] Building and starting containers...
docker compose up -d --build
if errorlevel 1 (
    echo [ERROR] docker compose up failed.
    exit /b 1
)

echo [2/4] Waiting for backend container...
set /a RETRIES=30
:wait_backend
set "BACKEND_CID="
for /f %%I in ('docker compose ps -q backend 2^>nul') do set "BACKEND_CID=%%I"
if defined BACKEND_CID (
    set "BACKEND_RUNNING="
    for /f %%S in ('docker inspect -f "{{.State.Running}}" !BACKEND_CID! 2^>nul') do set "BACKEND_RUNNING=%%S"
    if /I "!BACKEND_RUNNING!"=="true" goto backend_ready
)
set /a RETRIES-=1
if !RETRIES! LEQ 0 (
    echo [ERROR] Backend container did not start in time.
    echo Run: docker compose logs backend
    exit /b 1
)
timeout /t 2 /nobreak >nul
goto wait_backend

:backend_ready
echo [3/4] Applying migrations...
set /a RETRIES=20
:migrate_retry
docker compose exec -T backend python manage.py migrate >nul 2>nul
if not errorlevel 1 goto migrate_ok
set /a RETRIES-=1
if !RETRIES! LEQ 0 (
    echo [ERROR] Migrations failed.
    echo Run: docker compose logs backend
    exit /b 1
)
timeout /t 2 /nobreak >nul
goto migrate_retry

:migrate_ok
echo [4/4] Collecting static files...
docker compose exec -T backend python manage.py collectstatic --noinput
if errorlevel 1 (
    echo [ERROR] collectstatic failed.
    exit /b 1
)

echo [OK] Kittygram is up.
echo Open: http://127.0.0.1:9000
echo Stop containers with: run_stop.cmd
exit /b 0
