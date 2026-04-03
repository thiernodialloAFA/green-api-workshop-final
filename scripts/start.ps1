#!/usr/bin/env pwsh
<##
  Start baseline + optimized (local dev)
  Usage: .\scripts\start.ps1 [-Analyze]
##>
param(
  [switch]$Analyze,
  [switch]$Debug
)

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

Write-Host "Starting baseline (8080)..."
Start-Process -FilePath "mvn" -ArgumentList "-q", "spring-boot:run" -WorkingDirectory (Join-Path $Root "green-api-baseline")

Write-Host "Starting optimized (8081)..."
Start-Process -FilePath "mvn" -ArgumentList "-q", "spring-boot:run" -WorkingDirectory (Join-Path $Root "green-api-optimized")

if ($Analyze) {
  Write-Host "Running Green Score analyzer..."
  $analyzerArgs = @{}
  if ($Debug) { $analyzerArgs["Debug"] = $true }
  & (Join-Path $Root "scripts\green-score-analyzer.ps1") @analyzerArgs
}

Write-Host "Baseline:  http://localhost:8080"
Write-Host "Optimized: http://localhost:8081"
Write-Host "Dashboard: .\dashboard\index.html"

