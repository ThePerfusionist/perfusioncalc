<#
    Minimaler statischer Webserver fuer PerfusionCalc.

    Zweck: Fallback fuer Rechner, auf denen das Ausfuehren fremder
    .exe-Dateien durch Richtlinien gesperrt ist - PowerShell ist auf
    jedem Windows-System vorhanden.

    Bindet bewusst nur an localhost. Damit ist keine Administrator-
    Berechtigung noetig (fuer 'http://+:port/' waere sie es) und der
    Server ist von aussen nicht erreichbar.

    SICHERHEITSHINWEIS FUER DIE PRUEFUNG DURCH DIE KLINIK-IT
    -------------------------------------------------------
    Dieses Skript liefert ausschliesslich Dateien aus dem beim Start
    uebergebenen Ordner aus. Die Pfadpruefung in Get-SafePath loest '..'
    VOR dem Vergleich auf (siehe Kommentar dort) - eine Anfrage wie
    /%2e%2e%2f%2e%2e%2fWindows/win.ini wird mit 403 beantwortet.

    Manuelle Gegenprobe nach jeder Aenderung an Get-SafePath:
      http://localhost:8080/%2e%2e%2f%2e%2e%2fWindows/win.ini   -> 403
      http://localhost:8080/../../Windows/win.ini               -> 403
      http://localhost:8080/index.html                          -> 200
#>
param(
    [int]$Port = 8080,
    [string]$Root = "web"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    Write-Host ""
    Write-Host "  Der Ordner '$Root' wurde nicht gefunden."
    Write-Host "  serve.ps1 muss neben dem Ordner 'web' liegen."
    Write-Host ""
    Read-Host "  Mit Enter beenden"
    exit 1
}
$rootPath = (Resolve-Path -LiteralPath $Root).Path

# Mit abschliessendem Trenner: sonst wuerde ein Nachbarordner 'webbackup'
# den Praefixvergleich bestehen, weil der String mit '...\web' beginnt.
$rootPrefix = $rootPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
              [System.IO.Path]::DirectorySeparatorChar

$mime = @{
    ".html"="text/html; charset=utf-8"; ".htm"="text/html; charset=utf-8"
    ".js"="text/javascript; charset=utf-8"; ".mjs"="text/javascript; charset=utf-8"
    ".css"="text/css; charset=utf-8"; ".json"="application/json; charset=utf-8"
    ".wasm"="application/wasm"; ".png"="image/png"; ".jpg"="image/jpeg"
    ".jpeg"="image/jpeg"; ".gif"="image/gif"; ".svg"="image/svg+xml"
    ".ico"="image/x-icon"; ".webp"="image/webp"; ".ttf"="font/ttf"
    ".otf"="font/otf"; ".woff"="font/woff"; ".woff2"="font/woff2"
    ".txt"="text/plain; charset=utf-8"; ".pdf"="application/pdf"
    ".bin"="application/octet-stream"; ".symbols"="application/octet-stream"
}

<#
    Loest einen angefragten Pfad auf und gibt ihn NUR zurueck, wenn er
    innerhalb von $rootPath liegt. Sonst $null.

    Warum nicht einfach Join-Path + StartsWith: Join-Path normalisiert
    NICHT. Fuer rel = '..\..\Windows\win.ini' entsteht der String
    'C:\PerfusionCalc\web\..\..\Windows\win.ini' - der beginnt mit dem
    Wurzelpfad, besteht den Vergleich also, und ReadAllBytes loest die
    '..' anschliessend auf. GetFullPath loest sie VORHER auf.

    UnescapeDataString ist ebenfalls kritisch: HttpListener liefert den
    Pfad teilweise noch prozentkodiert, %2e%2e%2f wird hier also erst zu
    '../'. Deshalb muss die Pruefung NACH dem Dekodieren stattfinden -
    genau das tut diese Funktion.
#>
function Get-SafePath {
    param([string]$Relative)

    if ([string]::IsNullOrWhiteSpace($Relative)) { $Relative = "index.html" }

    # Fuehrende Trenner entfernen, sonst behandelt Join-Path den Pfad als
    # absolut und ignoriert die Wurzel vollstaendig.
    $Relative = $Relative -replace '^[\\/]+', ''
    if ([string]::IsNullOrWhiteSpace($Relative)) { $Relative = "index.html" }

    try {
        $candidate = [System.IO.Path]::GetFullPath((Join-Path $rootPath $Relative))
    } catch {
        return $null   # ungueltige Zeichen im Pfad
    }

    # OrdinalIgnoreCase: Windows-Pfade sind nicht case-sensitiv.
    if (-not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }
    return $candidate
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
try {
    $listener.Start()
} catch {
    Write-Host ""
    Write-Host "  Server konnte nicht gestartet werden: $($_.Exception.Message)"
    Write-Host "  Moeglicherweise ist Port $Port belegt."
    Write-Host ""
    Read-Host "  Mit Enter beenden"
    exit 1
}

Write-Host "  Laeuft auf http://localhost:$Port/  (Strg+C beendet)"

try {
    while ($listener.IsListening) {
        $ctx = $null
        try {
            $ctx = $listener.GetContext()

            $rel = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
            $full = Get-SafePath -Relative $rel

            if ($null -eq $full) {
                $ctx.Response.StatusCode = 403
                $ctx.Response.Close()
                continue
            }

            if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
                # Single-Page-App: Pfade OHNE Dateiendung auf index.html
                # leiten. Pfade MIT Endung bekommen 404 - fuer eine fehlende
                # .js-Datei HTML zurueckzugeben erzeugt sonst einen
                # Folgefehler, der wie ein Syntaxfehler aussieht.
                if ([System.IO.Path]::GetExtension($full)) {
                    $ctx.Response.StatusCode = 404
                    $ctx.Response.Close()
                    continue
                }
                $full = Join-Path $rootPath "index.html"
            }

            $bytes = [System.IO.File]::ReadAllBytes($full)
            $ext = [System.IO.Path]::GetExtension($full).ToLower()
            $ctx.Response.ContentType =
                if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" }

            # Hier wirken echte HTTP-Header - anders als bei GitHub Pages,
            # wo dieselben Angaben als <meta> wirkungslos waeren (siehe
            # Kommentar in web/index.html). Der Offline-Bundle ist der
            # einzige Auslieferungsweg, auf dem sie gesetzt werden koennen.
            $ctx.Response.Headers.Add("X-Content-Type-Options", "nosniff")
            $ctx.Response.Headers.Add("Referrer-Policy", "no-referrer")
            $ctx.Response.Headers.Add("X-Frame-Options", "DENY")

            $ctx.Response.ContentLength64 = $bytes.Length
            # HEAD: Header ja, Rumpf nein.
            if ($ctx.Request.HttpMethod -ne "HEAD") {
                $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            $ctx.Response.Close()
        } catch {
            if ($null -ne $ctx) {
                try { $ctx.Response.StatusCode = 500; $ctx.Response.Close() } catch { }
            }
        }
    }
} finally {
    try { $listener.Stop(); $listener.Close() } catch { }
}
