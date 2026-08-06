<#
    Counter-check for serve.ps1 — path traversal and basic behaviour
    ================================================================

    Starts serve.ps1 on a free port, fires a series of requests at it and
    compares the results. Replaces the manual check that used to live as a
    comment in the header of serve.ps1.

    Background: until v0.4.9 serve.ps1 used Join-Path + StartsWith to decide
    whether a request left the root folder. Join-Path does NOT normalise
    '..' — the concatenated string starts with the root path, so it passes
    the check, and ReadAllBytes resolves the '..' afterwards. Arbitrary file
    read access with the rights of the logged-in user.

    The percent-encoded variants are the more important ones: a browser
    collapses '..' in a URL before sending; '%2e%2e%2f' survives and is only
    resolved by UnescapeDataString inside the server.

    USAGE (from the tool/offline folder):
        powershell -NoProfile -ExecutionPolicy Bypass -File .\test-serve.ps1

    Exits 0 when everything passes, otherwise 1.
#>
param(
    [int]$Port = 8137   # deliberately away from the usual 8080 range
)

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

$failures = 0
$checks = 0

# The marker lives in the file outside the root folder. It is the actual
# pass/fail criterion — see Assert-NoLeak.
$script:SecretMarker = "THIS-FILE-MUST-NEVER-BE-SERVED"

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
        Write-Host ("  [FAIL] {0,-52} -> {1}, erwartet {2}" -f $Path, $r.Status, ($Expected -join '/')) -ForegroundColor Red
        Write-Host ("         {0}" -f $Why) -ForegroundColor Red
        $script:failures++
    }
}

<#
    Pass/fail criterion for traversal attempts.

    Do NOT check for 403 alone — that would be too narrow and was wrong in
    the first version of this test. Reason: Invoke-WebRequest (and http.sys
    on the way there) normalises '..' in a URL BEFORE the request reaches
    the server. '/../secret.txt' becomes '/secret.txt', and the server
    answers that perfectly correctly with 404 — it never saw a traversal. An
    expected 403 then fails without anything being broken.

    That is precisely why the percent-encoded variants are the interesting
    ones: '%2e%2e%2f' survives any normalisation and is only resolved inside
    the server by UnescapeDataString — where Get-SafePath takes effect.

    The real criterion is about content: the contents of the file outside the
    root folder must NEVER appear in a response. Status 403 (server refused)
    and 404 (request arrived normalised) are both fine; 200 with the marker
    in the body is the finding.
#>
function Assert-NoLeak {
    param([string]$Path, [string]$Why)
    $script:checks++
    $r = Invoke-Probe $Path
    $leaked = $r.Body -and ($r.Body -like "*$script:SecretMarker*")
    if ($leaked) {
        Write-Host ("  [FAIL] {0,-52} -> {1} WITH FILE CONTENTS" -f $Path, $r.Status) -ForegroundColor Red
        Write-Host ("         {0} - file outside the root folder was served!" -f $Why) -ForegroundColor Red
        $script:failures++
    } elseif ($r.Status -eq 200) {
        Write-Host ("  [FAIL] {0,-52} -> 200" -f $Path) -ForegroundColor Red
        Write-Host ("         {0} - unexpectedly succeeded" -f $Why) -ForegroundColor Red
        $script:failures++
    } elseif ($r.Status -eq 403) {
        Write-Host ("  [ok]   {0,-52} -> 403 refused" -f $Path)
    } elseif ($r.Status -eq 404) {
        Write-Host ("  [ok]   {0,-52} -> 404 (client normalised the path)" -f $Path)
    } else {
        Write-Host ("  [FAIL] {0,-52} -> {1} unexpected" -f $Path, $r.Status) -ForegroundColor Red
        $script:failures++
    }
}

<#
    Raw request over a TCP socket, bypassing any client-side normalisation.
    Only this way can we check what a hostile client would actually send.
    http.sys may still canonicalise — that is a passing case too, as long as
    the marker does not appear in the body.
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
        Write-Host ("  [warn] {0,-52} -> connection failed, skipped" -f $RawPath) -ForegroundColor Yellow
        return
    }
    $statusLine = ($response -split "`r`n")[0]
    if ($response -like "*$script:SecretMarker*") {
        Write-Host ("  [FAIL] {0,-52} -> {1} WITH FILE CONTENTS" -f $RawPath, $statusLine) -ForegroundColor Red
        Write-Host ("         {0} - sent raw, file was served!" -f $Why) -ForegroundColor Red
        $script:failures++
    } else {
        Write-Host ("  [ok]   {0,-52} -> {1}" -f $RawPath, $statusLine)
    }
}

# ── Build the test environment ───────────────────────────────────────────
# A dedicated root folder instead of the real web\, so the test also runs
# without a built bundle. The traversal's target file is created ON PURPOSE:
# otherwise a 404 would look like a passing test even though the server
# would happily have handed the file out.
$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("pcalc-servetest-" + [guid]::NewGuid().ToString("N"))
$root = Join-Path $sandbox "web"
$outside = Join-Path $sandbox "secret.txt"
$sibling = Join-Path $sandbox "webbackup"

New-Item -ItemType Directory -Path $root -Force | Out-Null
New-Item -ItemType Directory -Path $sibling -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root "assets") -Force | Out-Null
Set-Content -LiteralPath (Join-Path $root "index.html") -Value "<html><body>ok</body></html>"
Set-Content -LiteralPath (Join-Path $root "main.dart.js") -Value "console.log(1)"
Set-Content -LiteralPath (Join-Path $root "assets\datei.txt") -Value "asset"
Set-Content -LiteralPath $outside -Value "THIS-FILE-MUST-NEVER-BE-SERVED"
Set-Content -LiteralPath (Join-Path $sibling "neighbour.txt") -Value "THIS-FILE-MUST-NEVER-BE-SERVED"

Write-Host ""
Write-Host "  Sandbox: $sandbox"
Write-Host "  Server:  http://localhost:$Port/"
Write-Host ""

$job = Start-Job -ScriptBlock {
    param($script, $port, $root)
    & $script -Port $port -Root $root
} -ArgumentList (Join-Path $PSScriptRoot "serve.ps1"), $Port, $root

try {
    # Wait for the listener instead of sleeping blindly.
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
        Write-Host "  ERROR: the server did not come up." -ForegroundColor Red
        Write-Host "  Output of the server process:" -ForegroundColor Red
        Receive-Job $job -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "    $_" -ForegroundColor Red
        }
        $failures++
        return
    }

    Write-Host "  Allowed paths"
    Assert-Status "/"                    @(200) "root must serve index.html"
    Assert-Status "/index.html"          @(200) "existing file"
    Assert-Status "/main.dart.js"        @(200) "existing file in the root folder"
    Assert-Status "/assets/datei.txt"    @(200) "existing file in a subfolder"

    Write-Host ""
    Write-Host "  Path traversal (file contents must never appear)"
    Assert-NoLeak "/../secret.txt"                     "plain-text traversal"
    Assert-NoLeak "/%2e%2e%2fsecret.txt"               "percent-encoded - survives normalisation"
    Assert-NoLeak "/%2e%2e/secret.txt"                 "mixed encoding"
    Assert-NoLeak "/..%5csecret.txt"                   "encoded backslash"
    Assert-NoLeak "/assets/%2e%2e%2f%2e%2e%2fsecret.txt" "from a subfolder, encoded"
    Assert-NoLeak "/assets/../../secret.txt"           "from a subfolder, plain text"
    Assert-NoLeak "/%2e%2e%2fwebbackup%2fneighbour.txt"  "sibling folder with the same prefix"
    Assert-NoLeak "/../webbackup/neighbour.txt"          "sibling folder, plain text"
    Assert-NoLeak "/%2e%2e%2f%2e%2e%2fWindows/win.ini" "multi-level, real system target"

    Write-Host ""
    Write-Host "  Sent raw, bypassing client normalisation"
    Assert-NoLeakRaw "/../secret.txt"                  "unnormalised plain-text traversal"
    Assert-NoLeakRaw "/..%2fsecret.txt"                "unnormalised, partially encoded"

    Write-Host ""
    Write-Host "  Missing paths"
    # With an extension: 404. Returning HTML for a missing .js otherwise
    # causes a follow-up error that looks like a syntax error.
    Assert-Status "/gibtesnicht.js"      @(404) "missing file WITH an extension"
    # Ohne Endung: SPA-Rueckfall auf index.html.
    Assert-Status "/irgendeine/route"    @(200) "SPA fallback for paths WITHOUT an extension"

    Write-Host ""
    if ($failures -eq 0) {
        Write-Host "  $checks checks, all passed." -ForegroundColor Green
    } else {
        Write-Host "  $checks checks, $failures FAILED." -ForegroundColor Red
    }
} finally {
    Stop-Job $job -ErrorAction SilentlyContinue | Out-Null
    Remove-Job $job -Force -ErrorAction SilentlyContinue | Out-Null
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

# No ternary operator: that only exists from PowerShell 7 onwards, and on
# Windows workstations 5.1 is the normal case.
if ($failures -eq 0) { exit 0 } else { exit 1 }
