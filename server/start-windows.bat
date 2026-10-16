@echo off
REM From a Fountain: starts the letter book service and the ngrok tunnel.
REM Start Icecast and BUTT first. Settings come from fountain.env next to this file.
cd /d "%~dp0"
if not exist fountain.env (
  echo Copy fountain.env.example to fountain.env and fill it in first.
  pause
  exit /b 1
)
for /f "usebackq eol=# tokens=1,* delims==" %%a in ("fountain.env") do set "%%a=%%b"
start "ngrok" ngrok http --url=%NGROK_DOMAIN% 8787
python fountain.py
pause
