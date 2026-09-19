@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Run a temporary copy so this updater can safely replace itself during git update.
if not defined BIG_HERO_UPDATER_TEMP (
  for %%I in ("%~dp0..") do set "BIG_HERO_REPO=%%~fI"
  set "UPDATER_TEMP=%TEMP%\big-hero-update-%RANDOM%-%RANDOM%.bat"
  copy /y "%~f0" "!UPDATER_TEMP!" >nul
  if errorlevel 1 (
    echo ERROR: Could not create the temporary updater.
    pause
    exit /b 1
  )
  set "BIG_HERO_UPDATER_TEMP=1"
  call "!UPDATER_TEMP!" %*
  set "UPDATER_EXIT=!ERRORLEVEL!"
  del /q "!UPDATER_TEMP!" >nul 2>&1
  exit /b !UPDATER_EXIT!
)

title Big Hero - Update and Start
cd /d "%BIG_HERO_REPO%"

echo ========================================
echo   Big Hero automatic update and start
echo ========================================
echo.

if not exist ".git" (
  echo ERROR: This file must be run from the cloned Big-Hero-Web repository.
  goto :fatal
)

where git.exe >nul 2>&1
if errorlevel 1 (
  echo ERROR: Git was not found. Install Git for Windows first.
  goto :fatal
)

where node.exe >nul 2>&1
if errorlevel 1 (
  echo ERROR: Node.js was not found. Install Node.js 22 or newer first.
  goto :fatal
)

set "CURRENT_BRANCH="
for /f "delims=" %%I in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%I"
if /i not "!CURRENT_BRANCH!"=="main" (
  echo WARNING: The current Git branch is not main. Automatic update was skipped.
  goto :start_server
)

set "WORKTREE_DIRTY="
for /f "delims=" %%I in ('git status --porcelain 2^>nul') do set "WORKTREE_DIRTY=1"
if defined WORKTREE_DIRTY (
  echo WARNING: Local project files have changes. Automatic update was skipped to protect them.
  echo Ask the maintainer to inspect this server copy before updating.
  goto :start_server
)

set "LOCAL_FULL="
set "LOCAL_SHORT="
for /f "delims=" %%I in ('git rev-parse HEAD 2^>nul') do set "LOCAL_FULL=%%I"
for /f "delims=" %%I in ('git rev-parse --short HEAD 2^>nul') do set "LOCAL_SHORT=%%I"
if not defined LOCAL_FULL (
  echo ERROR: The installed Git version could not be read.
  goto :fatal
)

echo Installed version: !LOCAL_SHORT!
echo Checking GitHub for updates...
git fetch --quiet origin main
if errorlevel 1 (
  echo GitHub check through the configured network failed. Retrying without a proxy...
  git -c http.proxy= -c https.proxy= fetch --quiet origin main
)
if errorlevel 1 (
  echo WARNING: GitHub is unavailable. Starting installed version !LOCAL_SHORT!.
  goto :start_server
)

set "REMOTE_FULL="
set "REMOTE_SHORT="
for /f "delims=" %%I in ('git rev-parse origin/main 2^>nul') do set "REMOTE_FULL=%%I"
for /f "delims=" %%I in ('git rev-parse --short origin/main 2^>nul') do set "REMOTE_SHORT=%%I"
if not defined REMOTE_FULL (
  echo WARNING: The remote version could not be read. Starting the installed version.
  goto :start_server
)

echo Latest version:    !REMOTE_SHORT!
if /i "!LOCAL_FULL!"=="!REMOTE_FULL!" (
  echo The server is already up to date.
  goto :start_server
)

git merge-base --is-ancestor HEAD origin/main >nul 2>&1
if errorlevel 1 (
  echo WARNING: The local and remote histories differ. Automatic update was skipped.
  echo Ask the maintainer to inspect this server copy before updating.
  goto :start_server
)

set "DEPENDENCIES_CHANGED="
for /f "delims=" %%I in ('git diff --name-only "!LOCAL_FULL!" origin/main -- SERVER/package.json SERVER/package-lock.json 2^>nul') do set "DEPENDENCIES_CHANGED=1"

if exist "SERVER\.env" (
  if not exist "SERVER\node_modules\tsx\dist\cli.mjs" (
    echo.
    echo Restoring the installed server dependencies before backup...
    pushd "SERVER"
    call npm ci --include=dev --ignore-scripts
    set "NPM_EXIT=!ERRORLEVEL!"
    popd
    if not "!NPM_EXIT!"=="0" (
      echo ERROR: Dependency installation failed. The update was cancelled.
      goto :fatal
    )
  )
  echo.
  echo Backing up the SQLite database before updating...
  pushd "SERVER"
  call npm run backup
  set "BACKUP_EXIT=!ERRORLEVEL!"
  popd
  if not "!BACKUP_EXIT!"=="0" (
    echo ERROR: Database backup failed. The update was cancelled.
    goto :fatal
  )
)

echo.
echo Installing version !REMOTE_SHORT!...
git merge --ff-only origin/main
if errorlevel 1 (
  echo ERROR: Git could not apply the update. The installed files were not overwritten.
  goto :fatal
)

if defined DEPENDENCIES_CHANGED goto :install_dependencies
if not exist "SERVER\node_modules\tsx\dist\cli.mjs" goto :install_dependencies
goto :update_complete

:install_dependencies
echo.
echo Installing updated server dependencies...
pushd "SERVER"
call npm ci --include=dev --ignore-scripts
set "NPM_EXIT=!ERRORLEVEL!"
popd
if not "!NPM_EXIT!"=="0" (
  echo ERROR: Dependency installation failed. The server was not started.
  goto :fatal
)
if defined START_AFTER_INSTALL goto :start_server

:update_complete
set "INSTALLED_SHORT="
for /f "delims=" %%I in ('git rev-parse --short HEAD 2^>nul') do set "INSTALLED_SHORT=%%I"
echo Update complete. Installed version: !INSTALLED_SHORT!

:start_server
if /i "%~1"=="--no-start" (
  echo Update check complete. The server was not started.
  exit /b 0
)
if not exist "SERVER\node_modules\tsx\dist\cli.mjs" (
  echo Server dependencies are missing and will be installed automatically.
  set "START_AFTER_INSTALL=1"
  goto :install_dependencies
)
echo.
echo Starting the game server...
call "%BIG_HERO_REPO%\SERVER\start-server.bat"
exit /b !ERRORLEVEL!

:fatal
echo.
echo The automatic updater stopped without deleting player data.
pause
exit /b 1
