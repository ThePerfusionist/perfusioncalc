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
REM
REM  WICHTIG: Jede Variante wird VOR dem Start geprueft, nicht nur
REM  auf Vorhandensein. caddy.exe liegt immer im Paket - ist sie
REM  durch AppLocker oder SmartScreen gesperrt, muss die Ausfuehrung
REM  zur naechsten Variante durchfallen. Sonst greift der Fallback
REM  ausgerechnet in dem Fall nicht, fuer den er gebaut wurde.
REM ============================================================

setlocal EnableExtensions

REM Selbstaufruf zum verzoegerten Oeffnen des Browsers (siehe unten).
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

REM Freien Port suchen, falls 8080 belegt ist
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
    REM Startprobe: 'caddy version' kehrt sofort zurueck. Ein Test NACH
    REM dem Serverstart ginge nicht - 'caddy file-server' laeuft bis zum
    REM Schliessen des Fensters im Vordergrund.
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
REM 'where python' genuegt nicht: Windows liefert einen Store-Platzhalter
REM mit, der bei Aufruf nur den Microsoft Store oeffnet. Ein echter
REM Programmlauf ist der verlaessliche Test.
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
REM  Browser erst nach der Server-Auswahl oeffnen, und verzoegert.
REM
REM  Frueher stand 'start' ganz oben - der Tab war offen, bevor der
REM  Server gebunden hatte, und zeigte "Verbindung abgelehnt". Wenn
REM  gar kein Server startete, stand der tote Tab sogar da, bevor die
REM  Fehlermeldung im Fenster erschien.
REM
REM  Der Selbstaufruf mit --open loest das ohne Verschachtelung von
REM  Anfuehrungszeichen: eine zweite, minimierte Instanz wartet zwei
REM  Sekunden und oeffnet dann die Adresse.
REM ------------------------------------------------------------
:openbrowser
start "" /min "%~f0" --open %PORT%
exit /b
