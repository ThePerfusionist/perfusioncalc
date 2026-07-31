@echo off
REM ============================================================
REM  PerfusionCalc - Offline-Start fuer Windows
REM
REM  Eine Flutter-Webapp laesst sich nicht per Doppelklick auf
REM  index.html oeffnen: der Browser blockiert das Nachladen der
REM  Module ueber file://. Es wird daher ein kleiner lokaler
REM  Webserver gestartet - ausschliesslich auf diesem Rechner,
REM  ohne Internetverbindung.
REM
REM  Reihenfolge bewusst so gewaehlt:
REM   1. caddy.exe - schnell und zuverlaessig
REM   2. PowerShell - falls fremde .exe-Dateien gesperrt sind
REM      (auf Klinik-PCs haeufig der Fall)
REM   3. Python - falls ohnehin installiert
REM ============================================================

setlocal
cd /d "%~dp0"
set PORT=8080

echo.
echo   PerfusionCalc - lokaler Start
echo   ------------------------------
echo.

REM Freien Port suchen, falls 8080 belegt ist
for %%P in (8080 8081 8082 8090) do (
    netstat -ano | findstr /r /c:":%%P .*LISTENING" >nul 2>&1
    if errorlevel 1 (
        set PORT=%%P
        goto :found
    )
)
:found
echo   Adresse: http://localhost:%PORT%
echo.

start "" "http://localhost:%PORT%"

if exist "caddy.exe" (
    echo   Server: caddy.exe
    echo   Zum Beenden dieses Fenster schliessen.
    echo.
    caddy.exe file-server --root web --listen :%PORT%
    goto :eof
)

if exist "serve.ps1" (
    echo   Server: PowerShell
    echo   Zum Beenden dieses Fenster schliessen.
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "serve.ps1" -Port %PORT% -Root "web"
    goto :eof
)

where python >nul 2>&1
if %errorlevel%==0 (
    echo   Server: Python
    echo   Zum Beenden dieses Fenster schliessen.
    echo.
    cd web
    python -m http.server %PORT%
    goto :eof
)

echo   FEHLER: Kein Webserver gefunden.
echo   Es wird caddy.exe, serve.ps1 oder Python benoetigt.
echo.
pause
