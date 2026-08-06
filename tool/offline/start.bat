@echo off
REM ============================================================
REM  PerfusionCalc - offline start for Windows
REM
REM  A Flutter web app cannot be opened by double-clicking index.html:
REM  the browser blocks module loading over file://. A small local web
REM  server is therefore started - on this machine only, with no
REM  internet connection.
REM
REM  The order is deliberate:
REM   1. caddy.exe - fast and reliable
REM   2. PowerShell - in case foreign .exe files are blocked
REM      (frequently the case on hospital PCs)
REM   3. Python - if it happens to be installed
REM
REM  IMPORTANT: every option is probed BEFORE starting, not merely
REM  checked for existence. caddy.exe is always in the package - if it
REM  is blocked by AppLocker or SmartScreen, execution has to fall
REM  through to the next option. Otherwise the fallback fails in
REM  precisely the case it was built for.
REM ============================================================

setlocal EnableExtensions

REM Self-invocation for the delayed browser launch (see below).
if /i "%~1"=="--open" (
    timeout /t 2 /nobreak >nul 2>&1
    start "" "http://localhost:%~2"
    exit /b
)

cd /d "%~dp0"
set PORT=8080

echo.
echo   PerfusionCalc - lokaler Start
echo   ------------------------------
echo.

REM Find a free port in case 8080 is taken
for %%P in (8080 8081 8082 8090) do (
    netstat -ano | findstr /r /c:":%%P .*LISTENING" >nul 2>&1
    if errorlevel 1 (
        set PORT=%%P
        goto :found
    )
)
echo   Hinweis: 8080-8090 wirken belegt - Versuch trotzdem auf %PORT%.
:found
echo   Adresse: http://localhost:%PORT%
echo.

REM ---------- 1. caddy.exe ----------
if exist "caddy.exe" (
    REM Start probe: 'caddy version' returns immediately. A test AFTER
    REM starting the server would not work - 'caddy file-server' runs in
    REM the foreground until the window is closed.
    caddy.exe version >nul 2>&1
    if not errorlevel 1 (
        echo   Server: caddy.exe
        echo   Zum Beenden dieses Fenster schliessen.
        echo.
        call :openbrowser
        caddy.exe file-server --root web --listen :%PORT%
        goto :eof
    )
    echo   caddy.exe laesst sich nicht ausfuehren ^(Richtlinie?^) - weiche aus.
    echo.
)

REM ---------- 2. PowerShell ----------
if exist "serve.ps1" (
    powershell -NoProfile -Command "exit 0" >nul 2>&1
    if not errorlevel 1 (
        echo   Server: PowerShell
        echo   Zum Beenden dieses Fenster schliessen.
        echo.
        call :openbrowser
        powershell -NoProfile -ExecutionPolicy Bypass -File "serve.ps1" -Port %PORT% -Root "web"
        goto :eof
    )
    echo   PowerShell ist nicht verfuegbar - weiche aus.
    echo.
)

REM ---------- 3. Python ----------
REM 'where python' is not enough: Windows ships a Store placeholder that
REM merely opens the Microsoft Store when invoked. An actual program run
REM is the reliable test.
python -c "pass" >nul 2>&1
if not errorlevel 1 (
    echo   Server: Python
    echo   Zum Beenden dieses Fenster schliessen.
    echo.
    call :openbrowser
    cd web
    python -m http.server %PORT%
    goto :eof
)

py -3 -c "pass" >nul 2>&1
if not errorlevel 1 (
    echo   Server: Python ^(py -3^)
    echo   Zum Beenden dieses Fenster schliessen.
    echo.
    call :openbrowser
    cd web
    py -3 -m http.server %PORT%
    goto :eof
)

echo   FEHLER: Kein Webserver konnte gestartet werden.
echo.
echo   Gefunden wurde nichts Lauffaehiges: caddy.exe ist gesperrt oder
echo   fehlt, PowerShell ist blockiert, Python ist nicht installiert.
echo   Bitte LIESMICH.txt lesen oder die IT-Abteilung fragen.
echo.
pause
goto :eof

REM ------------------------------------------------------------
REM  Open the browser only after the server has been chosen, and with
REM  a delay.
REM
REM  'start' used to sit right at the top - the tab was open before the
REM  server had bound and showed "connection refused". When no server
REM  started at all, the dead tab was even there before the error
REM  message appeared in the window.
REM
REM  The self-invocation with --open solves this without nesting
REM  quotation marks: a second, minimised instance waits two seconds
REM  and then opens the address.
REM ------------------------------------------------------------
:openbrowser
start "" /min "%~f0" --open %PORT%
exit /b
