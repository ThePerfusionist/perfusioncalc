<#
    Minimal static web server for PerfusionCalc.

    Purpose: a fallback for machines where running foreign .exe files is
    blocked by policy — PowerShell is present on every Windows system.

    Binds to localhost only, on purpose. That needs no administrator rights
    (which 'http://+:port/' would) and keeps the server unreachable from
    outside.

    SECURITY NOTE FOR REVIEW BY HOSPITAL IT
    ---------------------------------------
    This script serves files exclusively from the folder passed in at start.
    The path check in Get-SafePath resolves '..' BEFORE comparing (see the
    comment there) — a request such as /%2e%2e%2f%2e%2e%2fWindows/win.ini is
    answered with 403.

    Manual counter-check after every change to Get-SafePath:
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

# With a trailing separator: otherwise a sibling folder 'webbackup' would
# pass the prefix comparison, because the string starts with '...\web'.
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
    Resolves a requested path and returns it ONLY if it lies inside
    $rootPath. Otherwise $null.

    Why not simply Join-Path + StartsWith: Join-Path does NOT normalise. For
    rel = '..\..\Windows\win.ini' the resulting string is
    'C:\PerfusionCalc\web\..\..\Windows\win.ini' — which starts with the
    root path, so it passes the comparison, and ReadAllBytes resolves the
    '..' afterwards. GetFullPath resolves them BEFOREHAND.

    UnescapeDataString is equally critical: HttpListener delivers the path
    still partially percent-encoded, so %2e%2e%2f only becomes '../' here.
    The check therefore has to happen AFTER decoding — which is exactly what
    this function does.
#>
function Get-SafePath {
    param([string]$Relative)

    if ([string]::IsNullOrWhiteSpace($Relative)) { $Relative = "index.html" }

    # Strip leading separators, otherwise Join-Path treats the path as
    # absolute and ignores the root entirely.
    $Relative = $Relative -replace '^[\\/]+', ''
    if ([string]::IsNullOrWhiteSpace($Relative)) { $Relative = "index.html" }

    try {
        $candidate = [System.IO.Path]::GetFullPath((Join-Path $rootPath $Relative))
    } catch {
        return $null   # invalid characters in the path
    }

    # OrdinalIgnoreCase: Windows paths are not case sensitive.
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
                # Single-page app: route paths WITHOUT a file extension to
                # index.html. Paths WITH an extension get 404 — returning
                # HTML for a missing .js file otherwise causes a follow-up
                # error that looks like a syntax error.
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

            # Real HTTP headers take effect here — unlike on GitHub Pages,
            # where the same declarations would be ineffective as <meta>
            # (see the comment in web/index.html). The offline bundle is the
            # only delivery path on which they can be set.
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
