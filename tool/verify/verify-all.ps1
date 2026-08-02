<#
    PerfusionCalc — vollständige lokale Prüfung
    ===========================================

    Ruft alles auf, was vor einem Release grün sein muss, in der Reihenfolge
    „was hart fehlschlägt zuerst":

      1. flutter pub get
      2. flutter analyze
      3. flutter test
      4. tool/verify/consistency_check.py   (sprachübergreifende Invarianten)
      5. tool/offline/test-serve.ps1        (Pfad-Traversal des Offline-Servers)

    Schritt 5 läuft nur unter Windows und braucht keinen Flutter-Build - er
    baut sich seinen eigenen Testordner.

    AUFRUF (im Projektwurzelverzeichnis):
        powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\verify\verify-all.ps1

    Optionen:
        -SkipTests      überspringt flutter test (schneller Durchlauf)
        -SkipServe      überspringt die Serverprüfung

    Beendet mit 0, wenn alles passt, sonst 1.
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
        Write-Host "   -> fehlgeschlagen (Exit $code)" -ForegroundColor Red
    }
}

Step "flutter pub get" { flutter pub get }
Step "flutter analyze" { flutter analyze }

if (-not $SkipTests) {
    Step "flutter test" { flutter test }
} else {
    Write-Host "`n══ flutter test  (übersprungen)" -ForegroundColor Yellow
}

<#
    Findet einen Python-Interpreter, der wirklich LÄUFT.

    Get-Command allein genügt nicht: Windows legt unter
    %LOCALAPPDATA%\Microsoft\WindowsApps App-Ausführungsaliase für
    python.exe und python3.exe ab. Die stehen im PATH, oft VOR einer echten
    Installation, und öffnen beim Aufruf nur den Microsoft Store -
    Exit-Code 9009. Get-Command meldet sie trotzdem als gefunden.

    Dieselbe Falle, gegen die start.bat seit O-2 mit `python -c "pass"`
    prüft. Ein Ausführungsversuch ist der einzige verlässliche Test.

    Reihenfolge: `py -3` zuerst - der Python-Launcher kommt mit den
    Installern von python.org, liegt in %WINDIR% und wird von den Aliassen
    nicht verdeckt.
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

Step "Konsistenzprüfung" {
    $py = Find-Python
    if (-not $py) {
        Write-Host "   Kein lauffähiger Python-Interpreter gefunden." -ForegroundColor Yellow
        Write-Host "   Falls Python installiert ist, verdeckt vermutlich der" -ForegroundColor Yellow
        Write-Host "   App-Ausführungsalias die echte Installation:" -ForegroundColor Yellow
        Write-Host "     Einstellungen > Apps > Erweiterte App-Einstellungen >" -ForegroundColor Yellow
        Write-Host "     App-Ausführungsaliase -> python.exe und python3.exe abschalten." -ForegroundColor Yellow
        Write-Host "   Alternativ direkt:  py -3 tool\verify\consistency_check.py" -ForegroundColor Yellow
        $global:LASTEXITCODE = 1
        return
    }
    $call = @($py.Args) + @("tool\verify\consistency_check.py")
    & $py.Exe @call
}

if (-not $SkipServe) {
    Step "Offline-Server (Pfad-Traversal)" {
        powershell -NoProfile -ExecutionPolicy Bypass -File "tool\offline\test-serve.ps1"
    }
} else {
    Write-Host "`n══ Offline-Server  (übersprungen)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "══ Zusammenfassung ══════════════════════════════════════════"
$failed = 0
foreach ($r in $results) {
    if ($r.Code -eq 0) {
        Write-Host ("  ok     " + $r.Name) -ForegroundColor Green
    } else {
        Write-Host ("  FEHL   " + $r.Name) -ForegroundColor Red
        $failed++
    }
}
Write-Host ""

if ($failed -eq 0) {
    Write-Host "  Alles grün." -ForegroundColor Green
    exit 0
}
Write-Host "  $failed Schritt(e) fehlgeschlagen." -ForegroundColor Red
exit 1
