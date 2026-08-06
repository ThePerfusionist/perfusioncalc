<#
    PerfusionCalc — full local verification
    =======================================

    Runs everything that has to be green before a release, in the order
    "what fails hard comes first":

      1. flutter pub get
      2. flutter analyze
      3. flutter test
      4. tool/verify/consistency_check.py   (cross-language invariants)
      5. tool/offline/test-serve.ps1        (path traversal of the offline server)

    Step 5 runs on Windows only and needs no Flutter build — it creates its
    own test directory.

    USAGE (from the project root):
        powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\verify\verify-all.ps1

    Options:
        -SkipTests      skips flutter test (quick pass)
        -SkipServe      skips the server check

    Exits 0 when everything passes, otherwise 1.
#>
param(
    [switch]$SkipTests,
    [switch]$SkipServe
)

$ErrorActionPreference = "Continue"
$repo = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location -LiteralPath $repo

$results = @()

function Step {
    param([string]$Name, [scriptblock]$Action)
    Write-Host ""
    Write-Host "══ $Name " -NoNewline
    Write-Host ("═" * [Math]::Max(0, 58 - $Name.Length))
    & $Action
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
    $script:results += [pscustomobject]@{ Name = $Name; Code = $code }
    if ($code -ne 0) {
        Write-Host "   -> failed (exit $code)" -ForegroundColor Red
    }
}

Step "flutter pub get" { flutter pub get }
Step "flutter analyze" { flutter analyze }

if (-not $SkipTests) {
    Step "flutter test" { flutter test }
} else {
    Write-Host "`n══ flutter test  (skipped)" -ForegroundColor Yellow
}

<#
    Finds a Python interpreter that actually RUNS.

    Get-Command alone is not enough: Windows places app execution aliases for
    python.exe and python3.exe under %LOCALAPPDATA%\Microsoft\WindowsApps.
    They sit in PATH, often BEFORE a real installation, and merely open the
    Microsoft Store when invoked — exit code 9009. Get-Command still reports
    them as found.

    The same trap that start.bat has guarded against with `python -c "pass"`
    since O-2. An execution attempt is the only reliable test.

    Order: `py -3` first — the Python launcher ships with the python.org
    installers, lives in %WINDIR% and is not shadowed by the aliases.
#>
function Find-Python {
    $candidates = @(
        @{ Exe = "py";      Args = @("-3") },
        @{ Exe = "python3"; Args = @() },
        @{ Exe = "python";  Args = @() }
    )
    foreach ($c in $candidates) {
        if (-not (Get-Command $c.Exe -ErrorAction SilentlyContinue)) { continue }
        try {
            $probe = @($c.Args) + @("-c", "pass")
            & $c.Exe @probe 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { return $c }
        } catch { }
    }
    return $null
}

Step "Consistency check" {
    $py = Find-Python
    if (-not $py) {
        Write-Host "   No runnable Python interpreter found." -ForegroundColor Yellow
        Write-Host "   If Python is installed, the app execution alias is probably" -ForegroundColor Yellow
        Write-Host "   shadowing the real installation:" -ForegroundColor Yellow
        Write-Host "     Settings > Apps > Advanced app settings >" -ForegroundColor Yellow
        Write-Host "     App execution aliases -> turn off python.exe and python3.exe." -ForegroundColor Yellow
        Write-Host "   Or run it directly:  py -3 tool\verify\consistency_check.py" -ForegroundColor Yellow
        $global:LASTEXITCODE = 1
        return
    }
    $call = @($py.Args) + @("tool\verify\consistency_check.py")
    & $py.Exe @call
}

if (-not $SkipServe) {
    Step "Offline server (path traversal)" {
        powershell -NoProfile -ExecutionPolicy Bypass -File "tool\offline\test-serve.ps1"
    }
} else {
    Write-Host "`n══ Offline server  (skipped)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "══ Summary ═════════════════════════════════════════════════"
$failed = 0
foreach ($r in $results) {
    if ($r.Code -eq 0) {
        Write-Host ("  ok     " + $r.Name) -ForegroundColor Green
    } else {
        Write-Host ("  FAIL   " + $r.Name) -ForegroundColor Red
        $failed++
    }
}
Write-Host ""

if ($failed -eq 0) {
    Write-Host "  All green." -ForegroundColor Green
    exit 0
}
Write-Host "  $failed step(s) failed." -ForegroundColor Red
exit 1
