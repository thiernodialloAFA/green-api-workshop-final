###############################################################################
#  Green Score Analyzer WITH DISCOVERY - PowerShell
#  ==================================================
#  Same as green-score-analyzer.ps1 but with automatic endpoint discovery
#  from OpenAPI/Swagger spec exposed by the API.
#
#  Usage:
#    .\green-score-analyzer_withdiscovery.ps1
#    .\green-score-analyzer_withdiscovery.ps1 -OptimizedPort 8081
#    .\green-score-analyzer_withdiscovery.ps1 -SwaggerUrl http://localhost:8081/v3/api-docs
###############################################################################
param(
    [int]$BaselinePort = 8080,
    [int]$OptimizedPort = 8081,
    [string]$SwaggerUrl = "",
    [string]$BearerToken = "",
    [int]$Repeat = 3
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
$SpecFile = Join-Path $ReportDir "discovered-openapi.json"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Green API Score Analyzer - WITH DISCOVERY" -ForegroundColor Cyan
Write-Host "  Devoxx France 2026 - Green Architecture" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

###############################################################################
# Helpers
###############################################################################
function Measure-Endpoint {
    param([string]$Url, [hashtable]$Headers = @{})
    if ($BearerToken) { $Headers["Authorization"] = "Bearer $BearerToken" }
    $totalTime = 0.0
    $totalBytes = 0
    $lastCode = 0
    for ($i = 0; $i -lt [math]::Max(1, $Repeat); $i++) {
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $params = @{ Uri = $Url; Method = "GET"; UseBasicParsing = $true }
            if ($Headers.Count -gt 0) { $params.Headers = $Headers }
            $response = Invoke-WebRequest @params -ErrorAction Stop
            $sw.Stop()
            $lastCode = [int]$response.StatusCode
            $totalBytes += $response.Content.Length
            $totalTime += $sw.Elapsed.TotalSeconds
        } catch {
            if ($sw) { $sw.Stop(); $totalTime += $sw.Elapsed.TotalSeconds }
            if ($_.Exception.Response) { $lastCode = [int]$_.Exception.Response.StatusCode }
        }
    }
    $n = [math]::Max(1, $Repeat)
    $avgTime = [math]::Round($totalTime / $n, 6)
    $avgBytes = [int]($totalBytes / $n)
    $speed = if ($avgTime -gt 0) { [int]($avgBytes / $avgTime) } else { 0 }
    return @{
        http_code = $lastCode
        size_download = $avgBytes
        time_total = $avgTime
        speed_download = $speed
    }
}

function Measure-EndpointOnce {
    param([string]$Url, [hashtable]$Headers = @{})
    if ($BearerToken) { $Headers["Authorization"] = "Bearer $BearerToken" }
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
        if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        return @{ http_code = $code; size_download = 0; time_total = 0 }
    }
}

function Get-ETag {
    param([string]$Url)
    try {
        $hdrs = @{}
        if ($BearerToken) { $hdrs["Authorization"] = "Bearer $BearerToken" }
        $r = Invoke-WebRequest -Uri $Url -Method HEAD -UseBasicParsing -Headers $hdrs -ErrorAction Stop
        if ($r.Headers["ETag"]) { return $r.Headers["ETag"] }
        return ""
    } catch { return "" }
}

###############################################################################
# STEP 0 - DISCOVER SWAGGER
###############################################################################
Write-Host "--- SWAGGER DISCOVERY ---" -ForegroundColor Yellow

$SwaggerPaths = @("/v3/api-docs", "/v3/api-docs.yaml", "/v2/api-docs", "/openapi.json", "/swagger.json")
$DiscoveryOk = $false
$DiscoveredEndpoints = @()

function Discover-Swagger {
    param([string]$BaseUrl, [string]$Label)

    if ($SwaggerUrl) {
        Write-Host "  Using explicit swagger: $SwaggerUrl" -ForegroundColor Cyan
        try {
            $resp = Invoke-WebRequest -Uri $SwaggerUrl -UseBasicParsing -ErrorAction Stop
            $resp.Content | Out-File -FilePath $SpecFile -Encoding utf8
            Write-Host "  Spec loaded from $SwaggerUrl" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "  Failed to load $SwaggerUrl" -ForegroundColor Red
        }
    }

    foreach ($path in $SwaggerPaths) {
        $url = "$BaseUrl$path"
        Write-Host -NoNewline "  Trying $url..."
        try {
            $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            if ($resp.StatusCode -eq 200 -and $resp.Content.Length -gt 50) {
                $resp.Content | Out-File -FilePath $SpecFile -Encoding utf8
                $script:SwaggerUrl = $url
                Write-Host " Found!" -ForegroundColor Green
                return $true
            }
        } catch {}
        Write-Host " x" -ForegroundColor Red
    }
    return $false
}

if (Discover-Swagger $Optimized "optimized") {
    $DiscoveryOk = $true
    Write-Host "  Swagger discovered from optimized API" -ForegroundColor Green
} elseif (Discover-Swagger $Baseline "baseline") {
    $DiscoveryOk = $true
    Write-Host "  Swagger discovered from baseline API" -ForegroundColor Green
} else {
    Write-Host "  No swagger discovered. Using hardcoded endpoints." -ForegroundColor Yellow
}

# Extract endpoints
if ($DiscoveryOk -and (Test-Path $SpecFile)) {
    try {
        $spec = Get-Content $SpecFile -Raw | ConvertFrom-Json
        $basePath = ""
        if ($spec.swagger -eq "2.0") { $basePath = $spec.basePath }

        $paths = $spec.paths.PSObject.Properties
        foreach ($p in $paths) {
            $pathStr = if ($basePath) { "$basePath$($p.Name)" } else { $p.Name }
            $methods = @("get", "post", "put", "patch", "delete")
            foreach ($method in $methods) {
                if ($p.Value.PSObject.Properties[$method]) {
                    $op = $p.Value.$method
                    $DiscoveredEndpoints += @{
                        method = $method.ToUpper()
                        path = $pathStr
                        operationId = if ($op.operationId) { $op.operationId } else { "${method}_${pathStr}" }
                        summary = if ($op.summary) { $op.summary } else { "" }
                        has_path_param = $pathStr -match "\{"
                    }
                }
            }
        }
        Write-Host "  Discovered $($DiscoveredEndpoints.Count) endpoint(s)" -ForegroundColor Green
        foreach ($ep in $DiscoveredEndpoints) {
            Write-Host "    $($ep.method.PadRight(6)) $($ep.path)  ($($ep.summary -replace '^$',$ep.operationId))" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  Error parsing spec: $_" -ForegroundColor Red
    }
}

Write-Host ""

###############################################################################
# STEP 1 - BASELINE (hardcoded + discovered)
###############################################################################
Write-Host "--- BASELINE (port $BaselinePort) ---" -ForegroundColor Yellow

$B_FULL = @{ http_code=0; size_download=0; time_total=0; speed_download=0 }
$B_ONE = @{ http_code=0; size_download=0; time_total=0; speed_download=0 }
$B_ONE2 = @{ http_code=0; size_download=0; time_total=0; speed_download=0 }
$B_Disc = @{}

$baselineUp = $false
try {
    $null = Invoke-WebRequest -Uri "$Baseline/actuator/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    $baselineUp = $true
} catch {}

if ($baselineUp) {
    # Discovered endpoints
    Write-Host "  Measuring discovered endpoints on baseline..." -ForegroundColor Cyan
    foreach ($ep in $DiscoveredEndpoints) {
        if ($ep.method -ne "GET") { continue }
        $urlPath = $ep.path -replace '\{[^}]+\}', '1'
        $url = "$Baseline$urlPath"
        $m = Measure-Endpoint $url
        $key = "$($ep.method):$($ep.path)"
        $B_Disc[$key] = $m
        Write-Host "    $($ep.method.PadRight(6)) $($ep.path.PadRight(50)) -> $($m.http_code)  $($m.size_download) bytes  $($m.time_total)s" -ForegroundColor Gray
    }

    # Hardcoded
    Write-Host "  [1/3] GET /books (full)..." -ForegroundColor Cyan
    $B_FULL = Measure-EndpointOnce "$Baseline/books"
    Write-Host "         size=$($B_FULL.size_download) bytes  time=$($B_FULL.time_total)s" -ForegroundColor Green

    Write-Host "  [2/3] GET /books/1..." -ForegroundColor Cyan
    $B_ONE = Measure-EndpointOnce "$Baseline/books/1"
    Write-Host "         size=$($B_ONE.size_download) bytes" -ForegroundColor Green

    Write-Host "  [3/3] GET /books/1 (repeat)..." -ForegroundColor Cyan
    $B_ONE2 = Measure-EndpointOnce "$Baseline/books/1"
    Write-Host "         http_code=$($B_ONE2.http_code)" -ForegroundColor Green
} else {
    Write-Host "  Baseline non disponible sur le port $BaselinePort" -ForegroundColor Red
}

Write-Host ""

###############################################################################
# STEP 2 - OPTIMIZED (hardcoded + discovered)
###############################################################################
Write-Host "--- OPTIMIZED (port $OptimizedPort) ---" -ForegroundColor Yellow

$O_PAGE = @{ http_code=0; size_download=0; time_total=0; speed_download=0 }
$O_FIELDS = @{ http_code=0; size_download=0; time_total=0; speed_download=0 }
$O_GZIP = @{ http_code=0; size_download=0; time_total=0; speed_download=0 }
$O_ETAG_FIRST = @{ http_code=0; size_download=0; time_total=0; speed_download=0 }
$O_ETAG_304 = @{ http_code=0; size_download=0; time_total=0; speed_download=0 }
$O_DELTA = @{ http_code=0; size_download=0; time_total=0; speed_download=0 }
$O_RANGE = @{ http_code=0; size_download=0; time_total=0; speed_download=0 }
$O_CBOR = @{ http_code=0; size_download=0; time_total=0; speed_download=0 }
$O_FULL = @{ http_code=0; size_download=0; time_total=0; speed_download=0 }
$O_Disc = @{}

$optimizedUp = $false
try {
    $null = Invoke-WebRequest -Uri "$Optimized/actuator/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    $optimizedUp = $true
} catch {}

if ($optimizedUp) {
    # Discovered endpoints
    Write-Host "  Measuring discovered endpoints on optimized..." -ForegroundColor Cyan
    foreach ($ep in $DiscoveredEndpoints) {
        if ($ep.method -ne "GET") { continue }
        $urlPath = $ep.path -replace '\{[^}]+\}', '1'
        $url = "$Optimized$urlPath"
        $m = Measure-Endpoint $url
        $key = "$($ep.method):$($ep.path)"
        $O_Disc[$key] = $m
        Write-Host "    $($ep.method.PadRight(6)) $($ep.path.PadRight(50)) -> $($m.http_code)  $($m.size_download) bytes  $($m.time_total)s" -ForegroundColor Gray
    }

    # Hardcoded green-specific
    Write-Host "  [1/8] Pagination DE11..." -ForegroundColor Cyan
    $O_PAGE = Measure-EndpointOnce "$Optimized/books?page=0&size=20"
    Write-Host "         size=$($O_PAGE.size_download) bytes" -ForegroundColor Green

    Write-Host "  [2/8] Fields DE08..." -ForegroundColor Cyan
    $O_FIELDS = Measure-EndpointOnce "$Optimized/books/select?fields=id,title,author&page=0&size=20"
    Write-Host "         size=$($O_FIELDS.size_download) bytes" -ForegroundColor Green

    Write-Host "  [3/8] Gzip DE01..." -ForegroundColor Cyan
    $O_GZIP = Measure-EndpointOnce "$Optimized/books/select?fields=id,title,author&page=0&size=50" @{"Accept-Encoding"="gzip"}
    Write-Host "         size=$($O_GZIP.size_download) bytes" -ForegroundColor Green

    Write-Host "  [4/8] ETag 304 DE02/DE03..." -ForegroundColor Cyan
    $O_ETAG_FIRST = Measure-EndpointOnce "$Optimized/books/1"
    $etag = Get-ETag "$Optimized/books/1"
    if ($etag) {
        $O_ETAG_304 = Measure-EndpointOnce "$Optimized/books/1" @{"If-None-Match"=$etag}
    }
    Write-Host "         304 code=$($O_ETAG_304.http_code)" -ForegroundColor Green

    Write-Host "  [5/8] Delta DE06..." -ForegroundColor Cyan
    $since = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $O_DELTA = Measure-EndpointOnce "$Optimized/books/changes?since=$since"
    Write-Host "         size=$($O_DELTA.size_download) bytes" -ForegroundColor Green

    Write-Host "  [6/8] Range 206..." -ForegroundColor Cyan
    $O_RANGE = Measure-EndpointOnce "$Optimized/books/1/summary" @{"Range"="bytes=0-199"}
    Write-Host "         code=$($O_RANGE.http_code)" -ForegroundColor Green

    Write-Host "  [7/8] CBOR..." -ForegroundColor Cyan
    $O_CBOR = Measure-EndpointOnce "$Optimized/books/cbor" @{"Accept"="application/cbor"}
    Write-Host "         size=$($O_CBOR.size_download) bytes" -ForegroundColor Green

    Write-Host "  [8/8] Full payload..." -ForegroundColor Cyan
    $O_FULL = Measure-EndpointOnce "$Optimized/books"
    Write-Host "         size=$($O_FULL.size_download) bytes" -ForegroundColor Green
} else {
    Write-Host "  Optimized non disponible sur le port $OptimizedPort" -ForegroundColor Red
}

Write-Host ""

###############################################################################
# STEP 3 - GREEN SCORE
###############################################################################
Write-Host "--- GREEN SCORE ---" -ForegroundColor Yellow

$scores = @{}
$details = @{}

$bf = $B_FULL.size_download; $op = $O_PAGE.size_download
if ($bf -gt 0 -and $op -gt 0 -and $op -lt $bf) {
    $ratio = 1 - ($op / $bf)
    $scores["DE11_pagination"] = [math]::Min(15, [math]::Round($ratio * 15, 1))
    $details["DE11_pagination"] = @{ baseline_bytes=$bf; optimized_bytes=$op; reduction_pct=[math]::Round($ratio*100,1) }
} elseif ($op -gt 0) { $scores["DE11_pagination"] = 8 } else { $scores["DE11_pagination"] = 0 }

$of = $O_FIELDS.size_download
if ($op -gt 0 -and $of -gt 0 -and $of -lt $op) {
    $ratio = 1 - ($of / $op)
    $scores["DE08_fields"] = [math]::Min(15, [math]::Round($ratio * 15 + 5, 1))
    $details["DE08_fields"] = @{ paginated_bytes=$op; filtered_bytes=$of; reduction_pct=[math]::Round($ratio*100,1) }
} elseif ($of -gt 0) { $scores["DE08_fields"] = 10 } else { $scores["DE08_fields"] = 0 }

$og = $O_GZIP.size_download
if ($of -gt 0 -and $og -gt 0 -and $og -lt $of) {
    $ratio = 1 - ($og / $of)
    $scores["DE01_compression"] = [math]::Min(15, [math]::Round($ratio * 15 + 3, 1))
    $details["DE01_compression"] = @{ note="gzip active" }
} elseif ($og -gt 0) { $scores["DE01_compression"] = 8 } else { $scores["DE01_compression"] = 0 }

if ($O_ETAG_304.http_code -eq 304) {
    $scores["DE02_DE03_cache"] = 15
    $details["DE02_DE03_cache"] = @{ http_code=304; note="perfect 304" }
} elseif ($O_ETAG_304.http_code -eq 200) { $scores["DE02_DE03_cache"] = 5
} else { $scores["DE02_DE03_cache"] = 0 }

if ($O_DELTA.http_code -eq 200) {
    $scores["DE06_delta"] = 8
    $details["DE06_delta"] = @{ delta_bytes=$O_DELTA.size_download }
} else { $scores["DE06_delta"] = 0 }

if ($O_RANGE.http_code -eq 206) { $scores["range_206"] = 10 }
elseif ($O_RANGE.http_code -eq 200) { $scores["range_206"] = 3 }
else { $scores["range_206"] = 0 }

if ($O_FULL.http_code -gt 0) { $scores["LO01_observability"] = 5 } else { $scores["LO01_observability"] = 0 }
if ($O_FULL.http_code -gt 0) { $scores["US07_rate_limit"] = 5 } else { $scores["US07_rate_limit"] = 0 }
if ($O_CBOR.size_download -gt 0) { $scores["AR02_format_cbor"] = 10 } else { $scores["AR02_format_cbor"] = 0 }

$total = ($scores.Values | Measure-Object -Sum).Sum
$grade = if ($total -ge 90) {"A+"} elseif ($total -ge 80) {"A"} elseif ($total -ge 65) {"B"} elseif ($total -ge 50) {"C"} elseif ($total -ge 30) {"D"} else {"E"}

###############################################################################
# STEP 3.5 - SPECTRAL LINTING (Python fallback)
###############################################################################
Write-Host ""
Write-Host "--- SPECTRAL / LINT ---" -ForegroundColor Yellow

$SpectralOut = Join-Path $ReportDir "spectral-results.json"
$SpectralIssues = @()

if ($DiscoveryOk -and (Test-Path $SpecFile)) {
    Write-Host "  Running Python-based green rule linting..." -ForegroundColor Cyan
    try {
        $lintScript = @"
import json, sys

spec = json.load(open(r'$SpecFile', 'r'))
issues = []

def add(code, path, sev, msg, rule=''):
    issues.append({'code': code, 'path': path, 'severity': sev, 'message': msg, 'rule': rule, 'source': r'$SpecFile'})

paths = spec.get('paths') or {}
info = spec.get('info', {})
if not info.get('description'):
    add('info-description', ['info'], 1, 'Le champ info.description est manquant.')
if not info.get('contact'):
    add('info-contact', ['info'], 1, 'Le champ info.contact est manquant.')

for p, ops in paths.items():
    for method in ('get', 'post', 'put', 'patch', 'delete'):
        if method not in ops:
            continue
        op = ops[method]
        op_path = ['paths', p, method]
        param_names = [pr.get('name','').lower() for pr in (op.get('parameters') or [])]

        if method == 'get' and '{' not in p:
            has_pag = any(n in param_names for n in ('page','size','limit','offset','cursor'))
            if not has_pag:
                add('green-api-pagination', op_path, 1, f'DE11 - GET {p} : collection sans pagination.', 'DE11')

        if method == 'get' and '{' not in p:
            has_fields = 'fields' in param_names or 'select' in param_names
            if not has_fields:
                add('green-api-fields-filter', op_path, 2, f'DE08 - GET {p} : pas de parametre fields.', 'DE08')

        if not op.get('description') and not op.get('summary'):
            add('green-api-operation-description', op_path, 1, f'{method.upper()} {p} : pas de description.', '')

        if method == 'get':
            resp200 = (op.get('responses') or {}).get('200', {})
            if not resp200.get('headers'):
                add('green-api-cache-headers', op_path, 2, f'DE02/DE03 - GET {p} : cache headers non documentes.', 'DE02')

        responses = op.get('responses') or {}
        if '404' not in responses and '4XX' not in responses:
            add('green-api-error-responses', op_path, 2, f'US07 - {method.upper()} {p} : reponse 404 non documentee.', 'US07')

has_delta = any('change' in p.lower() or 'delta' in p.lower() for p in paths)
if not has_delta:
    add('green-api-delta', ['paths'], 2, 'DE06 - Aucun endpoint /changes ou /delta detecte.', 'DE06')

has_binary = any('cbor' in p.lower() or 'protobuf' in p.lower() for p in paths)
if not has_binary:
    add('green-api-binary-format', ['paths'], 2, 'AR02 - Aucun endpoint avec format binaire detecte.', 'AR02')

issues.sort(key=lambda x: x['severity'])
json.dump(issues, open(r'$SpectralOut', 'w'), indent=2)
print(json.dumps({'count': len(issues)}))
"@
        $lintResult = $lintScript | python3 2>$null
        if (Test-Path $SpectralOut) {
            $SpectralIssues = Get-Content $SpectralOut -Raw | ConvertFrom-Json
            Write-Host "  Lint: $($SpectralIssues.Count) issue(s) found" -ForegroundColor Green
            foreach ($issue in ($SpectralIssues | Select-Object -First 15)) {
                $sevMap = @{ 0 = "ERR"; 1 = "WARN"; 2 = "INFO"; 3 = "HINT" }
                $sev = $sevMap[[int]$issue.severity]
                Write-Host "    [$sev] $($issue.code): $($issue.message)" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "  Lint failed: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  Spectral skipped (no spec discovered)" -ForegroundColor Yellow
}

###############################################################################
# STEP 4 - BUILD REPORT (with discovery data + spectral)
###############################################################################
# Build discovered_endpoints list for dashboard
$discList = @()
foreach ($ep in $DiscoveredEndpoints) {
    if ($ep.method -ne "GET") { continue }
    $key = "$($ep.method):$($ep.path)"
    $m = $null
    if ($O_Disc.ContainsKey($key)) { $m = $O_Disc[$key] }
    elseif ($B_Disc.ContainsKey($key)) { $m = $B_Disc[$key] }
    if ($m) {
        $discList += @{
            method = $ep.method
            path = $ep.path
            operationId = $ep.operationId
            summary = $ep.summary
            tags = @()
            http_code = $m.http_code
            size_download = $m.size_download
            time_total = $m.time_total
            speed_download = $m.speed_download
        }
    }
}

# Build all_measurements
$allMeasurements = @{}
foreach ($key in $B_Disc.Keys) { $allMeasurements[$key] = $B_Disc[$key] }
foreach ($key in $O_Disc.Keys) { $allMeasurements[$key] = $O_Disc[$key] }

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
    auto_discovery = @{
        base_url = $Optimized
        swagger_url = $SwaggerUrl
        endpoints_discovered = $DiscoveredEndpoints.Count
        endpoints_measured = $allMeasurements.Count
        all_measurements = $allMeasurements
        discovered_endpoints = $discList
    }
    spectral = @{
        issues_count = $SpectralIssues.Count
        errors = @($SpectralIssues | Where-Object { $_.severity -eq 0 }).Count
        warnings = @($SpectralIssues | Where-Object { $_.severity -eq 1 }).Count
        infos = @($SpectralIssues | Where-Object { $_.severity -ge 2 }).Count
        issues = @($SpectralIssues | Select-Object -First 100)
    }
}

$json = $report | ConvertTo-Json -Depth 6
$json | Out-File -FilePath $ReportFile -Encoding utf8
$json | Out-File -FilePath $LatestLink -Encoding utf8

# Generate badge
$badgeScript = Join-Path $RootDir "scripts\generate-badge.ps1"
if (Test-Path $badgeScript) {
    & $badgeScript $LatestLink (Join-Path $RootDir "badges\green-score.svg") | Out-Null
}

# Generate dashboard
$dashboardScript = Join-Path $RootDir "scripts\generate-dashboard.ps1"
if (Test-Path $dashboardScript) {
    & $dashboardScript $LatestLink "dashboard\index.save.html" "dashboard\index.html" | Out-Null
}

$json | Write-Host

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  GREEN SCORE: $total/100   Grade: $grade" -ForegroundColor Green
Write-Host "  Endpoints discovered: $($DiscoveredEndpoints.Count)" -ForegroundColor Green
Write-Host "  Report: $ReportFile" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan

