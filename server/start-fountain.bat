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
REM BUTT may send AAC (/stream.aac) or MP3 (/stream.mp3); either works. MOUNT becomes whichever is live.
set "PORT=8787"

REM This file can sit anywhere (the Desktop is fine). It looks for the letter
REM book (from-a-fountain\server) next to itself, then in the usual places.
set "SERVER="
call :finddir SERVER "%~dp0"
call :finddir SERVER "%~dp0server"
call :finddir SERVER "%USERPROFILE%\from-a-fountain\server"
call :finddir SERVER "%USERPROFILE%\Documents\from-a-fountain\server"
call :finddir SERVER "%USERPROFILE%\Documents\GitHub\from-a-fountain\server"
call :finddir SERVER "%OneDriveCommercial%\Documents\from-a-fountain\server"
call :finddir SERVER "%OneDriveCommercial%\Documents\GitHub\from-a-fountain\server"
call :finddir SERVER "%OneDriveCommercial%\Desktop\from-a-fountain\server"
call :finddir SERVER "%OneDrive%\Documents\from-a-fountain\server"
call :finddir SERVER "%OneDrive%\Desktop\from-a-fountain\server"
call :finddir SERVER "%USERPROFILE%\Desktop\from-a-fountain\server"
call :finddir SERVER "%USERPROFILE%\Downloads\from-a-fountain-main\server"
call :finddir SERVER "%USERPROFILE%\Downloads\from-a-fountain\server"
if defined SERVER cd /d "%SERVER%"
if not defined SERVER goto envdone

if exist fountain.env goto loadenv
echo NOTE: no fountain.env in %SERVER%. The stream will still go out, but
echo record recognition and the docent page need it. See SETUP-WINDOWS.md, step 3.
goto envdone
:loadenv
for /f "usebackq eol=# tokens=1,* delims==" %%a in ("fountain.env") do set "%%a=%%b"
:envdone
REM The website plays NGROK_DOMAIN first, then NGROK_ALT_DOMAIN (your earlier address).
if not defined NGROK_DOMAIN set "NGROK_DOMAIN=malika-unflaky-loan.ngrok-free.dev"
if not defined NGROK_ALT_DOMAIN set "NGROK_ALT_DOMAIN=cuddly-doe-adversely.ngrok-free.app"
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
set "BUTTLNK="
call :findexe BUTTLNK "%OneDriveCommercial%\Desktop\butt.lnk"
call :findexe BUTTLNK "%OneDrive%\Desktop\butt.lnk"
call :findexe BUTTLNK "%USERPROFILE%\Desktop\butt.lnk"
call :findexe BUTTLNK "%PUBLIC%\Desktop\butt.lnk"
tasklist /fi "imagename eq butt.exe" | find /i "butt.exe" >nul
if not errorlevel 1 goto buttopen
if defined BUTT goto buttexe
if defined BUTTLNK goto buttlnk
goto buttmissing
:buttexe
REM Opened without -s: on its own, -s makes BUTT quit. "Start streaming after launch" in BUTT's settings starts it.
start "BUTT" "%BUTT%"
echo      opened
goto buttwait
:buttlnk
start "" "%BUTTLNK%"
echo      opened (from your desktop shortcut)
goto buttwait
:buttopen
echo      already open
goto buttwait
:buttmissing
echo      NOT FOUND where expected. Open BUTT yourself; this window will wait for it.
:buttwait
if defined NOCURL goto buttnocheck
echo      waiting for BUTT's stream (/stream.aac or /stream.mp3) to reach Icecast...
call :waitmount 12
if not errorlevel 1 goto buttlive
REM Not streaming yet. A running BUTT accepts "butt -s" as "start streaming" (BUTT 0.1.30 and later).
if defined BUTT start "" /b "%BUTT%" -s
call :waitmount 8
if not errorlevel 1 goto buttlive
echo.
echo      ^>^>^> Press PLAY in the BUTT window now. ^<^<^<
echo      (Waiting up to 2 minutes. If BUTT shows a connection error, check the
echo       source password, and set the mountpoint to "stream.mp3" in its server settings.)
call :waitmount 120
if not errorlevel 1 goto buttlive
echo      PROBLEM: Icecast never received /stream.aac or /stream.mp3. In BUTT: Settings,
echo      Main, Server, Edit: the mountpoint must be stream.mp3 (or stream.aac).
goto stop
:buttnocheck
echo      Make sure play is pressed in BUTT.
goto buttdone
:buttlive
echo      OK  /%MOUNT% is live in Icecast
:buttdone

REM ===================================================================
echo.
echo === 3 of 5   Letter book service  (now playing + letter book) ===
set "TPORT=%PORT%"
call :listening %PORT%
if not errorlevel 1 goto bookup
if not defined SERVER goto nobook
where py >nul 2>nul
if errorlevel 1 goto nopy
start "Letter book" /min cmd /k py fountain.py
echo      starting...
call :waitport %PORT% 20
if errorlevel 1 goto bookfail
:bookup
echo      OK  http://localhost:%PORT%
goto bookdone
:nobook
echo      Not set up on this computer (no from-a-fountain\server folder found).
goto streamonly
:nopy
echo      Python isn't installed (no "py" command), so the letter book is skipped.
goto streamonly
:bookfail
echo      The service didn't start; see the "Letter book" window. Skipping it.
:streamonly
echo      Streaming straight from Icecast instead. The music still reaches the site;
echo      "now playing" and the letter book are off until the service runs.
set "TPORT=8000"
:bookdone

REM ===================================================================
echo.
echo === 4 of 5   ngrok  (the public address) ===
set "NGROKEXE="
for /f "delims=" %%n in ('where ngrok 2^>nul') do if not defined NGROKEXE set "NGROKEXE=%%n"
call :findexe NGROKEXE "%LAD%\Microsoft\WindowsApps\ngrok.exe"
if not defined NGROKEXE goto nongrok
set "ACTIVE="
tasklist /fi "imagename eq ngrok.exe" | find /i "ngrok.exe" >nul
if errorlevel 1 goto ngrokstart
echo      already running
if defined NOCURL set "ACTIVE=%NGROK_DOMAIN%"
if defined NOCURL goto ngrokdone
call :waittunnel %NGROK_DOMAIN% 3
if not errorlevel 1 set "ACTIVE=%NGROK_DOMAIN%"
if defined ACTIVE goto ngrokok
call :waittunnel %NGROK_ALT_DOMAIN% 3
if not errorlevel 1 set "ACTIVE=%NGROK_ALT_DOMAIN%"
if defined ACTIVE goto ngrokok
echo      ...but not on either address. Restarting it.
taskkill /im ngrok.exe /f >nul 2>nul
:ngrokstart
call :tunnel %NGROK_DOMAIN%
if defined NOCURL set "ACTIVE=%NGROK_DOMAIN%"
if defined NOCURL goto ngrokdone
call :waittunnel %NGROK_DOMAIN% 15
if not errorlevel 1 set "ACTIVE=%NGROK_DOMAIN%"
if defined ACTIVE goto ngrokok
echo      %NGROK_DOMAIN% didn't come up; trying your other address...
taskkill /im ngrok.exe /f >nul 2>nul
call :tunnel %NGROK_ALT_DOMAIN%
call :waittunnel %NGROK_ALT_DOMAIN% 15
if not errorlevel 1 set "ACTIVE=%NGROK_ALT_DOMAIN%"
if defined ACTIVE goto ngrokok
goto ngrokfail
:ngrokok
echo      OK  https://%ACTIVE%
goto ngrokdone
:nongrok
echo      PROBLEM: ngrok isn't installed. SETUP-WINDOWS.md, step 4.
goto stop
:ngrokfail
echo      PROBLEM: neither ngrok address came up. Look at the "ngrok" window:
echo      "authentication failed" means:  ngrok config add-authtoken YOUR_TOKEN
echo      "already online" means ngrok is running on another computer with this address.
goto stop
:ngrokdone

REM ===================================================================
echo.
echo === 5 of 5   On air check  (from the internet, as listeners hear it) ===
if defined NOCURL goto opensite
set "CODE="
for /f %%c in ('curl -s -o nul -m 6 -H "ngrok-skip-browser-warning: 1" -w "%%{http_code}" "https://%ACTIVE%/%MOUNT%"') do set "CODE=%%c"
if "%CODE%"=="200" goto onair
echo      PROBLEM: https://%ACTIVE%/%MOUNT% answered "%CODE%" instead of 200.
echo      Opening the page anyway so you can try it.
goto opensite
:onair
echo      OK  the stream plays at https://%ACTIVE%/%MOUNT%

:opensite
echo.
echo Opening %SITE%
start "" "%SITE%"
echo.
echo ============================================================
echo   ON AIR at https://%ACTIVE%
echo   Listeners: %SITE%
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

:finddir
REM a from-a-fountain\server folder: has fountain.py
if defined %1 exit /b
if exist "%~2\fountain.py" set "%1=%~f2"
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
curl -s -m 2 http://localhost:8000/status-json.xsl 2>nul | find /i "/stream.aac" >nul
if not errorlevel 1 set "MOUNT=stream.aac"
if not errorlevel 1 exit /b 0
curl -s -m 2 http://localhost:8000/status-json.xsl 2>nul | find /i "/stream.mp3" >nul
if not errorlevel 1 set "MOUNT=stream.mp3"
if not errorlevel 1 exit /b 0
set /a _t+=2
if %_t% geq %1 exit /b 1
timeout /t 2 /nobreak >nul
goto waitmount_loop

:tunnel
REM start ngrok for domain %1 in its own window, kept open so errors stay readable
echo      starting https://%1 ...
start "ngrok" /min cmd /k ""%NGROKEXE%" http --domain=%1 %TPORT%"
exit /b

:waittunnel
REM wait up to %2 seconds for ngrok's local API to report a tunnel on domain %1
set /a _t=0
:waittunnel_loop
curl -s -m 2 http://127.0.0.1:4040/api/tunnels 2>nul | find /i "%1" >nul
if not errorlevel 1 exit /b 0
set /a _t+=1
if %_t% geq %2 exit /b 1
timeout /t 1 /nobreak >nul
goto waittunnel_loop
