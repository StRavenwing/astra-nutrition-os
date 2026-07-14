@echo off
cd /d "%~dp0"
start "Astra Nutrition OS" http://127.0.0.1:8787
python server.py
