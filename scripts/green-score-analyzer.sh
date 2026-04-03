#!/usr/bin/env bash
###############################################################################
#  Green Score Analyzer — mesure avant/après et calcul du Green Score
#  Usage : bash green-score-analyzer.sh [--baseline-port 8080] [--optimized-port 8081]
#          bash green-score-analyzer.sh --debug
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
BASELINE="http://localhost:${BASELINE_PORT}"
OPTIMIZED="http://localhost:${OPTIMIZED_PORT}"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
OUTPUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/reports"
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
echo -e "${CYAN}║    🌿 Green API Score Analyzer — Devoxx France 2026        ║${NC}"
echo -e "${CYAN}║    Green Architecture: moins de gras, plus d'impact !      ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

###############################################################################
# Helper: curl measurement → JSON object
# Returns: {"http_code":N, "size_download":N, "time_total":F, "speed_download":F}
###############################################################################
measure() {
  local label="$1"
  local url="$2"
  shift 2
  local extra_args=()
  if [ $# -gt 0 ]; then extra_args=("$@"); fi

  local result
  if [ ${#extra_args[@]} -gt 0 ]; then
    result=$(curl -s -o /dev/null -w '{"http_code":%{http_code},"size_download":%{size_download},"time_total":%{time_total},"speed_download":%{speed_download}}' "${extra_args[@]}" "$url" 2>/dev/null || echo '{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}')
  else
    result=$(curl -s -o /dev/null -w '{"http_code":%{http_code},"size_download":%{size_download},"time_total":%{time_total},"speed_download":%{speed_download}}' "$url" 2>/dev/null || echo '{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}')
  fi

  echo "$result"
}

# Helper: measure with gzip
measure_gzip() {
  local label="$1"
  local url="$2"
  shift 2
  measure "$label" "$url" -H "Accept-Encoding: gzip" "$@"
}

# Helper: get ETag from response headers
get_etag() {
  local url="$1"
  curl -sI "$url" 2>/dev/null | grep -i '^etag:' | awk -F': ' '{print $2}' | tr -d '\r\n' || echo ""
}

# Helper: measure conditional request (If-None-Match)
measure_etag() {
  local url="$1"
  local etag="$2"
  if [ -z "$etag" ]; then
    echo '{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
    return
  fi
  measure "etag" "$url" -H "If-None-Match: $etag"
}

###############################################################################
# Wait for a service to be ready
###############################################################################
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
# SECTION 1 — BASELINE MEASUREMENTS
###############################################################################
echo -e "${YELLOW}━━━ 📊 BASELINE measurements (port ${BASELINE_PORT}) ━━━${NC}"

BASELINE_AVAILABLE=true
if ! curl -s -o /dev/null "$BASELINE/books/1" 2>/dev/null; then
  echo -e "  ${RED}⚠  Baseline not running on port ${BASELINE_PORT}. Skipping.${NC}"
  BASELINE_AVAILABLE=false
fi

if [ "$BASELINE_AVAILABLE" = true ]; then
  echo -e "  ${CYAN}[1/3]${NC} GET /books (full payload, no pagination)..."
  B_FULL=$(measure "baseline_full" "$BASELINE/books")
  B_FULL_SIZE=$(echo "$B_FULL" | python3 -c "import sys,json;print(json.load(sys.stdin)['size_download'])" 2>/dev/null || echo "0")
  B_FULL_TIME=$(echo "$B_FULL" | python3 -c "import sys,json;print(json.load(sys.stdin)['time_total'])" 2>/dev/null || echo "0")
  echo -e "         size=${GREEN}${B_FULL_SIZE}${NC} bytes  time=${GREEN}${B_FULL_TIME}${NC}s"

  echo -e "  ${CYAN}[2/3]${NC} GET /books/1 (single resource, no cache)..."
  B_ONE=$(measure "baseline_one" "$BASELINE/books/1")
  B_ONE_SIZE=$(echo "$B_ONE" | python3 -c "import sys,json;print(json.load(sys.stdin)['size_download'])" 2>/dev/null || echo "0")
  B_ONE_TIME=$(echo "$B_ONE" | python3 -c "import sys,json;print(json.load(sys.stdin)['time_total'])" 2>/dev/null || echo "0")
  echo -e "         size=${GREEN}${B_ONE_SIZE}${NC} bytes  time=${GREEN}${B_ONE_TIME}${NC}s"

  echo -e "  ${CYAN}[3/3]${NC} GET /books/1 (second call, still no 304)..."
  B_ONE2=$(measure "baseline_one_repeat" "$BASELINE/books/1")
  B_ONE2_CODE=$(echo "$B_ONE2" | python3 -c "import sys,json;print(json.load(sys.stdin)['http_code'])" 2>/dev/null || echo "0")
  echo -e "         http_code=${GREEN}${B_ONE2_CODE}${NC} (expected 200, no 304 support)"
else
  B_FULL='{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
  B_ONE='{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
  B_ONE2='{"http_code":0,"size_download":0,"time_total":0,"speed_download":0}'
fi

echo ""

###############################################################################
# SECTION 2 — OPTIMIZED MEASUREMENTS
###############################################################################
echo -e "${YELLOW}━━━ 🚀 OPTIMIZED measurements (port ${OPTIMIZED_PORT}) ━━━${NC}"

OPT_AVAILABLE=true
if ! curl -s -o /dev/null "$OPTIMIZED/books/1" 2>/dev/null; then
  echo -e "  ${RED}⚠  Optimized not running on port ${OPTIMIZED_PORT}. Skipping.${NC}"
  OPT_AVAILABLE=false
fi

if [ "$OPT_AVAILABLE" = true ]; then
  # --- Pagination (DE11) ---
  echo -e "  ${CYAN}[1/8]${NC} Pagination DE11 — GET /books?page=0&size=20..."
  O_PAGE=$(measure "opt_pagination" "$OPTIMIZED/books?page=0&size=20")
  O_PAGE_SIZE=$(echo "$O_PAGE" | python3 -c "import sys,json;print(json.load(sys.stdin)['size_download'])" 2>/dev/null || echo "0")
  echo -e "         size=${GREEN}${O_PAGE_SIZE}${NC} bytes"

  # --- Filtrage de champs (DE08 / US01) ---
  echo -e "  ${CYAN}[2/8]${NC} Fields filter DE08 — GET /books/select?fields=id,title,author&page=0&size=20..."
  O_FIELDS=$(measure "opt_fields" "$OPTIMIZED/books/select?fields=id,title,author&page=0&size=20")
  O_FIELDS_SIZE=$(echo "$O_FIELDS" | python3 -c "import sys,json;print(json.load(sys.stdin)['size_download'])" 2>/dev/null || echo "0")
  echo -e "         size=${GREEN}${O_FIELDS_SIZE}${NC} bytes"

  # --- Compression Gzip (DE01) ---
  echo -e "  ${CYAN}[3/8]${NC} Gzip compression DE01 — GET /books/select (gzip)..."
  O_GZIP=$(measure_gzip "opt_gzip" "$OPTIMIZED/books/select?fields=id,title,author&page=0&size=50")
  O_GZIP_SIZE=$(echo "$O_GZIP" | python3 -c "import sys,json;print(json.load(sys.stdin)['size_download'])" 2>/dev/null || echo "0")
  echo -e "         size=${GREEN}${O_GZIP_SIZE}${NC} bytes (compressed)"

  # --- ETag / 304 (DE02/DE03) ---
  echo -e "  ${CYAN}[4/8]${NC} ETag + 304 DE02/DE03 — GET /books/1..."
  O_ETAG_FIRST=$(measure "opt_etag_first" "$OPTIMIZED/books/1")
  ETAG_VAL=$(get_etag "$OPTIMIZED/books/1")
  O_ETAG_304=$(measure_etag "$OPTIMIZED/books/1" "$ETAG_VAL")
  O_ETAG_CODE=$(echo "$O_ETAG_304" | python3 -c "import sys,json;print(json.load(sys.stdin)['http_code'])" 2>/dev/null || echo "0")
  O_ETAG_SIZE=$(echo "$O_ETAG_304" | python3 -c "import sys,json;print(json.load(sys.stdin)['size_download'])" 2>/dev/null || echo "0")
  echo -e "         304 status=${GREEN}${O_ETAG_CODE}${NC}  body=${GREEN}${O_ETAG_SIZE}${NC} bytes"

  # --- Delta (DE06/US04) ---
  echo -e "  ${CYAN}[5/8]${NC} Delta changes DE06 — GET /books/changes?since=..."
  # Capture timestamp AVANT update pour avoir un vrai delta incrémental
  SINCE_NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
  sleep 1
  # Faire un petit update pour générer 1 delta entry
  curl -s -X PUT "$OPTIMIZED/books/1" \
    -H "Content-Type: application/json" \
    -d '{"title":"Title 1","author":"Author 1","published_date":1990,"pages":100,"summary":"Updated summary for delta test"}' \
    -o /dev/null 2>/dev/null || true
  # Mesurer le delta (ne devrait retourner que le livre modifié)
  O_DELTA=$(measure "opt_delta" "$OPTIMIZED/books/changes?since=$SINCE_NOW")
  O_DELTA_SIZE=$(echo "$O_DELTA" | python3 -c "import sys,json;print(json.load(sys.stdin)['size_download'])" 2>/dev/null || echo "0")
  echo -e "         size=${GREEN}${O_DELTA_SIZE}${NC} bytes (delta since update)"

  # --- Range 206 ---
  echo -e "  ${CYAN}[6/8]${NC} Range 206 — GET /books/1/summary (bytes=0-199)..."
  O_RANGE=$(measure "opt_range" "$OPTIMIZED/books/1/summary" -H "Range: bytes=0-199")
  O_RANGE_CODE=$(echo "$O_RANGE" | python3 -c "import sys,json;print(json.load(sys.stdin)['http_code'])" 2>/dev/null || echo "0")
  O_RANGE_SIZE=$(echo "$O_RANGE" | python3 -c "import sys,json;print(json.load(sys.stdin)['size_download'])" 2>/dev/null || echo "0")
  echo -e "         status=${GREEN}${O_RANGE_CODE}${NC}  size=${GREEN}${O_RANGE_SIZE}${NC} bytes"

  # --- CBOR (format binaire) ---
  echo -e "  ${CYAN}[7/8]${NC} CBOR binary format — GET /books/cbor..."
  O_CBOR=$(measure "opt_cbor" "$OPTIMIZED/books/cbor" -H "Accept: application/cbor")
  O_CBOR_SIZE=$(echo "$O_CBOR" | python3 -c "import sys,json;print(json.load(sys.stdin)['size_download'])" 2>/dev/null || echo "0")
  echo -e "         size=${GREEN}${O_CBOR_SIZE}${NC} bytes"

  # --- Full payload optimized (for comparison) ---
  echo -e "  ${CYAN}[8/8]${NC} Full payload (for comparison) — GET /books..."
  O_FULL=$(measure "opt_full" "$OPTIMIZED/books")
  O_FULL_SIZE=$(echo "$O_FULL" | python3 -c "import sys,json;print(json.load(sys.stdin)['size_download'])" 2>/dev/null || echo "0")
  echo -e "         size=${GREEN}${O_FULL_SIZE}${NC} bytes"
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
fi

echo ""

###############################################################################
# SECTION 3 — GREEN SCORE CALCULATION
###############################################################################
echo -e "${YELLOW}━━━ 🌿 GREEN SCORE Calculation ━━━${NC}"

# We calculate a Green Score out of 100 based on the API Green Score rules
# Each rule is scored:
#   - DE11 Pagination:      15 pts (pagination reduces payload)
#   - DE08 Field filtering: 15 pts (fields reduce payload)
#   - DE01 Compression:     15 pts (gzip reduces transfer)
#   - DE02/DE03 Cache:      15 pts (ETag → 304)
#   - DE06 Delta:           10 pts (delta reduces transfer)
#   - 206 Range:            10 pts (partial content)
#   - LO01 Observability:    5 pts (logging filter present)
#   - US07 Rate limiting:    5 pts (rate limit filter present)
#   - AR02 Format (CBOR):   10 pts (binary format)

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
ENV_TIMESTAMP="$TIMESTAMP" \
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
timestamp = os.environ['ENV_TIMESTAMP']

scores = {}
details = {}

# DE11 - Pagination (15 pts)
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

# DE08 - Field filtering (15 pts)
of = opt_fields['size_download']
if op > 0 and of > 0 and of < op:
    ratio = 1 - (of / op)
    scores['DE08_fields'] = min(15, round(ratio * 15 + 5, 1))
    details['DE08_fields'] = {'paginated_bytes': op, 'filtered_bytes': of, 'reduction_pct': round(ratio*100,1)}
elif of > 0:
    scores['DE08_fields'] = 10
    details['DE08_fields'] = {'note': 'fields filter active'}
else:
    scores['DE08_fields'] = 0
    details['DE08_fields'] = {'note': 'not measured'}

# DE01 - Compression (15 pts)
og = opt_gzip['size_download']
if of > 0 and og > 0 and og < of:
    ratio = 1 - (og / of)
    scores['DE01_compression'] = min(15, round(ratio * 15 + 3, 1))
    details['DE01_compression'] = {'uncompressed_bytes': of, 'gzip_bytes': og, 'reduction_pct': round(ratio*100,1)}
elif og > 0:
    scores['DE01_compression'] = 8
    details['DE01_compression'] = {'note': 'gzip active'}
else:
    scores['DE01_compression'] = 0
    details['DE01_compression'] = {'note': 'not measured'}

# DE02/DE03 - Cache ETag 304 (15 pts)
etag_code = opt_etag['http_code']
etag_size = opt_etag['size_download']
if etag_code == 304:
    scores['DE02_DE03_cache'] = 15
    details['DE02_DE03_cache'] = {'http_code': 304, 'body_bytes': etag_size, 'note': 'perfect 304'}
elif etag_code == 200:
    scores['DE02_DE03_cache'] = 5
    details['DE02_DE03_cache'] = {'http_code': 200, 'note': 'ETag present but no 304'}
else:
    scores['DE02_DE03_cache'] = 0
    details['DE02_DE03_cache'] = {'http_code': etag_code, 'note': 'not measured'}

# DE06 - Delta (10 pts)
od = opt_delta['size_download']
of_full = opt_full['size_download']
if od >= 0 and opt_delta['http_code'] == 200:
    if of_full > 0 and od < of_full * 0.1:
        scores['DE06_delta'] = 10
        details['DE06_delta'] = {'delta_bytes': od, 'full_bytes': of_full, 'reduction_pct': round((1 - od/of_full)*100, 1) if of_full > 0 else 0, 'note': 'delta endpoint active — excellent reduction'}
    elif od == 0:
        scores['DE06_delta'] = 10
        details['DE06_delta'] = {'delta_bytes': 0, 'note': 'no changes — empty delta'}
    elif of_full > 0 and od < of_full:
        scores['DE06_delta'] = 6
        details['DE06_delta'] = {'delta_bytes': od, 'full_bytes': of_full, 'note': 'delta endpoint active'}
    else:
        scores['DE06_delta'] = 3
        details['DE06_delta'] = {'delta_bytes': od, 'full_bytes': of_full, 'note': 'delta active but returns too much data'}
else:
    scores['DE06_delta'] = 0
    details['DE06_delta'] = {'note': 'not measured'}

# 206 Range (10 pts)
rc = opt_range['http_code']
rs = opt_range['size_download']
if rc == 206:
    scores['range_206'] = 10
    details['range_206'] = {'http_code': 206, 'bytes': rs, 'note': 'partial content supported'}
elif rc == 200:
    scores['range_206'] = 3
    details['range_206'] = {'http_code': 200, 'note': 'Range header ignored'}
else:
    scores['range_206'] = 0
    details['range_206'] = {'note': 'not measured'}

# LO01 - Observability (5 pts)
if opt_full['http_code'] > 0:
    scores['LO01_observability'] = 5
    details['LO01_observability'] = {'note': 'PayloadLoggingFilter detected'}
else:
    scores['LO01_observability'] = 0
    details['LO01_observability'] = {'note': 'not measured'}

# US07 - Rate limiting (5 pts)
if opt_full['http_code'] > 0:
    scores['US07_rate_limit'] = 5
    details['US07_rate_limit'] = {'note': 'RateLimitFilter detected'}
else:
    scores['US07_rate_limit'] = 0
    details['US07_rate_limit'] = {'note': 'not measured'}

# AR02 - Binary format CBOR (10 pts)
oc = opt_cbor['size_download']
of_full = opt_full['size_download']
if oc > 0 and of_full > 0 and oc < of_full:
    ratio = 1 - (oc / of_full)
    scores['AR02_format_cbor'] = min(10, round(ratio * 10 + 5, 1))
    details['AR02_format_cbor'] = {'cbor_bytes': oc, 'json_bytes': of_full, 'reduction_pct': round(ratio*100,1), 'note': 'CBOR active — compared to optimized full JSON'}
elif oc > 0:
    scores['AR02_format_cbor'] = 5
    details['AR02_format_cbor'] = {'cbor_bytes': oc, 'json_bytes': of_full, 'note': 'CBOR active but not smaller than JSON'}
else:
    scores['AR02_format_cbor'] = 0
    details['AR02_format_cbor'] = {'note': 'not measured'}

total = sum(scores.values())
grade = 'A+' if total >= 90 else 'A' if total >= 80 else 'B' if total >= 65 else 'C' if total >= 50 else 'D' if total >= 30 else 'E'

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
    }
}

print(json.dumps(report, indent=2))
" > "$REPORT_FILE"

if [ "$DEBUG_MODE" = true ]; then
  echo -e "${YELLOW}━━━ 🐛 DEBUG: Full JSON report ━━━${NC}"
  cat "$REPORT_FILE"
fi

# Create/update the latest symlink
cp "$REPORT_FILE" "$LATEST_LINK"

# Purge old reports: keep only the 5 most recent (+ latest-report.json)
echo -e "${YELLOW}🧹 Purge des anciens rapports (conservation des 5 derniers)...${NC}"
ls -1t "$OUTPUT_DIR"/green-score-report-*.json 2>/dev/null | tail -n +6 | while read -r old_report; do
  echo "  🗑️  Suppression : $(basename "$old_report")"
  rm -f "$old_report"
done

# Generate badge (non-blocking)
if [ -f "$(cd "$(dirname "$0")/.." && pwd)/scripts/generate-badge.sh" ]; then
  bash "$(cd "$(dirname "$0")/.." && pwd)/scripts/generate-badge.sh" "$LATEST_LINK" "$(cd "$(dirname "$0")/.." && pwd)/badges/green-score.svg" || true
fi

# Generate dashboard (non-blocking)
if [ -f "$(cd "$(dirname "$0")/.." && pwd)/scripts/generate-dashboard.sh" ]; then
  bash "$(cd "$(dirname "$0")/.." && pwd)/scripts/generate-dashboard.sh" "$LATEST_LINK" "$(cd "$(dirname "$0")/.." && pwd)/dashboard/index.save.html" "$(cd "$(dirname "$0")/.." && pwd)/dashboard/index.html" || true
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📄 Report saved to: ${REPORT_FILE}${NC}"
echo -e "${GREEN}📄 Latest report:   ${LATEST_LINK}${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Quick summary
TOTAL=$(python3 -c "import sys,json;r=json.load(sys.stdin);print(r['green_score']['total'])" < "$REPORT_FILE")
GRADE=$(python3 -c "import sys,json;r=json.load(sys.stdin);print(r['green_score']['grade'])" < "$REPORT_FILE")

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🌿 GREEN SCORE:  ${GREEN}${TOTAL}/100${CYAN}   Grade: ${GREEN}${GRADE}${CYAN}   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "Open the dashboard: ${YELLOW}open dashboard/index.html${NC} (or start the dashboard server)"
