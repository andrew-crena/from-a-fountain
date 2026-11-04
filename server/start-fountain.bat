@echo off
setlocal
title From a Fountain - launcher
REM One click to go on air:
REM   turntable -> BUTT -> Icecast (8000) -> letter book service (8787) -> ngrok -> andrew-crena.github.io/fountain/
REM Starts whatever isn't running, checks each link in that chain, and opens the
REM Fountain page once the stream is reachable from the internet.
REM Safe to run twice: anything already running is left alone.
cd /d "%~dp0"

set "PF=%ProgramFiles%"
set "PF86=%ProgramFiles(x86)%"
set "LAD=%LocalAppData%"
set "SITE=https://andrew-crena.github.io/fountain/"
set "MOUNT=stream.aac"
set "PORT=8787"

if exist "%~dp0fountain.py" goto placeok
echo This launcher has to live in the from-a-fountain\server folder, next to
echo fountain.py and fountain.env. Right now it is in:
echo      %~dp0
echo.
echo Move it into the server folder (replace the old start-fountain.bat there),
echo then use your desktop shortcut as before.
pause
exit /b 1
:placeok

if exist fountain.env goto loadenv
echo NOTE: no fountain.env yet. The stream will still go out, but record
echo recognition and the docent page need it. See SETUP-WINDOWS.md, step 3.
goto envdone
:loadenv
for /f "usebackq eol=# tokens=1,* delims==" %%a in ("fountain.env") do set "%%a=%%b"
:envdone
if not defined NGROK_DOMAIN set "NGROK_DOMAIN=malika-unflaky-loan.ngrok-free.dev"
if defined FOUNTAIN_PORT set "PORT=%FOUNTAIN_PORT%"

where curl >nul 2>nul
if errorlevel 1 set "NOCURL=1"

REM ===================================================================
echo.
echo === 1 of 5   Icecast  (the stream server) ===
call :listening 8000
if not errorlevel 1 goto iceup
set "ICE="
call :findexe ICE "%PF%\Icecast\bin\icecast.exe"
call :findexe ICE "%PF86%\Icecast\bin\icecast.exe"
call :findexe ICE "%PF%\Icecast\icecast.exe"
call :findexe ICE "%PF86%\Icecast\icecast.exe"
call :findexe ICE "C:\Icecast\bin\icecast.exe"
call :findexe ICE "C:\Icecast\icecast.exe"
if not defined ICE goto icemissing
REM The install folder holds web\ and admin\, which icecast.xml refers to with
REM relative paths, so Icecast always runs from there.
set "ICEDIR="
call :findroot ICEDIR "%PF%\Icecast"
call :findroot ICEDIR "%PF86%\Icecast"
call :findroot ICEDIR "C:\Icecast"
REM The settings file: ICECAST_XML in fountain.env if set, else the install
REM folder, else Documents (where Notepad saves it when Program Files is locked).
set "XML="
if defined ICECAST_XML call :findfile XML "%ICECAST_XML%"
call :findfile XML "%ICEDIR%\icecast.xml"
call :findfile XML "%ICEDIR%\etc\icecast.xml"
call :findfile XML "%OneDriveCommercial%\Documents\icecast.xml"
call :findfile XML "%OneDrive%\Documents\icecast.xml"
call :findfile XML "%USERPROFILE%\OneDrive\Documents\icecast.xml"
call :findfile XML "%USERPROFILE%\Documents\icecast.xml"
if not defined XML goto icenoxml
echo      settings: %XML%
pushd "%ICEDIR%"
REM Settings in the install folder: start it the way the Start-menu shortcut does.
if /i "%XML%"=="%ICEDIR%\icecast.xml" if exist "%ICEDIR%\icecast.bat" goto icebat
start "Icecast" /min "%ICE%" -c "%XML%"
goto icelaunched
:icebat
start "Icecast" /min "%ICEDIR%\icecast.bat"
:icelaunched
popd
echo      starting...
call :waitport 8000 15
if errorlevel 1 goto icefail
:iceup
echo      OK  listening on port 8000
goto icedone
:icemissing
echo      NOT FOUND. Start Icecast from the Start menu, then run this again.
goto stop
:icenoxml
echo      Found Icecast but not its settings file, icecast.xml.
echo      Add a line to fountain.env saying where it is, for example:
echo        ICECAST_XML=C:\Users\you\Documents\icecast.xml
goto stop
:icefail
echo      PROBLEM: port 8000 never opened. Look at the Icecast window for an error
echo      (a "Permission denied" on the log folder is the usual one: SETUP-WINDOWS.md, step 1.4).
goto stop
:icedone

REM ===================================================================
echo.
echo === 2 of 5   BUTT  (turntable into Icecast) ===
set "BUTT="
call :findexe BUTT "%PF%\butt\butt.exe"
call :findexe BUTT "%PF86%\butt\butt.exe"
call :findexe BUTT "%LAD%\butt\butt.exe"
call :findexe BUTT "%LAD%\Programs\butt\butt.exe"
tasklist /fi "imagename eq butt.exe" | find /i "butt.exe" >nul
if not errorlevel 1 goto buttopen
if not defined BUTT goto buttmissing
REM Opened without -s: on its own, -s makes BUTT quit. "Start streaming after launch" in BUTT's settings starts it.
start "BUTT" "%BUTT%"
echo      opened
goto buttwait
:buttopen
echo      already open
goto buttwait
:buttmissing
echo      NOT FOUND where expected. Open BUTT yourself; this window will wait for it.
:buttwait
if defined NOCURL goto buttnocheck
echo      waiting for the /%MOUNT% stream to reach Icecast...
call :waitmount 12
if not errorlevel 1 goto buttlive
REM Not streaming yet. A running BUTT accepts "butt -s" as "start streaming" (BUTT 0.1.30 and later).
if defined BUTT start "" /b "%BUTT%" -s
call :waitmount 8
if not errorlevel 1 goto buttlive
echo.
echo      ^>^>^> Press PLAY in the BUTT window now. ^<^<^<
echo      (Waiting up to 2 minutes. If BUTT shows a connection error, check the
echo       source password and the mountpoint "%MOUNT%" in its server settings.)
call :waitmount 120
if not errorlevel 1 goto buttlive
echo      PROBLEM: Icecast never received /%MOUNT%. Check BUTT, then run this again.
goto stop
:buttnocheck
echo      Make sure play is pressed in BUTT.
goto buttdone
:buttlive
echo      OK  /%MOUNT% is live in Icecast
:buttdone

REM ===================================================================
echo.
echo === 3 of 5   Letter book service  (passes the stream through) ===
call :listening %PORT%
if not errorlevel 1 goto bookup
where py >nul 2>nul
if errorlevel 1 goto nopy
start "Letter book" /min cmd /k py fountain.py
echo      starting...
call :waitport %PORT% 20
if errorlevel 1 goto bookfail
:bookup
echo      OK  http://localhost:%PORT%
goto bookdone
:nopy
echo      PROBLEM: Python isn't installed (no "py" command). SETUP-WINDOWS.md, step 3.
goto stop
:bookfail
echo      PROBLEM: the service didn't start. Look at the "Letter book" window for the error.
goto stop
:bookdone

REM ===================================================================
echo.
echo === 4 of 5   ngrok  (the public address) ===
tasklist /fi "imagename eq ngrok.exe" | find /i "ngrok.exe" >nul
if not errorlevel 1 goto ngrokrunning
where ngrok >nul 2>nul
if errorlevel 1 goto nongrok
start "ngrok" /min ngrok http --domain=%NGROK_DOMAIN% %PORT%
echo      starting...
goto ngrokwait
:ngrokrunning
echo      already running
:ngrokwait
if defined NOCURL goto ngrokdone
call :waittunnel 20
if errorlevel 1 goto ngrokfail
echo      OK  https://%NGROK_DOMAIN%
goto ngrokdone
:nongrok
echo      PROBLEM: ngrok isn't installed or isn't on PATH. SETUP-WINDOWS.md, step 4.
goto stop
:ngrokfail
echo      PROBLEM: the tunnel for %NGROK_DOMAIN% didn't come up. Look at the ngrok window.
echo      "ERR_NGROK_108" or "already online" means ngrok is running elsewhere with this address (close it);
echo      "authentication failed" means: ngrok config add-authtoken YOUR_TOKEN
goto stop
:ngrokdone

REM ===================================================================
echo.
echo === 5 of 5   On air check  (from the internet, as listeners hear it) ===
if defined NOCURL goto opensite
set "CODE="
for /f %%c in ('curl -s -o nul -m 6 -H "ngrok-skip-browser-warning: 1" -w "%%{http_code}" "https://%NGROK_DOMAIN%/%MOUNT%"') do set "CODE=%%c"
if "%CODE%"=="200" goto onair
echo      PROBLEM: https://%NGROK_DOMAIN%/%MOUNT% answered "%CODE%" instead of 200.
echo      Opening the page anyway so you can try it.
goto opensite
:onair
echo      OK  the stream plays at https://%NGROK_DOMAIN%/%MOUNT%

:opensite
echo.
echo Opening %SITE%
start "" "%SITE%"
echo.
echo ============================================================
echo   ON AIR.  Listeners: %SITE%
echo   Letter book: https://andrew-crena.github.io/letters/
echo   Docent:      http://localhost:%PORT%/docent
echo.
echo   Icecast, BUTT, ngrok and the letter book each run in their
echo   own window (minimised). To go off air, run stop-fountain.bat.
echo ============================================================
echo.
pause
exit /b 0

:stop
echo.
echo Stopped here. Fix the step above, then run this again; whatever is
echo already running will be left alone.
pause
exit /b 1

REM ======================= helpers =======================
:findroot
REM an Icecast install folder: has icecast.exe directly or in bin\
if defined %1 exit /b
if exist "%~2\bin\icecast.exe" set "%1=%~2"
if exist "%~2\icecast.exe" set "%1=%~2"
exit /b

:findfile
if defined %1 exit /b
if exist "%~2" set "%1=%~2"
exit /b

:findexe
if defined %1 exit /b
if exist %2 set "%1=%~2"
exit /b

:listening
REM errorlevel 0 if something is listening on port %1
netstat -an | find ":%1 " | find "LISTENING" >nul
exit /b

:waitport
REM wait up to %2 seconds for port %1
set /a _t=0
:waitport_loop
call :listening %1
if not errorlevel 1 exit /b 0
set /a _t+=1
if %_t% geq %2 exit /b 1
timeout /t 1 /nobreak >nul
goto waitport_loop

:waitmount
REM wait up to %1 seconds for Icecast to list the mount
set /a _t=0
:waitmount_loop
curl -s -m 2 http://localhost:8000/status-json.xsl 2>nul | find /i "/%MOUNT%" >nul
if not errorlevel 1 exit /b 0
set /a _t+=2
if %_t% geq %1 exit /b 1
timeout /t 2 /nobreak >nul
goto waitmount_loop

:waittunnel
REM wait up to %1 seconds for ngrok's local API to report the tunnel
set /a _t=0
:waittunnel_loop
curl -s -m 2 http://127.0.0.1:4040/api/tunnels 2>nul | find /i "%NGROK_DOMAIN%" >nul
if not errorlevel 1 exit /b 0
set /a _t+=1
if %_t% geq %1 exit /b 1
timeout /t 1 /nobreak >nul
goto waittunnel_loop
