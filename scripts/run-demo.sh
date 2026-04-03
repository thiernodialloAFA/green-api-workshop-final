#!/usr/bin/env bash
###############################################################################
#  🌿 Green API — Script de démo live (Devoxx France 2026)
#  Lance baseline + optimized, exécute l'analyse, ouvre le dashboard
###############################################################################
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATASET_SIZE=${DATASET_SIZE:-1000000}

# Parse options
DEBUG_FLAG=""
for arg in "$@"; do
  case "$arg" in
    --debug) DEBUG_FLAG="--debug" ;;
  esac
done

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

cleanup() {
  echo -e "\n${YELLOW}🛑 Arrêt des services...${NC}"
  [ -f /tmp/baseline.pid ] && kill "$(cat /tmp/baseline.pid)" 2>/dev/null && rm -f /tmp/baseline.pid
  [ -f /tmp/optimized.pid ] && kill "$(cat /tmp/optimized.pid)" 2>/dev/null && rm -f /tmp/optimized.pid
  echo -e "${GREEN}✓ Nettoyage terminé.${NC}"
}
trap cleanup EXIT

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  🌿 Green Architecture — Démo Live                             ║"
echo "║  Devoxx France 2026 — Tools in Action                         ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

###############################################################################
# STEP 1 — Build
###############################################################################
echo -e "${YELLOW}━━━ STEP 1/7 : Build des projets ━━━${NC}"
echo -e "  Building baseline..."
cd "$ROOT/green-api-baseline" && mvn -q package -DskipTests 2>/dev/null
echo -e "  ${GREEN}✓ Baseline built${NC}"
echo -e "  Building optimized..."
cd "$ROOT/green-api-optimized" && mvn -q package -DskipTests 2>/dev/null
echo -e "  ${GREEN}✓ Optimized built${NC}"
echo ""

###############################################################################
# STEP 2 — Start services
###############################################################################
echo -e "${YELLOW}━━━ STEP 2/7 : Démarrage des services ━━━${NC}"
cd "$ROOT/green-api-baseline"
java -jar target/green-api-baseline-0.0.1-SNAPSHOT.jar \
  --app.dataset.size="$DATASET_SIZE" \
  > /tmp/baseline.log 2>&1 &
echo $! > /tmp/baseline.pid
echo -e "  ⏳ Baseline démarré (PID $(cat /tmp/baseline.pid), port 8080)"

cd "$ROOT/green-api-optimized"
java -jar target/green-api-optimized-0.0.1-SNAPSHOT.jar \
  --app.dataset.size="$DATASET_SIZE" \
  > /tmp/optimized.log 2>&1 &
echo $! > /tmp/optimized.pid
echo -e "  ⏳ Optimized démarré (PID $(cat /tmp/optimized.pid), port 8081)"

echo -ne "  Attente des services"
for i in $(seq 1 60); do
  B=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/actuator/health 2>/dev/null || echo "0")
  O=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8081/actuator/health 2>/dev/null || echo "0")
  if [ "$B" = "200" ] && [ "$O" = "200" ]; then
    echo -e " ${GREEN}✓${NC}"
    break
  fi
  echo -n "."
  sleep 1
done
echo ""

###############################################################################
# STEP 3 — Découverte automatique des endpoints
###############################################################################
echo -e "${YELLOW}━━━ STEP 3/7 : Découverte automatique des endpoints ━━━${NC}"
echo ""

SPEC_FILE="/tmp/green-api-spec.json"
SWAGGER_FOUND=""

# Try optimized first (has springdoc), then baseline
SWAGGER_PATHS="/v3/api-docs /v3/api-docs.yaml /v2/api-docs /openapi.json /swagger.json"
for base in "http://localhost:8081" "http://localhost:8080"; do
  for path in $SWAGGER_PATHS; do
    url="${base}${path}"
    echo -ne "  Trying ${url}..."
    status=$(curl -s -o "$SPEC_FILE" -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [ "$status" = "200" ] && [ -s "$SPEC_FILE" ]; then
      echo -e " ${GREEN}✓ Found!${NC}"
      SWAGGER_FOUND="$url"
      break 2
    fi
    echo -e " ${RED}✗${NC}"
  done
done

# Extract GET endpoints from spec
DISCOVERED_PATHS=""
if [ -n "$SWAGGER_FOUND" ]; then
  echo -e "  ${GREEN}✓ Swagger discovered: ${SWAGGER_FOUND}${NC}"
  cp "$SPEC_FILE" "$ROOT/reports/discovered-openapi.json" 2>/dev/null || true

  DISCOVERED_PATHS=$(python3 -c "
import json, re, sys

spec = json.load(sys.stdin)
base_path = spec.get('basePath', '') if spec.get('swagger') == '2.0' else ''

for path, ops in (spec.get('paths') or {}).items():
    full = base_path + path if base_path else path
    for method in ('get',):
        if method in ops:
            url_path = re.sub(r'\{[^}]+\}', '1', full)
            summary = (ops[method].get('summary') or ops[method].get('operationId') or '')[:60]
            print(f'{method.upper()}|{full}|{url_path}|{summary}')
" < "$SPEC_FILE" 2>/dev/null || echo "")

  EP_COUNT=$(echo "$DISCOVERED_PATHS" | grep -c '|' || echo "0")
  echo -e "  ${GREEN}✓ Discovered ${EP_COUNT} GET endpoint(s):${NC}"
  echo "$DISCOVERED_PATHS" | while IFS='|' read -r method path url_path summary; do
    [ -z "$method" ] && continue
    echo -e "     ${CYAN}${method}${NC} ${path}  ${YELLOW}(${summary})${NC}"
  done
else
  echo -e "  ${RED}⚠  No swagger discovered. Using hardcoded endpoints.${NC}"
fi
echo ""

###############################################################################
# STEP 4 — Mesures rapides avant/après (dynamiques)
###############################################################################
echo -e "${YELLOW}━━━ STEP 4/7 : Mesures rapides avant/après ━━━${NC}"
echo ""

if [ -n "$DISCOVERED_PATHS" ]; then
  # ── BASELINE: measure all discovered endpoints ──
  echo -e "  ${RED}🔴 AVANT — Baseline (API naïve, port 8080)${NC}"
  echo "$DISCOVERED_PATHS" | while IFS='|' read -r method path url_path summary; do
    [ -z "$method" ] && continue
    url="http://localhost:8080${url_path}"
    echo -ne "     ${method} ${path} "
    curl -s -w '→ %{http_code}  %{size_download} bytes  %{time_total}s\n' \
      -o /dev/null "$url" 2>/dev/null || echo "→ error"
  done
  echo ""

  # ── OPTIMIZED: measure all discovered endpoints ──
  echo -e "  ${GREEN}🟢 APRÈS — Optimized (API green, port 8081)${NC}"
  echo "$DISCOVERED_PATHS" | while IFS='|' read -r method path url_path summary; do
    [ -z "$method" ] && continue
    url="http://localhost:8081${url_path}"
    echo -ne "     ${method} ${path} "
    curl -s -w '→ %{http_code}  %{size_download} bytes  %{time_total}s\n' \
      -o /dev/null "$url" 2>/dev/null || echo "→ error"
  done
  echo ""
else
  # Fallback hardcoded
  echo -e "  ${RED}🔴 AVANT — Baseline: GET /books (pas de pagination)${NC}"
  curl -s -w '     → http_code=%{http_code}  size=%{size_download} bytes  time=%{time_total}s\n' \
    -o /dev/null http://localhost:8080/books
  echo ""

  echo -e "  ${GREEN}🟢 APRÈS — Optimized: GET /books?page=0&size=20${NC}"
  curl -s -w '     → http_code=%{http_code}  size=%{size_download} bytes  time=%{time_total}s\n' \
    -o /dev/null "http://localhost:8081/books?page=0&size=20"
  echo ""
fi

###############################################################################
# STEP 5 — Tests Green API spécifiques (gzip, ETag, Range)
###############################################################################
echo -e "${YELLOW}━━━ STEP 5/7 : Tests Green API spécifiques ━━━${NC}"
echo ""

# Find a collection endpoint and a single-resource endpoint from discovery
COLLECTION_PATH=""
SINGLE_PATH=""
if [ -n "$DISCOVERED_PATHS" ]; then
  COLLECTION_PATH=$(echo "$DISCOVERED_PATHS" | grep -v '{' | head -1 | cut -d'|' -f3)
  SINGLE_PATH=$(echo "$DISCOVERED_PATHS" | grep '{' | head -1 | cut -d'|' -f3)
fi
COLLECTION_PATH=${COLLECTION_PATH:-"/books"}
SINGLE_PATH=${SINGLE_PATH:-"/books/1"}

echo -e "  ${GREEN}🟢 Gzip compression — GET http://localhost:8081${COLLECTION_PATH}${NC}"
curl -s -H 'Accept-Encoding: gzip' \
  -w '     → http_code=%{http_code}  size=%{size_download} bytes  time=%{time_total}s\n' \
  -o /dev/null "http://localhost:8081${COLLECTION_PATH}"
echo ""

echo -e "  ${GREEN}🟢 ETag → 304 — GET http://localhost:8081${SINGLE_PATH}${NC}"
ETAG=$(curl -sI "http://localhost:8081${SINGLE_PATH}" 2>/dev/null | grep -i '^etag:' | awk -F': ' '{print $2}' | tr -d '\r\n')
if [ -n "$ETAG" ]; then
  curl -s -o /dev/null \
    -w '     → http_code=%{http_code}  size=%{size_download} bytes  time=%{time_total}s (ETag: %{http_code})\n' \
    -H "If-None-Match: $ETAG" "http://localhost:8081${SINGLE_PATH}"
else
  echo -e "     ${YELLOW}⚠ No ETag header returned — skipping 304 test${NC}"
fi
echo ""

RANGE_URL="http://localhost:8081${SINGLE_PATH}/summary"
echo -e "  ${GREEN}🟢 Range 206 — GET ${RANGE_URL}${NC}"
curl -s -o /dev/null \
  -w '     → http_code=%{http_code}  size=%{size_download} bytes  time=%{time_total}s\n' \
  -H 'Range: bytes=0-199' "$RANGE_URL" 2>/dev/null || echo "     → endpoint not available"
echo ""

###############################################################################
# STEP 6 — Analyse automatisée Green Score (with discovery)
###############################################################################
echo -e "${YELLOW}━━━ STEP 6/7 : Analyse Green Score automatisée (with discovery) ━━━${NC}"
if [ -f "$ROOT/scripts/green-score-analyzer_withdiscovery.sh" ]; then
  bash "$ROOT/scripts/green-score-analyzer_withdiscovery.sh" $DEBUG_FLAG
else
  bash "$ROOT/scripts/green-score-analyzer.sh" $DEBUG_FLAG
fi
echo ""

###############################################################################
# STEP 7 — Ouvrir le dashboard
###############################################################################
echo -e "${YELLOW}━━━ STEP 7/7 : Dashboard ━━━${NC}"
DASHBOARD="$ROOT/dashboard/index.html"
echo -e "  📊 Dashboard disponible : ${GREEN}${DASHBOARD}${NC}"

# Try to open the dashboard in the default browser
if command -v xdg-open &>/dev/null; then
  xdg-open "$DASHBOARD" 2>/dev/null &
elif command -v open &>/dev/null; then
  open "$DASHBOARD" 2>/dev/null &
elif command -v start &>/dev/null; then
  start "$DASHBOARD" 2>/dev/null &
fi

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🌿 Démo prête ! Services en cours d'exécution.               ║${NC}"
echo -e "${CYAN}║  Baseline:  http://localhost:8080   (API naïve)               ║${NC}"
echo -e "${CYAN}║  Optimized: http://localhost:8081   (API green)               ║${NC}"
echo -e "${CYAN}║  Swagger:   http://localhost:8081/swagger-ui.html             ║${NC}"
echo -e "${CYAN}║  Dashboard: dashboard/index.html                              ║${NC}"
echo -e "${CYAN}║                                                               ║${NC}"
echo -e "${CYAN}║  Appuyez sur Ctrl+C pour arrêter.                             ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo -e "  📦 Dataset size: ${GREEN}${DATASET_SIZE}${NC} books"

# Keep running until Ctrl+C
wait

