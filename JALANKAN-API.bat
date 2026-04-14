@echo off
cd /d "%~dp0staffhub-api"
echo Installing packages...
call npm.cmd install
echo.
echo Freeing port 3000 if already in use (avoids crash)...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :3000 ^| findstr LISTENING') do (
  echo Closing PID: %%a
  taskkill /F /PID %%a >nul 2>&1
)
timeout /t 1 /nobreak >nul
echo.
echo Starting API...
call npm.cmd run dev
