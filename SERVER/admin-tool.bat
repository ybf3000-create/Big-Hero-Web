@echo off
setlocal EnableExtensions
title Big Hero Admin Tool
cd /d "%~dp0"

if not exist ".env" (
  echo ERROR: .env was not found.
  pause
  exit /b 1
)

echo Please close the game server before using this tool.
call npm run admin
pause
