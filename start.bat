@echo off
cd /d "%~dp0"
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:"127.0.0.1:8787 .*LISTENING"') do (
  echo Stopping previous Astra Nutrition OS server...
  taskkill /PID %%P /F >nul 2>&1
)
timeout /t 1 /nobreak >nul
start "Astra Nutrition OS" http://127.0.0.1:8787
python server.py
