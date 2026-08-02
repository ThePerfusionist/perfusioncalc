<#
    Gegenprobe fuer serve.ps1 — Pfad-Traversal und Grundverhalten
    =============================================================

    Startet serve.ps1 auf einem freien Port, feuert eine Reihe von Anfragen
    dagegen und vergleicht die Statuscodes. Ersetzt die manuelle Pruefung,
    die bisher als Kommentar im Kopf von serve.ps1 stand.

    Hintergrund: Bis v0.4.9 pruefte serve.ps1 mit Join-Path + StartsWith, ob
    eine Anfrage den Wurzelordner verlaesst. Join-Path normalisiert '..'
    NICHT — der zusammengesetzte String beginnt mit dem Wurzelpfad, besteht
    die Pruefung also, und ReadAllBytes loest die '..' anschliessend auf.
    Beliebiger Dateilesezugriff mit den Rechten des angemeldeten Benutzers.

    Die prozentkodierten Varianten sind die wichtigeren: ein Browser
    kollabiert '..' in einer URL, bevor er sendet; '%2e%2e%2f' ueberlebt und
    wird erst von UnescapeDataString im Server aufgeloest.

    AUFRUF (im Ordner tool/offline):
        powershell -NoProfile -ExecutionPolicy Bypass -File .\test-serve.ps1

    Beendet mit Exit-Code 0, wenn alles passt, sonst 1.
#>
param(
    [int]$Port = 8137   # bewusst abseits der ueblichen 8080er
)

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

$failures = 0
$checks = 0

# Der Marker steht in der Datei ausserhalb des Wurzelordners. Er ist das
# eigentliche Pruefkriterium - siehe Assert-NoLeak.
$script:SecretMarker = "DIESE-DATEI-DARF-NIE-AUSGELIEFERT-WERDEN"

function Invoke-Probe {
    param([string]$Path)
    $url = "http://localhost:$Port$Path"
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5 `
                                  -MaximumRedirection 0
        return @{ Status = [int]$resp.StatusCode; Body = [string]$resp.Content }
    } catch {
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
            $body = ""
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $body = (New-Object System.IO.StreamReader($stream)).ReadToEnd()
            } catch { }
            return @{ Status = $status; Body = $body }
        }
        return @{ Status = -1; Body = "" }
    }
}

function Assert-Status {
    param([string]$Path, [int[]]$Expected, [string]$Why)
    $script:checks++
    $r = Invoke-Probe $Path
    if ($Expected -contains $r.Status) {
        Write-Host ("  [ok]   {0,-52} -> {1}" -f $Path, $r.Status)
    } else {
        Write-Host ("  [FEHL] {0,-52} -> {1}, erwartet {2}" -f $Path, $r.Status, ($Expected -join '/')) -ForegroundColor Red
        Write-Host ("         {0}" -f $Why) -ForegroundColor Red
        $script:failures++
    }
}

<#
    Pruefkriterium fuer Traversal-Versuche.

    NICHT auf 403 allein pruefen - das waere zu eng und war in der ersten
    Fassung dieses Tests falsch. Grund: Invoke-WebRequest (und auf dem Weg
    dorthin auch http.sys) normalisiert '..' in einer URL, BEVOR die Anfrage
    den Server erreicht. Aus '/../geheim.txt' wird '/geheim.txt', und darauf
    antwortet der Server voellig korrekt mit 404 - er hat nie einen Traversal
    gesehen. Ein erwartetes 403 schlaegt dann fehl, ohne dass irgendetwas
    kaputt waere.

    Genau deshalb sind die prozentkodierten Varianten die interessanten:
    '%2e%2e%2f' ueberlebt jede Normalisierung und wird erst im Server durch
    UnescapeDataString aufgeloest - dort, wo Get-SafePath greift.

    Das eigentliche Kriterium ist inhaltlich: Der Inhalt der Datei ausserhalb
    des Wurzelordners darf NIE in der Antwort auftauchen. Status 403 (Server
    hat abgelehnt) und 404 (Anfrage kam normalisiert an) sind beide in
    Ordnung; 200 mit dem Marker im Rumpf ist der Befund.
#>
function Assert-NoLeak {
    param([string]$Path, [string]$Why)
    $script:checks++
    $r = Invoke-Probe $Path
    $leaked = $r.Body -and ($r.Body -like "*$script:SecretMarker*")
    if ($leaked) {
        Write-Host ("  [FEHL] {0,-52} -> {1} MIT DATEIINHALT" -f $Path, $r.Status) -ForegroundColor Red
        Write-Host ("         {0} - Datei ausserhalb des Wurzelordners ausgeliefert!" -f $Why) -ForegroundColor Red
        $script:failures++
    } elseif ($r.Status -eq 200) {
        Write-Host ("  [FEHL] {0,-52} -> 200" -f $Path) -ForegroundColor Red
        Write-Host ("         {0} - unerwartet erfolgreich" -f $Why) -ForegroundColor Red
        $script:failures++
    } elseif ($r.Status -eq 403) {
        Write-Host ("  [ok]   {0,-52} -> 403 abgelehnt" -f $Path)
    } elseif ($r.Status -eq 404) {
        Write-Host ("  [ok]   {0,-52} -> 404 (Client normalisierte den Pfad)" -f $Path)
    } else {
        Write-Host ("  [FEHL] {0,-52} -> {1} unerwartet" -f $Path, $r.Status) -ForegroundColor Red
        $script:failures++
    }
}

<#
    Rohe Anfrage ueber einen TCP-Socket, an jeder Client-Normalisierung
    vorbei. Nur so laesst sich pruefen, was ein feindlicher Client
    tatsaechlich schicken wuerde. http.sys kanonisiert unter Umstaenden
    trotzdem noch - auch das ist ein bestandener Fall, solange der Marker
    nicht im Rumpf steht.
#>
function Assert-NoLeakRaw {
    param([string]$RawPath, [string]$Why)
    $script:checks++
    try {
        $client = New-Object System.Net.Sockets.TcpClient("127.0.0.1", $Port)
        $stream = $client.GetStream()
        $req = "GET $RawPath HTTP/1.1`r`nHost: localhost:$Port`r`nConnection: close`r`n`r`n"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($req)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
        $reader = New-Object System.IO.StreamReader($stream)
        $response = $reader.ReadToEnd()
        $client.Close()
    } catch {
        Write-Host ("  [warn] {0,-52} -> Verbindung fehlgeschlagen, uebersprungen" -f $RawPath) -ForegroundColor Yellow
        return
    }
    $statusLine = ($response -split "`r`n")[0]
    if ($response -like "*$script:SecretMarker*") {
        Write-Host ("  [FEHL] {0,-52} -> {1} MIT DATEIINHALT" -f $RawPath, $statusLine) -ForegroundColor Red
        Write-Host ("         {0} - roh gesendet, Datei ausgeliefert!" -f $Why) -ForegroundColor Red
        $script:failures++
    } else {
        Write-Host ("  [ok]   {0,-52} -> {1}" -f $RawPath, $statusLine)
    }
}

# ── Testumgebung aufbauen ────────────────────────────────────────────────
# Eigener Wurzelordner statt des echten web\, damit der Test auch ohne
# gebautes Bundle laeuft. Die Zieldatei des Traversals wird ABSICHTLICH
# angelegt: sonst wuerde ein 404 wie ein bestandener Test aussehen, obwohl
# der Server bereitwillig hinausgereicht haette.
$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("pcalc-servetest-" + [guid]::NewGuid().ToString("N"))
$root = Join-Path $sandbox "web"
$outside = Join-Path $sandbox "geheim.txt"
$sibling = Join-Path $sandbox "webbackup"

New-Item -ItemType Directory -Path $root -Force | Out-Null
New-Item -ItemType Directory -Path $sibling -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root "assets") -Force | Out-Null
Set-Content -LiteralPath (Join-Path $root "index.html") -Value "<html><body>ok</body></html>"
Set-Content -LiteralPath (Join-Path $root "main.dart.js") -Value "console.log(1)"
Set-Content -LiteralPath (Join-Path $root "assets\datei.txt") -Value "asset"
Set-Content -LiteralPath $outside -Value "DIESE-DATEI-DARF-NIE-AUSGELIEFERT-WERDEN"
Set-Content -LiteralPath (Join-Path $sibling "nachbar.txt") -Value "DIESE-DATEI-DARF-NIE-AUSGELIEFERT-WERDEN"

Write-Host ""
Write-Host "  Sandbox: $sandbox"
Write-Host "  Server:  http://localhost:$Port/"
Write-Host ""

$job = Start-Job -ScriptBlock {
    param($script, $port, $root)
    & $script -Port $port -Root $root
} -ArgumentList (Join-Path $PSScriptRoot "serve.ps1"), $Port, $root

try {
    # Auf den Listener warten statt blind zu schlafen.
    $ready = $false
    foreach ($i in 1..30) {
        Start-Sleep -Milliseconds 200
        try {
            Invoke-WebRequest -Uri "http://localhost:$Port/index.html" `
                              -UseBasicParsing -TimeoutSec 2 | Out-Null
            $ready = $true
            break
        } catch {
            if ($_.Exception.Response) { $ready = $true; break }
        }
    }
    if (-not $ready) {
        Write-Host "  FEHLER: Server ist nicht hochgekommen." -ForegroundColor Red
        Write-Host "  Ausgabe des Serverprozesses:" -ForegroundColor Red
        Receive-Job $job -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "    $_" -ForegroundColor Red
        }
        $failures++
        return
    }

    Write-Host "  Erlaubte Pfade"
    Assert-Status "/"                    @(200) "Wurzel muss index.html liefern"
    Assert-Status "/index.html"          @(200) "vorhandene Datei"
    Assert-Status "/main.dart.js"        @(200) "vorhandene Datei im Wurzelordner"
    Assert-Status "/assets/datei.txt"    @(200) "vorhandene Datei im Unterordner"

    Write-Host ""
    Write-Host "  Pfad-Traversal (Dateiinhalt darf nie erscheinen)"
    Assert-NoLeak "/../geheim.txt"                     "Klartext-Traversal"
    Assert-NoLeak "/%2e%2e%2fgeheim.txt"               "prozentkodiert - ueberlebt die Normalisierung"
    Assert-NoLeak "/%2e%2e/geheim.txt"                 "gemischt kodiert"
    Assert-NoLeak "/..%5cgeheim.txt"                   "kodierter Backslash"
    Assert-NoLeak "/assets/%2e%2e%2f%2e%2e%2fgeheim.txt" "aus einem Unterordner, kodiert"
    Assert-NoLeak "/assets/../../geheim.txt"           "aus einem Unterordner, Klartext"
    Assert-NoLeak "/%2e%2e%2fwebbackup%2fnachbar.txt"  "Nachbarordner mit gleichem Praefix"
    Assert-NoLeak "/../webbackup/nachbar.txt"          "Nachbarordner, Klartext"
    Assert-NoLeak "/%2e%2e%2f%2e%2e%2fWindows/win.ini" "mehrstufig, echtes Systemziel"

    Write-Host ""
    Write-Host "  Roh gesendet, an der Client-Normalisierung vorbei"
    Assert-NoLeakRaw "/../geheim.txt"                  "unnormalisierter Klartext-Traversal"
    Assert-NoLeakRaw "/..%2fgeheim.txt"                "unnormalisiert, teilkodiert"

    Write-Host ""
    Write-Host "  Nicht vorhandene Pfade"
    # Mit Endung: 404. Fuer eine fehlende .js HTML zurueckzugeben erzeugt
    # sonst einen Folgefehler, der wie ein Syntaxfehler aussieht.
    Assert-Status "/gibtesnicht.js"      @(404) "fehlende Datei MIT Endung"
    # Ohne Endung: SPA-Rueckfall auf index.html.
    Assert-Status "/irgendeine/route"    @(200) "SPA-Rueckfall fuer Pfade OHNE Endung"

    Write-Host ""
    if ($failures -eq 0) {
        Write-Host "  $checks Pruefungen, alle bestanden." -ForegroundColor Green
    } else {
        Write-Host "  $checks Pruefungen, $failures FEHLGESCHLAGEN." -ForegroundColor Red
    }
} finally {
    Stop-Job $job -ErrorAction SilentlyContinue | Out-Null
    Remove-Job $job -Force -ErrorAction SilentlyContinue | Out-Null
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

# Kein ternaerer Operator: den gibt es erst ab PowerShell 7, und auf
# Windows-Arbeitsplaetzen ist 5.1 der Normalfall.
if ($failures -eq 0) { exit 0 } else { exit 1 }
