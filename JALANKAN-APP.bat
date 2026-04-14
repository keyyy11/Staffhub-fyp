@echo off
cd /d "%~dp0staffhub-mobile"
echo Installing Flutter packages...
call flutter pub get
echo.
echo Running app in Chrome...
call flutter run -d chrome
rem If the CMD window seems frozen while running: avoid clicking inside it (Quick Edit), or disable QuickEdit Mode in the terminal Properties.
