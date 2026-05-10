@echo off
setlocal EnableExtensions EnableDelayedExpansion

cd /d "%~dp0"

set "TEST_MODE=%~1"
if "%TEST_MODE%"=="" set "TEST_MODE=local"

set "PY_CMD="
if exist "%LocalAppData%\Programs\Python\Python311\python.exe" set "PY_CMD=%LocalAppData%\Programs\Python\Python311\python.exe"
if not defined PY_CMD for %%V in (3.11 3.10 3.9) do (
    py -%%V -c "import sys" >nul 2>nul && set "PY_CMD=py -%%V"
)
if not defined PY_CMD (
    where python >nul 2>nul && set "PY_CMD=python"
)

if not defined PY_CMD (
    echo [ERROR] Python not found.
    echo Install Python 3.9+ and rerun this script.
    exit /b 1
)

echo Using Python command: %PY_CMD%

echo [1/4] Creating virtual environment (if needed)...
if not exist "venv\Scripts\python.exe" (
    %PY_CMD% -m venv venv
    if errorlevel 1 (
        echo [ERROR] Failed to create virtual environment.
        exit /b 1
    )
) else (
    echo venv is ready.
)

echo [2/4] Activating virtual environment...
call "venv\Scripts\activate.bat"
if errorlevel 1 (
    echo [ERROR] Failed to activate virtual environment.
    exit /b 1
)

echo [3/4] Installing test dependencies...
python -m pip install --upgrade pip >nul
python -m pip install pytest requests PyYAML
if errorlevel 1 (
    echo [ERROR] Failed to install dependencies.
    exit /b 1
)

if /I "%PYTEST_USE_PROXY%"=="1" (
    echo [4/5] Keeping proxy settings ^(PYTEST_USE_PROXY=1^).
) else (
    echo [4/5] Disabling proxy for test run...
    set HTTP_PROXY=
    set HTTPS_PROXY=
    set FTP_PROXY=
    set ALL_PROXY=
    set http_proxy=
    set https_proxy=
    set ftp_proxy=
    set all_proxy=
    set NO_PROXY=*
    set no_proxy=*
)

echo [5/5] Running pytest...
if /I "%TEST_MODE%"=="full" (
    shift
    python -m pytest %*
) else if /I "%TEST_MODE%"=="local" (
    shift
    python -m pytest tests\test_files.py tests\test_dockerhub_images.py %*
) else (
    echo [ERROR] Unknown test mode: %TEST_MODE%
    echo Usage:
    echo   run_pytest.cmd local [pytest_args]
    echo   run_pytest.cmd full [pytest_args]
    exit /b 1
)
set TEST_EXIT_CODE=%ERRORLEVEL%

if not "%TEST_EXIT_CODE%"=="0" (
    echo [FAIL] pytest finished with exit code %TEST_EXIT_CODE%.
    exit /b %TEST_EXIT_CODE%
)

echo [OK] pytest finished successfully.
exit /b 0
