#!/usr/bin/env pwsh
<##
  Generate Green Score badge (SVG)
  Usage: .\scripts\generate-badge.ps1 reports\latest-report.json badges\green-score.svg
##>
param(
  [string]$ReportFile = "reports\latest-report.json",
  [string]$OutFile = "badges\green-score.svg"
)

if (-not (Test-Path $ReportFile)) {
  Write-Error "Report not found: $ReportFile"
  exit 1
}

$report = Get-Content $ReportFile -Raw | ConvertFrom-Json
$score = [int]$report.green_score.total
$grade = $report.green_score.grade

$color = if ($score -ge 90) { "#16a34a" } elseif ($score -ge 80) { "#22c55e" } elseif ($score -ge 65) { "#eab308" } elseif ($score -ge 50) { "#f97316" } else { "#ef4444" }

$label = "Green Score"
$value = "$score/100 ($grade)"

$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="220" height="24" role="img" aria-label="${label}: ${value}">
  <title>${label}: ${value}</title>
  <linearGradient id="s" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <rect rx="4" width="100" height="24" fill="#374151"/>
  <rect rx="4" x="100" width="120" height="24" fill="${color}"/>
  <rect rx="4" width="220" height="24" fill="url(#s)"/>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,DejaVu Sans,sans-serif" font-size="11">
    <text x="50" y="16">${label}</text>
    <text x="160" y="16">${value}</text>
  </g>
</svg>
"@

$dir = Split-Path -Parent $OutFile
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[System.IO.File]::WriteAllText($OutFile, $svg, (New-Object System.Text.UTF8Encoding $false))
Write-Host "Badge written to $OutFile"
