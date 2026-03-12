###############################################################################
#  Green API Auto-Discover & Analyzer - PowerShell wrapper
#
#  Usage:
#    .\green-api-auto-discover.ps1
#    .\green-api-auto-discover.ps1 -Target http://localhost:8081
#    .\green-api-auto-discover.ps1 -Swagger .\openapi.yaml -DryRun
#    .\green-api-auto-discover.ps1 -Target http://localhost:8081 -Bearer MY_TOKEN
###############################################################################
param(
    [string]$Target      = "http://localhost:8081",
    [string]$Swagger     = "",
    [string]$Bearer      = "",
    [int]$Repeat         = 3,
    [string]$Methods     = "get",
    [switch]$DryRun,
    [switch]$SkipSpectral,
    [switch]$SkipDashboard,
    [string]$OutputDir   = "",
    [string[]]$Params    = @(),
    [string[]]$ExtraArgs = @()
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir   = Split-Path -Parent $ScriptDir
$PythonScript = Join-Path $ScriptDir "green-api-auto-discover.py"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Green API Auto-Discover & Analyzer" -ForegroundColor Cyan
Write-Host "  Devoxx France 2026 - Green Architecture" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Build arguments
$pyArgs = @()
if ($Target)   { $pyArgs += "--target"; $pyArgs += $Target }
if ($Swagger)  { $pyArgs += "--swagger"; $pyArgs += $Swagger }
if ($Bearer)   { $pyArgs += "--bearer"; $pyArgs += $Bearer }
$pyArgs += "--repeat"; $pyArgs += $Repeat.ToString()
$pyArgs += "--methods"; $pyArgs += $Methods
if ($DryRun)        { $pyArgs += "--dry-run" }
if ($SkipSpectral)  { $pyArgs += "--skip-spectral" }
if ($SkipDashboard) { $pyArgs += "--skip-dashboard" }
if ($OutputDir)     { $pyArgs += "--output-dir"; $pyArgs += $OutputDir }

foreach ($p in $Params) {
    $pyArgs += "--param"
    $pyArgs += $p
}

$pyArgs += $ExtraArgs

# Find python
$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
if (-not $python) {
    Write-Host "Python not found. Please install Python 3.8+." -ForegroundColor Red
    exit 1
}
$pyExe = $python.Source

Write-Host "Running: $pyExe $PythonScript $($pyArgs -join ' ')" -ForegroundColor Green
Write-Host ""

& $pyExe $PythonScript @pyArgs
$exitCode = $LASTEXITCODE

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "Analysis complete. Open dashboard/index.html to view results." -ForegroundColor Green
} else {
    Write-Host "Analysis failed or score below threshold (exit code: $exitCode)." -ForegroundColor Red
}

exit $exitCode

