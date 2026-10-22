@echo off
title From a Fountain - launcher
REM One-click start for a set: Icecast, BUTT, ngrok, and the letter book service.
cd /d "%~dp0"

set "PF=%ProgramFiles%"
set "PF86=%ProgramFiles(x86)%"
set "LAD=%LocalAppData%"

if not exist fountain.env goto noenv
for /f "usebackq eol=# tokens=1,* delims==" %%a in ("fountain.env") do set "%%a=%%b"
if not defined NGROK_DOMAIN set "NGROK_DOMAIN=malika-unflaky-loan.ngrok-free.dev"

echo.
echo === 1 of 4   Icecast ===
tasklist /fi "imagename eq icecast.exe" | find /i "icecast.exe" >nul
if not errorlevel 1 goto icedone
set "ICE="
call :findexe ICE "%PF%\Icecast\bin\icecast.exe"
call :findexe ICE "%PF86%\Icecast\bin\icecast.exe"
call :findexe ICE "%PF%\Icecast\icecast.exe"
call :findexe ICE "%PF86%\Icecast\icecast.exe"
call :findexe ICE "C:\Icecast\bin\icecast.exe"
call :findexe ICE "C:\Icecast\icecast.exe"
if not defined ICE goto icemissing
REM icecast.xml sits beside the exe, or one level up when the exe is in bin\
set "ICEDIR="
call :findxml ICEDIR "%PF%\Icecast"
call :findxml ICEDIR "%PF86%\Icecast"
call :findxml ICEDIR "C:\Icecast"
if not defined ICEDIR goto icenoxml
start "Icecast" /D "%ICEDIR%" "%ICE%" -c "%ICEDIR%\icecast.xml"
echo      started - waiting for port 8000
set /a tries=0
:icewait
timeout /t 1 /nobreak >nul
netstat -an | find ":8000" | find "LISTENING" >nul
if not errorlevel 1 goto iceup
set /a tries+=1
if %tries% lss 15 goto icewait
echo      WARNING: port 8000 never opened. Check the Icecast window for an error.
goto icedone
:iceup
echo      listening on port 8000
goto icedone
:icemissing
echo      NOT FOUND. Start Icecast from the Start menu, then run this again.
goto icedone
:icenoxml
echo      Found icecast.exe but not icecast.xml. Start Icecast from the Start menu.
:icedone

echo.
echo === 2 of 4   BUTT  (turntable into Icecast) ===
tasklist /fi "imagename eq butt.exe" | find /i "butt.exe" >nul
if not errorlevel 1 goto buttrunning
set "BUTT="
call :findexe BUTT "%PF%\butt\butt.exe"
call :findexe BUTT "%PF86%\butt\butt.exe"
call :findexe BUTT "%LAD%\Programs\butt\butt.exe"
if not defined BUTT goto buttmissing
start "BUTT" "%BUTT%" -s
echo      started and streaming
goto buttdone
:buttrunning
echo      already running - make sure play is pressed
goto buttdone
:buttmissing
echo      NOT FOUND. Open BUTT yourself and press play.
:buttdone

echo.
echo === 3 of 4   ngrok tunnel ===
tasklist /fi "imagename eq ngrok.exe" | find /i "ngrok.exe" >nul
if not errorlevel 1 goto ngrokdone
start "ngrok" ngrok http --url=%NGROK_DOMAIN% 8787
echo      https://%NGROK_DOMAIN%
goto ngrokafter
:ngrokdone
echo      already running
:ngrokafter

echo.
echo === 4 of 4   Letter book service ===
echo      letter book : http://localhost:8787
echo      docent      : http://localhost:8787/docent
echo      public      : https://%NGROK_DOMAIN%
echo.
echo Closing this window stops the letter book. Icecast, BUTT and ngrok have
echo their own windows and keep running until you close those too.
echo.
py fountain.py
echo.
echo The letter book stopped.
pause
exit /b

:findxml
if defined %1 exit /b
if exist "%~2\icecast.xml" set "%1=%~2"
exit /b

:findexe
if defined %1 exit /b
if exist %2 set "%1=%~2"
exit /b

:noenv
echo Copy fountain.env.example to fountain.env and fill it in first.
pause
exit /b 1
