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
echo -e "${YELLOW}━━━ STEP 1/5 : Build des projets ━━━${NC}"
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
echo -e "${YELLOW}━━━ STEP 2/5 : Démarrage des services ━━━${NC}"

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
# STEP 3 — Mesures manuelles rapides (live demo)
###############################################################################
echo -e "${YELLOW}━━━ STEP 3/5 : Mesures rapides avant/après ━━━${NC}"
echo ""

echo -e "  ${RED}🔴 AVANT — Baseline: GET /books (500k livres, pas de pagination)${NC}"
curl -s -w '     → http_code=%{http_code}  size=%{size_download} bytes  time=%{time_total}s\n' \
  -o /dev/null http://localhost:8080/books
echo ""

echo -e "  ${GREEN}🟢 APRÈS — Optimized: GET /books?page=0&size=20 (paginé)${NC}"
curl -s -w '     → http_code=%{http_code}  size=%{size_download} bytes  time=%{time_total}s\n' \
  -o /dev/null "http://localhost:8081/books?page=0&size=20"
echo ""

echo -e "  ${GREEN}🟢 APRÈS — Optimized: /books/select?fields=id,title,author (filtré)${NC}"
curl -s -w '     → http_code=%{http_code}  size=%{size_download} bytes  time=%{time_total}s\n' \
  -o /dev/null "http://localhost:8081/books/select?fields=id,title,author&page=0&size=20"
echo ""

echo -e "  ${GREEN}🟢 APRÈS — Optimized: gzip compressé${NC}"
curl -s -H 'Accept-Encoding: gzip' \
  -w '     → http_code=%{http_code}  size=%{size_download} bytes  time=%{time_total}s\n' \
  -o /dev/null "http://localhost:8081/books/select?fields=id,title,author&page=0&size=50"
echo ""

echo -e "  ${GREEN}🟢 APRÈS — ETag → 304 (zéro transfert)${NC}"
ETAG=$(curl -sI http://localhost:8081/books/1 2>/dev/null | grep -i '^etag:' | awk -F': ' '{print $2}' | tr -d '\r\n')
curl -s -o /dev/null \
  -w '     → http_code=%{http_code}  size=%{size_download} bytes  time=%{time_total}s\n' \
  -H "If-None-Match: $ETAG" http://localhost:8081/books/1
echo ""

echo -e "  ${GREEN}🟢 APRÈS — Range 206 (partial content)${NC}"
curl -s -o /dev/null \
  -w '     → http_code=%{http_code}  size=%{size_download} bytes  time=%{time_total}s\n' \
  -H 'Range: bytes=0-199' http://localhost:8081/books/1/summary
echo ""

###############################################################################
# STEP 4 — Analyse automatisée Green Score
###############################################################################
echo -e "${YELLOW}━━━ STEP 4/5 : Analyse Green Score automatisée ━━━${NC}"
bash "$ROOT/scripts/green-score-analyzer.sh" $DEBUG_FLAG
echo ""

###############################################################################
# STEP 5 — Ouvrir le dashboard
###############################################################################
echo -e "${YELLOW}━━━ STEP 5/5 : Dashboard ━━━${NC}"
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

