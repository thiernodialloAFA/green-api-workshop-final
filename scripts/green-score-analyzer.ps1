#!/usr/bin/env pwsh
###############################################################################
#  Green Score Analyzer — Version PowerShell (Windows)
#  Usage: .\green-score-analyzer.ps1
###############################################################################
param(
    [int]$BaselinePort = 8080,
    [int]$OptimizedPort = 8081,
    [switch]$Debug
)

$ErrorActionPreference = "Continue"
$Baseline = "http://localhost:$BaselinePort"
$Optimized = "http://localhost:$OptimizedPort"
$Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ReportDir = Join-Path $RootDir "reports"
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
$ReportFile = Join-Path $ReportDir "green-score-report-$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$LatestLink = Join-Path $ReportDir "latest-report.json"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Green API Score Analyzer - Devoxx France 2026" -ForegroundColor Cyan
Write-Host "  Green Architecture: moins de gras, plus d'impact !" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

function Measure-Endpoint {
    param([string]$Url, [hashtable]$Headers = @{})
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $params = @{ Uri = $Url; Method = "GET"; UseBasicParsing = $true }
        if ($Headers.Count -gt 0) { $params.Headers = $Headers }
        $response = Invoke-WebRequest @params -ErrorAction Stop
        $sw.Stop()
        return @{
            http_code = [int]$response.StatusCode
            size_download = $response.Content.Length
            time_total = [math]::Round($sw.Elapsed.TotalSeconds, 3)
        }
    } catch {
        $code = 0
        $size = 0
        if ($_.Exception.Response) {
            $code = [int]$_.Exception.Response.StatusCode
        }
        return @{ http_code = $code; size_download = $size; time_total = 0 }
    }
}

function Get-ETag {
    param([string]$Url)
    try {
        $r = Invoke-WebRequest -Uri $Url -Method HEAD -UseBasicParsing -ErrorAction Stop
        if ($r.Headers["ETag"]) { return $r.Headers["ETag"] }
        return ""
    } catch { return "" }
}

###############################################################################
# BASELINE
###############################################################################
Write-Host "--- BASELINE (port $BaselinePort) ---" -ForegroundColor Yellow

$B_FULL = @{ http_code=0; size_download=0; time_total=0 }
$B_ONE = @{ http_code=0; size_download=0; time_total=0 }
$B_ONE2 = @{ http_code=0; size_download=0; time_total=0 }

try {
    $null = Invoke-WebRequest -Uri "$Baseline/actuator/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    Write-Host "  [1/3] GET /books (full)..." -ForegroundColor Cyan
    $B_FULL = Measure-Endpoint "$Baseline/books"
    Write-Host "         size=$($B_FULL.size_download) bytes  time=$($B_FULL.time_total)s" -ForegroundColor Green

    Write-Host "  [2/3] GET /books/1..." -ForegroundColor Cyan
    $B_ONE = Measure-Endpoint "$Baseline/books/1"
    Write-Host "         size=$($B_ONE.size_download) bytes" -ForegroundColor Green

    Write-Host "  [3/3] GET /books/1 (repeat)..." -ForegroundColor Cyan
    $B_ONE2 = Measure-Endpoint "$Baseline/books/1"
    Write-Host "         http_code=$($B_ONE2.http_code)" -ForegroundColor Green
} catch {
    Write-Host "  Baseline non disponible sur le port $BaselinePort" -ForegroundColor Red
}

###############################################################################
# OPTIMIZED
###############################################################################
Write-Host ""
Write-Host "--- OPTIMIZED (port $OptimizedPort) ---" -ForegroundColor Yellow

$O_PAGE = @{ http_code=0; size_download=0; time_total=0 }
$O_FIELDS = @{ http_code=0; size_download=0; time_total=0 }
$O_GZIP = @{ http_code=0; size_download=0; time_total=0 }
$O_ETAG_FIRST = @{ http_code=0; size_download=0; time_total=0 }
$O_ETAG_304 = @{ http_code=0; size_download=0; time_total=0 }
$O_DELTA = @{ http_code=0; size_download=0; time_total=0 }
$O_RANGE = @{ http_code=0; size_download=0; time_total=0 }
$O_CBOR = @{ http_code=0; size_download=0; time_total=0 }
$O_FULL = @{ http_code=0; size_download=0; time_total=0 }

try {
    $null = Invoke-WebRequest -Uri "$Optimized/actuator/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop

    Write-Host "  [1/8] Pagination DE11..." -ForegroundColor Cyan
    $O_PAGE = Measure-Endpoint "$Optimized/books?page=0&size=20"
    Write-Host "         size=$($O_PAGE.size_download) bytes" -ForegroundColor Green

    Write-Host "  [2/8] Fields DE08..." -ForegroundColor Cyan
    $O_FIELDS = Measure-Endpoint "$Optimized/books/select?fields=id,title,author&page=0&size=20"
    Write-Host "         size=$($O_FIELDS.size_download) bytes" -ForegroundColor Green

    Write-Host "  [3/8] Gzip DE01..." -ForegroundColor Cyan
    $O_GZIP = Measure-Endpoint "$Optimized/books/select?fields=id,title,author&page=0&size=50" @{"Accept-Encoding"="gzip"}
    Write-Host "         size=$($O_GZIP.size_download) bytes" -ForegroundColor Green

    Write-Host "  [4/8] ETag 304 DE02/DE03..." -ForegroundColor Cyan
    $O_ETAG_FIRST = Measure-Endpoint "$Optimized/books/1"
    $etag = Get-ETag "$Optimized/books/1"
    if ($etag) {
        $O_ETAG_304 = Measure-Endpoint "$Optimized/books/1" @{"If-None-Match"=$etag}
    }
    Write-Host "         304 code=$($O_ETAG_304.http_code) size=$($O_ETAG_304.size_download)" -ForegroundColor Green

    Write-Host "  [5/8] Delta DE06..." -ForegroundColor Cyan
    $since = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $O_DELTA = Measure-Endpoint "$Optimized/books/changes?since=$since"
    Write-Host "         size=$($O_DELTA.size_download) bytes" -ForegroundColor Green

    Write-Host "  [6/8] Range 206..." -ForegroundColor Cyan
    $O_RANGE = Measure-Endpoint "$Optimized/books/1/summary" @{"Range"="bytes=0-199"}
    Write-Host "         code=$($O_RANGE.http_code) size=$($O_RANGE.size_download)" -ForegroundColor Green

    Write-Host "  [7/8] CBOR..." -ForegroundColor Cyan
    $O_CBOR = Measure-Endpoint "$Optimized/books/cbor" @{"Accept"="application/cbor"}
    Write-Host "         size=$($O_CBOR.size_download) bytes" -ForegroundColor Green

    Write-Host "  [8/8] Full payload..." -ForegroundColor Cyan
    $O_FULL = Measure-Endpoint "$Optimized/books"
    Write-Host "         size=$($O_FULL.size_download) bytes" -ForegroundColor Green

} catch {
    Write-Host "  Optimized non disponible sur le port $OptimizedPort" -ForegroundColor Red
}

###############################################################################
# GREEN SCORE CALCULATION
###############################################################################
Write-Host ""
Write-Host "--- GREEN SCORE ---" -ForegroundColor Yellow

$scores = @{}
$details = @{}

# DE11 - Pagination (15 pts)
$bf = $B_FULL.size_download; $op = $O_PAGE.size_download
if ($bf -gt 0 -and $op -gt 0 -and $op -lt $bf) {
    $ratio = 1 - ($op / $bf)
    $scores["DE11_pagination"] = [math]::Min(15, [math]::Round($ratio * 15, 1))
    $details["DE11_pagination"] = @{ baseline_bytes=$bf; optimized_bytes=$op; reduction_pct=[math]::Round($ratio*100,1) }
} elseif ($op -gt 0) { $scores["DE11_pagination"] = 8 } else { $scores["DE11_pagination"] = 0 }

# DE08 - Fields (15 pts)
$of = $O_FIELDS.size_download
if ($op -gt 0 -and $of -gt 0 -and $of -lt $op) {
    $ratio = 1 - ($of / $op)
    $scores["DE08_fields"] = [math]::Min(15, [math]::Round($ratio * 15 + 5, 1))
    $details["DE08_fields"] = @{ paginated_bytes=$op; filtered_bytes=$of; reduction_pct=[math]::Round($ratio*100,1) }
} elseif ($of -gt 0) { $scores["DE08_fields"] = 10 } else { $scores["DE08_fields"] = 0 }

# DE01 - Compression (15 pts)
$og = $O_GZIP.size_download
if ($of -gt 0 -and $og -gt 0 -and $og -lt $of) {
    $ratio = 1 - ($og / $of)
    $scores["DE01_compression"] = [math]::Min(15, [math]::Round($ratio * 15 + 3, 1))
    $details["DE01_compression"] = @{ uncompressed=$of; gzip=$og; reduction_pct=[math]::Round($ratio*100,1) }
} elseif ($og -gt 0) { $scores["DE01_compression"] = 8 } else { $scores["DE01_compression"] = 0 }

# DE02/DE03 - Cache (15 pts)
if ($O_ETAG_304.http_code -eq 304) { $scores["DE02_DE03_cache"] = 15; $details["DE02_DE03_cache"] = @{ note="304 OK" } }
elseif ($O_ETAG_304.http_code -eq 200) { $scores["DE02_DE03_cache"] = 5 }
else { $scores["DE02_DE03_cache"] = 0 }

# DE06 - Delta (10 pts)
if ($O_DELTA.http_code -eq 200) { $scores["DE06_delta"] = 8; $details["DE06_delta"] = @{ delta_bytes=$O_DELTA.size_download } }
else { $scores["DE06_delta"] = 0 }

# 206 Range (10 pts)
if ($O_RANGE.http_code -eq 206) { $scores["range_206"] = 10 }
elseif ($O_RANGE.http_code -eq 200) { $scores["range_206"] = 3 }
else { $scores["range_206"] = 0 }

# LO01 (5 pts)
if ($O_FULL.http_code -gt 0) { $scores["LO01_observability"] = 5 } else { $scores["LO01_observability"] = 0 }

# US07 (5 pts)
if ($O_FULL.http_code -gt 0) { $scores["US07_rate_limit"] = 5 } else { $scores["US07_rate_limit"] = 0 }

# AR02 (10 pts)
if ($O_CBOR.size_download -gt 0) { $scores["AR02_format_cbor"] = 10 } else { $scores["AR02_format_cbor"] = 0 }

$total = ($scores.Values | Measure-Object -Sum).Sum
$grade = if ($total -ge 90) {"A+"} elseif ($total -ge 80) {"A"} elseif ($total -ge 65) {"B"} elseif ($total -ge 50) {"C"} elseif ($total -ge 30) {"D"} else {"E"}

$report = @{
    timestamp = $Timestamp
    green_score = @{
        total = $total
        max = 100
        grade = $grade
        breakdown = $scores
        details = $details
    }
    measurements = @{
        baseline = @{ full_payload = $B_FULL; single_resource = $B_ONE; single_repeat = $B_ONE2 }
        optimized = @{
            pagination = $O_PAGE; fields_filter = $O_FIELDS; gzip_compression = $O_GZIP
            etag_first_call = $O_ETAG_FIRST; etag_304 = $O_ETAG_304
            delta_changes = $O_DELTA; range_206 = $O_RANGE
            cbor_format = $O_CBOR; full_payload = $O_FULL
        }
    }
}

$json = $report | ConvertTo-Json -Depth 5
$json | Out-File -FilePath $ReportFile -Encoding utf8
$json | Out-File -FilePath $LatestLink -Encoding utf8

# Purge old reports: keep only the 5 most recent (+ latest-report.json)
Write-Host "🧹 Purge des anciens rapports (conservation des 5 derniers)..." -ForegroundColor Yellow
$allReports = Get-ChildItem -Path $ReportDir -Filter "green-score-report-*.json" | Sort-Object LastWriteTime -Descending
if ($allReports.Count -gt 5) {
    $allReports | Select-Object -Skip 5 | ForEach-Object {
        Write-Host "  🗑️  Suppression : $($_.Name)"
        Remove-Item $_.FullName -Force
    }
}

# Generate badge (non-blocking)
$badgeScript = Join-Path $RootDir "scripts\generate-badge.ps1"
if (Test-Path $badgeScript) {
  & $badgeScript $LatestLink (Join-Path $RootDir "badges\green-score.svg") | Out-Null
}

# Generate dashboard (non-blocking)
$dashboardScript = Join-Path $RootDir "scripts\generate-dashboard.ps1"
if (Test-Path $dashboardScript) {
  & $dashboardScript $LatestLink "dashboard\index.save.html" "dashboard\index.html" | Out-Null
}

if ($Debug) {
    Write-Host "--- DEBUG: Full JSON report ---" -ForegroundColor Yellow
    $json | Write-Host
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  GREEN SCORE: $total/100   Grade: $grade" -ForegroundColor Green
Write-Host "  Report: $ReportFile" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan

