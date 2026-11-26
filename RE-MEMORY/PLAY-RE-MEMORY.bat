@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>nul
if errorlevel 1 (
  echo Python 3 is required. Install it from https://www.python.org/downloads/
  pause
  exit /b 1
)
start "RE-MEMORY server" /min py -m http.server 8000
timeout /t 2 /nobreak >nul
start "" http://localhost:8000
echo RE-MEMORY is running at http://localhost:8000
echo Keep this window open while playing. Press Ctrl+C in the server window to stop.
pause
