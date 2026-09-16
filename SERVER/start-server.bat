@echo off
setlocal EnableExtensions

title Big Hero Server
cd /d "%~dp0"

if not exist "package.json" (
  echo ERROR: package.json was not found.
  echo Run this file from the SERVER folder in the Big-Hero-Web repository.
  pause
  exit /b 1
)

if not exist ".env" (
  echo ERROR: .env was not found.
  echo Copy .env.example to .env and configure the server first.
  pause
  exit /b 1
)

if not exist "node_modules\tsx\dist\cli.mjs" (
  echo ERROR: server dependencies are missing.
  echo Run: npm ci --include=dev --ignore-scripts
  pause
  exit /b 1
)

echo Updating the database and compiled server...
if exist "..\web-client\build.mjs" (
  node "..\web-client\build.mjs"
  if errorlevel 1 (
    echo ERROR: web client build failed. The server was not started.
    pause
    exit /b 1
  )
)

call npm run migrate
if errorlevel 1 (
  echo ERROR: database migration failed. The server was not started.
  pause
  exit /b 1
)

call npm run build
if errorlevel 1 (
  echo ERROR: build failed. The server was not started.
  pause
  exit /b 1
)

set "HOST=0.0.0.0"
set "SERVER_PORT=3000"
for /f "tokens=1,* delims==" %%A in ('findstr /b /c:"PORT=" ".env"') do set "SERVER_PORT=%%B"

set "ZEROTIER_IP="
for /f "delims=" %%I in ('powershell.exe -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 -IPAddress '10.144.*' -ErrorAction SilentlyContinue).IPAddress"') do set "ZEROTIER_IP=%%I"

echo.
echo Starting Big Hero server...
echo Keep this window open while the server is running.
echo Browser URL on this computer: http://127.0.0.1:%SERVER_PORT%/game/
if defined ZEROTIER_IP (
  echo ZeroTier browser URL: http://%ZEROTIER_IP%:%SERVER_PORT%/game/
) else (
  echo ZeroTier network was not detected. Local access is still available.
)
echo.

call npm start

echo.
echo The server has stopped.
pause
