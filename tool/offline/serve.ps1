<#
    Minimaler statischer Webserver fuer PerfusionCalc.

    Zweck: Fallback fuer Rechner, auf denen das Ausfuehren fremder
    .exe-Dateien durch Richtlinien gesperrt ist - PowerShell ist auf
    jedem Windows-System vorhanden.

    Bindet bewusst nur an localhost. Damit ist keine Administrator-
    Berechtigung noetig (fuer 'http://+:port/' waere sie es) und der
    Server ist von aussen nicht erreichbar.
#>
param(
    [int]$Port = 8080,
    [string]$Root = "web"
)

$ErrorActionPreference = "Stop"
$rootPath = (Resolve-Path -LiteralPath $Root).Path

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

while ($listener.IsListening) {
    try {
        $ctx = $listener.GetContext()
        $rel = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart("/"))
        if ([string]::IsNullOrWhiteSpace($rel)) { $rel = "index.html" }

        $full = Join-Path $rootPath $rel
        # Verzeichniswechsel nach oben unterbinden
        if (-not $full.StartsWith($rootPath)) {
            $ctx.Response.StatusCode = 403; $ctx.Response.Close(); continue
        }
        # Unbekannte Pfade auf index.html leiten (Single-Page-App)
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            $full = Join-Path $rootPath "index.html"
        }

        $bytes = [System.IO.File]::ReadAllBytes($full)
        $ext = [System.IO.Path]::GetExtension($full).ToLower()
        $ctx.Response.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" }
        $ctx.Response.ContentLength64 = $bytes.Length
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $ctx.Response.Close()
    } catch {
        try { $ctx.Response.StatusCode = 500; $ctx.Response.Close() } catch { }
    }
}
