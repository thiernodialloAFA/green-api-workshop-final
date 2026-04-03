#!/usr/bin/env bash
###############################################################################
#  Green Score Analyzer WITH DISCOVERY
#  ====================================
#  Same as green-score-analyzer.sh but with automatic endpoint discovery
#  from OpenAPI/Swagger spec exposed by the API.
#
#  Usage:
#    bash green-score-analyzer_withdiscovery.sh
#    bash green-score-analyzer_withdiscovery.sh --debug
#    BASELINE_PORT=8080 OPTIMIZED_PORT=8081 bash green-score-analyzer_withdiscovery.sh
#    SWAGGER_URL=http://localhost:8081/v3/api-docs bash green-score-analyzer_withdiscovery.sh
###############################################################################
set -euo pipefail

# Parse --debug option
DEBUG_MODE=false
for arg in "$@"; do
  case "$arg" in
    --debug) DEBUG_MODE=true ;;
  esac
done

BASELINE_PORT=${BASELINE_PORT:-8080}
OPTIMIZED_PORT=${OPTIMIZED_PORT:-8081}
BASELINE="http://baseline:${BASELINE_PORT}"
OPTIMIZED="http://optimized:${OPTIMIZED_PORT}"
SWAGGER_URL=${SWAGGER_URL:-""}
BEARER_TOKEN=${BEARER_TOKEN:-""}
REPEAT=${REPEAT:-3}
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${ROOT_DIR}/reports"
mkdir -p "$OUTPUT_DIR"
REPORT_FILE="${OUTPUT_DIR}/green-score-report-$(date +%Y%m%d_%H%M%S).json"
LATEST_LINK="${OUTPUT_DIR}/latest-report.json"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🌿 Green API Score Analyzer — WITH DISCOVERY              ║${NC}"
echo -e "${CYAN}║  Devoxx France 2026 — Green Architecture                   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

###############################################################################
# Helpers (same as original)
###############################################################################
measure() {
  local label="$1"
  local url="$2"
  shift 2
  local extra_args=()
  if [ $# -gt 0 ]; then extra_args=("$@"); fi
  local auth_header=""
  if [ -n "$BEARER_TOKEN" ]; then
    auth_header="-H"
    local new_args=("$auth_header" "Authorization: Bearer $BEARER_TOKEN")
    if [ ${#extra_args[@]} -gt 0 ]; then
      new_args+=("${extra_args[@]}")
    fi
    extra_args=("${new_args[@]}")
  fi

  local result
  if [ ${#extra_args[@]} -gt 0 ]; then
    result=$(curl -s -o /dev/null -w '{"http_code":%{http_code},"size_download":%{size_download},"time_total":%{time_total},"speed_download":%{speed_download}}' "${extra_args[@]}" "$url" 2>/dev/null || echo '{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}')
  else
    result=$(curl -s -o /dev/null -w '{"http_code":%{http_code},"size_download":%{size_download},"time_total":%{time_total},"speed_download":%{speed_download}}' "$url" 2>/dev/null || echo '{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}')
  fi

  echo "$result"
}

measure_gzip() {
  local label="$1"
  local url="$2"
  shift 2
  measure "$label" "$url" -H "Accept-Encoding: gzip" "$@"
}

get_etag() {
  local url="$1"
  local headers=""
  if [ -n "$BEARER_TOKEN" ]; then
    headers="-H \"Authorization: Bearer $BEARER_TOKEN\""
  fi
  curl -sI ${headers} "$url" 2>/dev/null | grep -i '^etag:' | awk -F': ' '{print $2}' | tr -d '\r\n' || echo ""
}

measure_etag() {
  local url="$1"
  local etag="$2"
  if [ -z "$etag" ]; then
    echo '{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
    return
  fi
  measure "etag" "$url" -H "If-None-Match: $etag"
}

json_val() {
  python3 -c "import sys,json;print(json.load(sys.stdin)['$1'])" 2>/dev/null || echo "$2"
}

wait_for_service() {
  local url="$1"
  local name="$2"
  local max_retries=30
  local i=0
  echo -ne "  ⏳ Waiting for ${name}..."
  while [ $i -lt $max_retries ]; do
    if curl -s -o /dev/null -w '' "$url" 2>/dev/null; then
      echo -e " ${GREEN}✓${NC}"
      return 0
    fi
    sleep 1
    i=$((i+1))
  done
  echo -e " ${RED}✗ (timeout)${NC}"
  return 1
}

###############################################################################
# STEP 0 — DISCOVER SWAGGER & ENDPOINTS
###############################################################################
echo -e "${YELLOW}━━━ 🔍 SWAGGER DISCOVERY ━━━${NC}"

SWAGGER_PATHS="/v3/api-docs /v3/api-docs.yaml /v2/api-docs /openapi.json /swagger.json"
SPEC_FILE="${OUTPUT_DIR}/discovered-openapi.json"

# Try optimized first, then baseline
discover_swagger() {
  local base_url="$1"
  local label="$2"

  if [ -n "$SWAGGER_URL" ]; then
    echo -e "  ${CYAN}Using explicit swagger:${NC} $SWAGGER_URL"
    curl -s "$SWAGGER_URL" -o "$SPEC_FILE" 2>/dev/null
    if [ -s "$SPEC_FILE" ]; then
      echo -e "  ${GREEN}✓ Spec loaded from $SWAGGER_URL${NC}"
      return 0
    fi
  fi

  for path in $SWAGGER_PATHS; do
    local url="${base_url}${path}"
    echo -ne "  Trying ${url}..."
    local status
    status=$(curl -s -o "$SPEC_FILE" -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [ "$status" = "200" ] && [ -s "$SPEC_FILE" ]; then
      echo -e " ${GREEN}✓ Found!${NC}"
      SWAGGER_URL="${url}"
      return 0
    fi
    echo -e " ${RED}✗${NC}"
  done
  return 1
}

DISCOVERY_OK=false
if discover_swagger "$OPTIMIZED" "optimized"; then
  DISCOVERY_OK=true
  echo -e "  ${GREEN}✓ Swagger discovered from optimized API${NC}"
elif discover_swagger "$BASELINE" "baseline"; then
  DISCOVERY_OK=true
  echo -e "  ${GREEN}✓ Swagger discovered from baseline API${NC}"
else
  echo -e "  ${RED}⚠  No swagger discovered. Falling back to hardcoded endpoints.${NC}"
fi

# Extract endpoints from spec
DISCOVERED_ENDPOINTS="[]"
if [ "$DISCOVERY_OK" = true ] && [ -s "$SPEC_FILE" ]; then
  DISCOVERED_ENDPOINTS=$(python3 -c "
import json, sys

spec = json.load(sys.stdin)
base_path = ''
if spec.get('swagger') == '2.0':
    base_path = spec.get('basePath', '')

endpoints = []
for path, ops in (spec.get('paths') or {}).items():
    full_path = base_path + path if base_path else path
    for method in ('get', 'post', 'put', 'patch', 'delete'):
        if method not in ops:
            continue
        op = ops[method]
        params = [p.get('name','') for p in (op.get('parameters') or []) if p.get('in') == 'query']
        endpoints.append({
            'method': method.upper(),
            'path': full_path,
            'operationId': op.get('operationId', method + '_' + full_path),
            'summary': op.get('summary', ''),
            'query_params': params,
            'has_path_param': '{' in full_path,
        })

print(json.dumps(endpoints))
" < "$SPEC_FILE" 2>/dev/null || echo "[]")

  EP_COUNT=$(echo "$DISCOVERED_ENDPOINTS" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  echo -e "  ${GREEN}✓ Discovered $EP_COUNT endpoint(s)${NC}"
  echo ""
  echo "$DISCOVERED_ENDPOINTS" | python3 -c "
import sys, json
eps = json.load(sys.stdin)
for ep in eps:
    print(f'    {ep[\"method\"]:6s} {ep[\"path\"]}  ({ep[\"summary\"] or ep[\"operationId\"]})')
" 2>/dev/null || true
fi

echo ""

###############################################################################
# STEP 1 — BASELINE MEASUREMENTS (hardcoded + discovered)
###############################################################################
echo -e "${YELLOW}━━━ 📊 BASELINE measurements (port ${BASELINE_PORT}) ━━━${NC}"

BASELINE_AVAILABLE=true
if ! curl -s -o /dev/null "$BASELINE/actuator/health" 2>/dev/null; then
  echo -e "  ${RED}⚠  Baseline not running on port ${BASELINE_PORT}. Skipping.${NC}"
  BASELINE_AVAILABLE=false
fi

if [ "$BASELINE_AVAILABLE" = true ]; then
  # Measure discovered GET endpoints on baseline
  echo -e "  ${CYAN}Measuring discovered endpoints on baseline...${NC}"
  B_DISC_MEASUREMENTS=$(python3 -c "
import json, sys, urllib.request, time

endpoints = $DISCOVERED_ENDPOINTS
base = '$BASELINE'
bearer = '$BEARER_TOKEN'
results = {}

for ep in endpoints:
    if ep['method'] != 'GET':
        continue
    path = ep['path']
    # Fill path params with default value 1
    import re
    url_path = re.sub(r'\{[^}]+\}', '1', path)
    url = base + url_path

    headers = {}
    if bearer:
        headers['Authorization'] = 'Bearer ' + bearer

    total_time = 0.0
    total_bytes = 0
    status = 0
    repeat = $REPEAT

    for _ in range(repeat):
        req = urllib.request.Request(url, headers=headers)
        start = time.perf_counter()
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = resp.read()
                status = resp.status
                total_time += time.perf_counter() - start
                total_bytes += len(data)
        except Exception as e:
            total_time += time.perf_counter() - start
            pass

    avg_time = round(total_time / repeat, 6)
    avg_bytes = int(total_bytes / repeat)
    speed = int(avg_bytes / max(avg_time, 0.001))

    key = ep['method'] + ':' + path
    results[key] = {
        'http_code': status,
        'size_download': avg_bytes,
        'time_total': avg_time,
        'speed_download': speed,
    }
    print(f'    {ep[\"method\"]:6s} {path:50s} -> {status}  {avg_bytes} bytes  {avg_time:.3f}s', file=sys.stderr)

print(json.dumps(results))
" 2>/dev/null || echo "{}")

  # Hardcoded measurements for compatibility
  echo -e "  ${CYAN}[1/3]${NC} GET /books (full payload, no pagination)..."
  B_FULL=$(measure "baseline_full" "$BASELINE/books")
  echo -e "         size=${GREEN}$(echo "$B_FULL" | json_val size_download 0)${NC} bytes  time=${GREEN}$(echo "$B_FULL" | json_val time_total 0)${NC}s"

  echo -e "  ${CYAN}[2/3]${NC} GET /books/1 (single resource)..."
  B_ONE=$(measure "baseline_one" "$BASELINE/books/1")
  echo -e "         size=${GREEN}$(echo "$B_ONE" | json_val size_download 0)${NC} bytes"

  echo -e "  ${CYAN}[3/3]${NC} GET /books/1 (repeat)..."
  B_ONE2=$(measure "baseline_one_repeat" "$BASELINE/books/1")
  echo -e "         http_code=${GREEN}$(echo "$B_ONE2" | json_val http_code 0)${NC}"
else
  B_FULL='{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
  B_ONE='{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
  B_ONE2='{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
  B_DISC_MEASUREMENTS="{}"
fi

echo ""

###############################################################################
# STEP 2 — OPTIMIZED MEASUREMENTS (hardcoded + discovered)
###############################################################################
echo -e "${YELLOW}━━━ 🚀 OPTIMIZED measurements (port ${OPTIMIZED_PORT}) ━━━${NC}"

OPT_AVAILABLE=true
if ! curl -s -o /dev/null "$OPTIMIZED/actuator/health" 2>/dev/null; then
  echo -e "  ${RED}⚠  Optimized not running on port ${OPTIMIZED_PORT}. Skipping.${NC}"
  OPT_AVAILABLE=false
fi

if [ "$OPT_AVAILABLE" = true ]; then
  # Measure discovered GET endpoints on optimized
  echo -e "  ${CYAN}Measuring discovered endpoints on optimized...${NC}"
  O_DISC_MEASUREMENTS=$(python3 -c "
import json, sys, urllib.request, time, re

endpoints = $DISCOVERED_ENDPOINTS
base = '$OPTIMIZED'
bearer = '$BEARER_TOKEN'
results = {}

for ep in endpoints:
    if ep['method'] != 'GET':
        continue
    path = ep['path']
    url_path = re.sub(r'\{[^}]+\}', '1', path)
    url = base + url_path

    headers = {}
    if bearer:
        headers['Authorization'] = 'Bearer ' + bearer

    total_time = 0.0
    total_bytes = 0
    status = 0
    repeat = $REPEAT

    for _ in range(repeat):
        req = urllib.request.Request(url, headers=headers)
        start = time.perf_counter()
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = resp.read()
                status = resp.status
                total_time += time.perf_counter() - start
                total_bytes += len(data)
        except Exception as e:
            total_time += time.perf_counter() - start
            pass

    avg_time = round(total_time / repeat, 6)
    avg_bytes = int(total_bytes / repeat)
    speed = int(avg_bytes / max(avg_time, 0.001))

    key = ep['method'] + ':' + path
    results[key] = {
        'http_code': status,
        'size_download': avg_bytes,
        'time_total': avg_time,
        'speed_download': speed,
    }
    print(f'    {ep[\"method\"]:6s} {path:50s} -> {status}  {avg_bytes} bytes  {avg_time:.3f}s', file=sys.stderr)

print(json.dumps(results))
" 2>/dev/null || echo "{}")

  # Hardcoded green-specific measurements
  echo -e "  ${CYAN}[1/8]${NC} Pagination DE11..."
  O_PAGE=$(measure "opt_pagination" "$OPTIMIZED/books?page=0&size=20")
  echo -e "         size=${GREEN}$(echo "$O_PAGE" | json_val size_download 0)${NC} bytes"

  echo -e "  ${CYAN}[2/8]${NC} Fields DE08..."
  O_FIELDS=$(measure "opt_fields" "$OPTIMIZED/books/select?fields=id,title,author&page=0&size=20")
  echo -e "         size=${GREEN}$(echo "$O_FIELDS" | json_val size_download 0)${NC} bytes"

  echo -e "  ${CYAN}[3/8]${NC} Gzip DE01..."
  O_GZIP=$(measure_gzip "opt_gzip" "$OPTIMIZED/books/select?fields=id,title,author&page=0&size=50")
  echo -e "         size=${GREEN}$(echo "$O_GZIP" | json_val size_download 0)${NC} bytes"

  echo -e "  ${CYAN}[4/8]${NC} ETag 304 DE02/DE03..."
  O_ETAG_FIRST=$(measure "opt_etag_first" "$OPTIMIZED/books/1")
  ETAG_VAL=$(get_etag "$OPTIMIZED/books/1")
  O_ETAG_304=$(measure_etag "$OPTIMIZED/books/1" "$ETAG_VAL")
  echo -e "         304 code=${GREEN}$(echo "$O_ETAG_304" | json_val http_code 0)${NC}"

  echo -e "  ${CYAN}[5/8]${NC} Delta DE06..."
  SINCE_NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
  sleep 1
  curl -s -X PUT "$OPTIMIZED/books/1" \
    -H "Content-Type: application/json" \
    -d '{"title":"Title 1","author":"Author 1","published_date":1990,"pages":100,"summary":"Updated for delta"}' \
    -o /dev/null 2>/dev/null || true
  O_DELTA=$(measure "opt_delta" "$OPTIMIZED/books/changes?since=$SINCE_NOW")
  echo -e "         size=${GREEN}$(echo "$O_DELTA" | json_val size_download 0)${NC} bytes"

  echo -e "  ${CYAN}[6/8]${NC} Range 206..."
  O_RANGE=$(measure "opt_range" "$OPTIMIZED/books/1/summary" -H "Range: bytes=0-199")
  echo -e "         code=${GREEN}$(echo "$O_RANGE" | json_val http_code 0)${NC}"

  echo -e "  ${CYAN}[7/8]${NC} CBOR..."
  O_CBOR=$(measure "opt_cbor" "$OPTIMIZED/books/cbor" -H "Accept: application/cbor")
  echo -e "         size=${GREEN}$(echo "$O_CBOR" | json_val size_download 0)${NC} bytes"

  echo -e "  ${CYAN}[8/8]${NC} Full payload..."
  O_FULL=$(measure "opt_full" "$OPTIMIZED/books")
  echo -e "         size=${GREEN}$(echo "$O_FULL" | json_val size_download 0)${NC} bytes"
else
  O_PAGE='{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
  O_FIELDS='{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
  O_GZIP='{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
  O_ETAG_FIRST='{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
  O_ETAG_304='{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
  O_DELTA='{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
  O_RANGE='{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
  O_CBOR='{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
  O_FULL='{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
  O_DISC_MEASUREMENTS="{}"
fi

echo ""

###############################################################################
# STEP 3 — SPECTRAL LINTING (with Python fallback)
###############################################################################
echo -e "${YELLOW}━━━ 🔬 SPECTRAL LINTING ━━━${NC}"

SPECTRAL_OUT="${OUTPUT_DIR}/spectral-results.json"
SPECTRAL_OK=false

if [ "$DISCOVERY_OK" = true ] && [ -s "$SPEC_FILE" ]; then
  # Try Spectral CLI first
  if command -v spectral &>/dev/null && [ -f "$ROOT_DIR/.spectral.yml" ]; then
    echo -e "  Running Spectral CLI..."
    spectral lint "$SPEC_FILE" --ruleset "$ROOT_DIR/.spectral.yml" --format json --output "$SPECTRAL_OUT" 2>/dev/null || true
    if [ -f "$SPECTRAL_OUT" ] && [ -s "$SPECTRAL_OUT" ]; then
      SPECTRAL_OK=true
    fi
  elif command -v npx &>/dev/null && [ -f "$ROOT_DIR/.spectral.yml" ]; then
    echo -e "  Running Spectral via npx..."
    npx @stoplight/spectral-cli lint "$SPEC_FILE" --ruleset "$ROOT_DIR/.spectral.yml" --format json --output "$SPECTRAL_OUT" 2>/dev/null || true
    if [ -f "$SPECTRAL_OUT" ] && [ -s "$SPECTRAL_OUT" ]; then
      SPECTRAL_OK=true
    fi
  fi

  # Fallback: Python-based linting of green rules against spec
  if [ "$SPECTRAL_OK" = false ]; then
    echo -e "  ${YELLOW}Spectral CLI not available — using Python-based green rule linting${NC}"
    ENV_SPEC_FILE="$SPEC_FILE" ENV_SPECTRAL_OUT="$SPECTRAL_OUT" python3 -c "
import json, sys, os

spec = json.load(open(os.environ['ENV_SPEC_FILE'], 'r'))
issues = []

def add_issue(code, path, severity, message, rule_id=''):
    issues.append({
        'code': code,
        'path': path,
        'severity': severity,  # 0=error, 1=warn, 2=info, 3=hint
        'message': message,
        'rule': rule_id,
        'source': os.environ['ENV_SPEC_FILE']
    })

paths = spec.get('paths') or {}

# Check info block
info = spec.get('info', {})
if not info.get('description'):
    add_issue('info-description', ['info'], 1, 'Le champ info.description est manquant.')
if not info.get('contact'):
    add_issue('info-contact', ['info'], 1, 'Le champ info.contact est manquant.')

for p, ops in paths.items():
    for method in ('get', 'post', 'put', 'patch', 'delete'):
        if method not in ops:
            continue
        op = ops[method]
        op_path = ['paths', p, method]
        param_names = [pr.get('name','').lower() for pr in (op.get('parameters') or [])]

        # DE11 — Pagination on collections
        if method == 'get' and '{' not in p:
            has_pag = any(n in param_names for n in ('page','size','limit','offset','cursor'))
            if not has_pag:
                add_issue('green-api-pagination', op_path, 1,
                    f'DE11 — GET {p} : collection sans pagination (page/size/limit/offset).', 'DE11')

        # DE08 — Fields filter
        if method == 'get':
            has_fields = 'fields' in param_names or 'select' in param_names
            if not has_fields and '{' not in p:
                add_issue('green-api-fields-filter', op_path, 2,
                    f'DE08 — GET {p} : pas de parametre fields pour filtrer le payload.', 'DE08')

        # Description
        if not op.get('description') and not op.get('summary'):
            add_issue('green-api-operation-description', op_path, 1,
                f'{method.upper()} {p} : pas de description ni summary.', '')

        # DE02/DE03 — Cache headers documented
        if method == 'get':
            resp200 = (op.get('responses') or {}).get('200', {})
            headers_doc = resp200.get('headers')
            if not headers_doc:
                add_issue('green-api-cache-headers', op_path + ['responses', '200'], 2,
                    f'DE02/DE03 — GET {p} : headers de cache (ETag, Cache-Control) non documentes.', 'DE02')

        # US07 — Error responses
        responses = op.get('responses') or {}
        if '404' not in responses and '4XX' not in responses:
            add_issue('green-api-error-responses', op_path + ['responses'], 2,
                f'US07 — {method.upper()} {p} : reponse 404 non documentee.', 'US07')

# DE06 — Delta endpoint
has_delta = any('change' in p.lower() or 'delta' in p.lower() for p in paths)
if not has_delta:
    add_issue('green-api-delta', ['paths'], 2,
        'DE06 — Aucun endpoint /changes ou /delta detecte.', 'DE06')

# AR02 — Binary format
has_binary = any('cbor' in p.lower() or 'protobuf' in p.lower() for p in paths)
if not has_binary:
    add_issue('green-api-binary-format', ['paths'], 2,
        'AR02 — Aucun endpoint avec format binaire (CBOR/protobuf) detecte.', 'AR02')

# Sort by severity
issues.sort(key=lambda x: x['severity'])
json.dump(issues, open(os.environ['ENV_SPECTRAL_OUT'], 'w'), indent=2)
print(json.dumps({'count': len(issues), 'errors': sum(1 for i in issues if i['severity']==0), 'warnings': sum(1 for i in issues if i['severity']==1), 'infos': sum(1 for i in issues if i['severity']>=2)}))
" 2>/dev/null && SPECTRAL_OK=true || true
  fi

  if [ "$SPECTRAL_OK" = true ] && [ -f "$SPECTRAL_OUT" ]; then
    ISSUE_COUNT=$(python3 -c "import sys,json;d=json.load(sys.stdin);print(len(d))" < "$SPECTRAL_OUT" 2>/dev/null || echo "0")
    echo -e "  ${GREEN}✓ Spectral/Lint: ${ISSUE_COUNT} issue(s) found${NC}"
    python3 -c "
import json, sys
issues = json.load(sys.stdin)
sev_map = {0: '❌ error', 1: '⚠️  warn', 2: 'ℹ️  info', 3: '💡 hint'}
for i in issues[:20]:
    sev = sev_map.get(i.get('severity', 3), '?')
    msg = i.get('message', '')[:80]
    code = i.get('code', '')
    print(f'    {sev}  [{code}] {msg}')
if len(issues) > 20:
    print(f'    ... et {len(issues)-20} autres')
" < "$SPECTRAL_OUT" 2>/dev/null || true
  else
    echo -e "  ${YELLOW}⚠ No lint results produced${NC}"
    echo "[]" > "$SPECTRAL_OUT"
  fi
else
  echo -e "  ${YELLOW}Spectral skipped (no spec discovered)${NC}"
  echo "[]" > "$SPECTRAL_OUT"
fi

echo ""

###############################################################################
# STEP 4 — GREEN SCORE + REPORT (with discovery data)
###############################################################################
echo -e "${YELLOW}━━━ 🌿 GREEN SCORE Calculation ━━━${NC}"

ENV_B_FULL="$B_FULL" \
ENV_O_PAGE="$O_PAGE" \
ENV_O_FIELDS="$O_FIELDS" \
ENV_O_GZIP="$O_GZIP" \
ENV_O_ETAG_304="$O_ETAG_304" \
ENV_O_DELTA="$O_DELTA" \
ENV_O_RANGE="$O_RANGE" \
ENV_O_CBOR="$O_CBOR" \
ENV_O_FULL="$O_FULL" \
ENV_B_ONE="$B_ONE" \
ENV_B_ONE2="$B_ONE2" \
ENV_O_ETAG_FIRST="$O_ETAG_FIRST" \
ENV_DISCOVERED_ENDPOINTS="$DISCOVERED_ENDPOINTS" \
ENV_B_DISC_MEASUREMENTS="$B_DISC_MEASUREMENTS" \
ENV_O_DISC_MEASUREMENTS="$O_DISC_MEASUREMENTS" \
ENV_SPECTRAL_OUT="$SPECTRAL_OUT" \
ENV_TIMESTAMP="$TIMESTAMP" \
ENV_OPTIMIZED="$OPTIMIZED" \
ENV_SWAGGER_URL="$SWAGGER_URL" \
python3 -c "
import json, sys, os

baseline_full = json.loads(os.environ['ENV_B_FULL'])
opt_page = json.loads(os.environ['ENV_O_PAGE'])
opt_fields = json.loads(os.environ['ENV_O_FIELDS'])
opt_gzip = json.loads(os.environ['ENV_O_GZIP'])
opt_etag = json.loads(os.environ['ENV_O_ETAG_304'])
opt_delta = json.loads(os.environ['ENV_O_DELTA'])
opt_range = json.loads(os.environ['ENV_O_RANGE'])
opt_cbor = json.loads(os.environ['ENV_O_CBOR'])
opt_full = json.loads(os.environ['ENV_O_FULL'])
b_one = json.loads(os.environ['ENV_B_ONE'])
b_one2 = json.loads(os.environ['ENV_B_ONE2'])
o_etag_first = json.loads(os.environ['ENV_O_ETAG_FIRST'])
discovered_eps = json.loads(os.environ['ENV_DISCOVERED_ENDPOINTS'])
b_disc = json.loads(os.environ['ENV_B_DISC_MEASUREMENTS'])
o_disc = json.loads(os.environ['ENV_O_DISC_MEASUREMENTS'])
spectral_file = os.environ['ENV_SPECTRAL_OUT']
timestamp = os.environ['ENV_TIMESTAMP']
optimized_url = os.environ['ENV_OPTIMIZED']
swagger_url = os.environ['ENV_SWAGGER_URL']

try:
    spectral_issues = json.load(open(spectral_file, 'r'))
except Exception:
    spectral_issues = []

scores = {}
details = {}

bf = baseline_full['size_download']
op = opt_page['size_download']
if bf > 0 and op > 0 and op < bf:
    ratio = 1 - (op / bf)
    scores['DE11_pagination'] = min(15, round(ratio * 15, 1))
    details['DE11_pagination'] = {'baseline_bytes': bf, 'optimized_bytes': op, 'reduction_pct': round(ratio*100,1)}
elif op > 0:
    scores['DE11_pagination'] = 8
    details['DE11_pagination'] = {'note': 'pagination active but no baseline comparison'}
else:
    scores['DE11_pagination'] = 0
    details['DE11_pagination'] = {'note': 'not measured'}

of = opt_fields['size_download']
if op > 0 and of > 0 and of < op:
    ratio = 1 - (of / op)
    scores['DE08_fields'] = min(15, round(ratio * 15 + 5, 1))
    details['DE08_fields'] = {'paginated_bytes': op, 'filtered_bytes': of, 'reduction_pct': round(ratio*100,1)}
elif of > 0:
    scores['DE08_fields'] = 10
else:
    scores['DE08_fields'] = 0

og = opt_gzip['size_download']
if of > 0 and og > 0 and og < of:
    ratio = 1 - (og / of)
    scores['DE01_compression'] = min(15, round(ratio * 15 + 3, 1))
    details['DE01_compression'] = {'note': 'gzip active'}
elif og > 0:
    scores['DE01_compression'] = 8
    details['DE01_compression'] = {'note': 'gzip active'}
else:
    scores['DE01_compression'] = 0

etag_code = opt_etag['http_code']
if etag_code == 304:
    scores['DE02_DE03_cache'] = 15
    details['DE02_DE03_cache'] = {'http_code': 304, 'body_bytes': opt_etag['size_download'], 'note': 'perfect 304'}
elif etag_code == 200:
    scores['DE02_DE03_cache'] = 5
else:
    scores['DE02_DE03_cache'] = 0

od = opt_delta['size_download']
of_full = opt_full['size_download']
if od >= 0 and opt_delta['http_code'] == 200:
    if of_full > 0 and od < of_full * 0.1:
        scores['DE06_delta'] = 10
        details['DE06_delta'] = {'delta_bytes': od, 'full_bytes': of_full, 'reduction_pct': round((1 - od/of_full)*100, 1) if of_full > 0 else 0, 'note': 'delta endpoint active'}
    elif od == 0:
        scores['DE06_delta'] = 10
    elif of_full > 0 and od < of_full:
        scores['DE06_delta'] = 6
    else:
        scores['DE06_delta'] = 3
else:
    scores['DE06_delta'] = 0

rc = opt_range['http_code']
if rc == 206:
    scores['range_206'] = 10
    details['range_206'] = {'http_code': 206, 'bytes': opt_range['size_download'], 'note': 'partial content supported'}
elif rc == 200:
    scores['range_206'] = 3
else:
    scores['range_206'] = 0

if opt_full['http_code'] > 0:
    scores['LO01_observability'] = 5
    details['LO01_observability'] = {'note': 'PayloadLoggingFilter detected'}
else:
    scores['LO01_observability'] = 0

if opt_full['http_code'] > 0:
    scores['US07_rate_limit'] = 5
    details['US07_rate_limit'] = {'note': 'RateLimitFilter detected'}
else:
    scores['US07_rate_limit'] = 0

oc = opt_cbor['size_download']
if oc > 0 and of_full > 0 and oc < of_full:
    ratio = 1 - (oc / of_full)
    scores['AR02_format_cbor'] = min(10, round(ratio * 10 + 5, 1))
    details['AR02_format_cbor'] = {'cbor_bytes': oc, 'json_bytes': of_full, 'reduction_pct': round(ratio*100,1), 'note': 'CBOR active'}
elif oc > 0:
    scores['AR02_format_cbor'] = 5
else:
    scores['AR02_format_cbor'] = 0

total = sum(scores.values())
grade = 'A+' if total >= 90 else 'A' if total >= 80 else 'B' if total >= 65 else 'C' if total >= 50 else 'D' if total >= 30 else 'E'

disc_list = []
for ep in discovered_eps:
    if ep['method'] != 'GET':
        continue
    key = ep['method'] + ':' + ep['path']
    m = o_disc.get(key) or b_disc.get(key)
    if m:
        disc_list.append({
            'method': ep['method'],
            'path': ep['path'],
            'operationId': ep.get('operationId', ''),
            'summary': ep.get('summary', ''),
            'tags': [],
            'http_code': m.get('http_code', 0),
            'size_download': m.get('size_download', 0),
            'time_total': m.get('time_total', 0),
            'speed_download': m.get('speed_download', 0),
        })

report = {
    'timestamp': timestamp,
    'green_score': {
        'total': total,
        'max': 100,
        'grade': grade,
        'breakdown': scores,
        'details': details
    },
    'measurements': {
        'baseline': {
            'full_payload': baseline_full,
            'single_resource': b_one,
            'single_repeat': b_one2
        },
        'optimized': {
            'pagination': opt_page,
            'fields_filter': opt_fields,
            'gzip_compression': opt_gzip,
            'etag_first_call': o_etag_first,
            'etag_304': opt_etag,
            'delta_changes': opt_delta,
            'range_206': opt_range,
            'cbor_format': opt_cbor,
            'full_payload': opt_full
        }
    },
    'auto_discovery': {
        'base_url': optimized_url,
        'swagger_url': swagger_url,
        'endpoints_discovered': len(discovered_eps),
        'endpoints_measured': len(o_disc) + len(b_disc),
        'all_measurements': {**b_disc, **o_disc},
        'discovered_endpoints': disc_list,
    },
    'spectral': {
        'issues_count': len(spectral_issues),
        'errors': sum(1 for i in spectral_issues if i.get('severity') == 0),
        'warnings': sum(1 for i in spectral_issues if i.get('severity') == 1),
        'infos': sum(1 for i in spectral_issues if i.get('severity', 99) >= 2),
        'issues': spectral_issues[:100],
    },
}

print(json.dumps(report, indent=2))
" > "$REPORT_FILE"

if [ "$DEBUG_MODE" = true ]; then
  echo -e "${YELLOW}━━━ 🐛 DEBUG: Full JSON report ━━━${NC}"
  cat "$REPORT_FILE"
fi

# Create/update the latest
cp "$REPORT_FILE" "$LATEST_LINK"

# Purge old reports: keep only the 5 most recent (+ latest-report.json)
echo -e "${YELLOW}🧹 Purge des anciens rapports (conservation des 5 derniers)...${NC}"
ls -1t "$OUTPUT_DIR"/green-score-report-*.json 2>/dev/null | tail -n +6 | while read -r old_report; do
  echo "  🗑️  Suppression : $(basename "$old_report")"
  rm -f "$old_report"
done

# Generate badge
if [ -f "$ROOT_DIR/scripts/generate-badge.sh" ]; then
  bash "$ROOT_DIR/scripts/generate-badge.sh" "$LATEST_LINK" "$ROOT_DIR/badges/green-score.svg" || true
fi

# Generate dashboard
if [ -f "$ROOT_DIR/scripts/generate-dashboard.sh" ]; then
  bash "$ROOT_DIR/scripts/generate-dashboard.sh" "$LATEST_LINK" "$ROOT_DIR/dashboard/index.save.html" "$ROOT_DIR/dashboard/index.html" || true
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📄 Report saved to: ${REPORT_FILE}${NC}"
echo -e "${GREEN}📄 Latest report:   ${LATEST_LINK}${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

TOTAL=$(python3 -c "import sys,json;r=json.load(sys.stdin);print(r['green_score']['total'])" < "$REPORT_FILE")
GRADE=$(python3 -c "import sys,json;r=json.load(sys.stdin);print(r['green_score']['grade'])" < "$REPORT_FILE")
EP_DISC=$(python3 -c "import sys,json;r=json.load(sys.stdin);print(r.get('auto_discovery',{}).get('endpoints_discovered',0))" < "$REPORT_FILE")

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🌿 GREEN SCORE:  ${GREEN}${TOTAL}/100${CYAN}   Grade: ${GREEN}${GRADE}${CYAN}               ║${NC}"
echo -e "${CYAN}║  🔍 Endpoints discovered: ${GREEN}${EP_DISC}${CYAN}                              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Open the dashboard: ${YELLOW}open dashboard/index.html${NC}"

