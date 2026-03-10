#!/usr/bin/env pwsh
param(
  [string]$ReportFile = "reports\latest-report.json",
  [string]$TemplateFile = "dashboard\index.save.html",
  [string]$OutFile = "dashboard\index.html"
)

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ReportPath = Join-Path $RootDir $ReportFile
$TemplatePath = Join-Path $RootDir $TemplateFile
$OutPath = Join-Path $RootDir $OutFile

& python $RootDir\scripts\generate-dashboard.py --report $ReportPath --template $TemplatePath --output $OutPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

