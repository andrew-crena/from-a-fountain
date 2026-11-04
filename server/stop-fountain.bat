@echo off
title From a Fountain - off air
REM Goes off air: stops BUTT, ngrok, the letter book service and Icecast.
REM Letters are saved as they're written, so nothing is lost.
echo Going off air...
taskkill /im butt.exe >nul 2>nul && echo   BUTT stopped
taskkill /im ngrok.exe >nul 2>nul && echo   ngrok stopped
taskkill /fi "WINDOWTITLE eq Letter book*" /t /f >nul 2>nul && echo   letter book stopped
taskkill /im icecast.exe >nul 2>nul && echo   Icecast stopped
echo.
echo Off air.
timeout /t 4 >nul
