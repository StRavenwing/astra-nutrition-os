@echo off
setlocal
cd /d "%~dp0"

set "GH=C:\Program Files\GitHub CLI\gh.exe"
if not exist "%GH%" set "GH=gh"

set "SAFE_DIR=%CD:\=/%"
set "GIT_CONFIG_COUNT=1"
set "GIT_CONFIG_KEY_0=safe.directory"
set "GIT_CONFIG_VALUE_0=%SAFE_DIR%"

echo Creating a private GitHub repository: astra-nutrition-os
git init -b main
git add .
git commit -m "Initial Astra Nutrition OS release"
"%GH%" repo create astra-nutrition-os --private --source . --remote origin --push --description "Local nutrition and workout tracker with SQLite, Excel and a web interface"

if errorlevel 1 (
  echo.
  echo Publication was not completed. Check the message above.
) else (
  echo.
  echo Done. Opening the repository in your browser...
  "%GH%" repo view --web
)

echo.
pause
