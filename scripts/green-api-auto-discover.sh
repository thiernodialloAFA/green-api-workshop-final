#!/usr/bin/env bash
###############################################################################
#  Green API Auto-Discover & Analyzer — Bash wrapper
#
#  Usage:
#    bash green-api-auto-discover.sh                              # defaults
#    bash green-api-auto-discover.sh --target http://localhost:8081
#    bash green-api-auto-discover.sh --swagger ./openapi.yaml --dry-run
#
#  Environment variables (override defaults):
#    TARGET_URL          Base URL (default: http://localhost:8081)
#    SWAGGER_URL         Explicit swagger URL/path (auto-discovered if empty)
#    BEARER_TOKEN        Bearer token for authenticated APIs
#    REPEAT              Repetitions per endpoint (default: 3)
#    SKIP_SPECTRAL       Set to 1 to skip Spectral linting
#    SKIP_DASHBOARD      Set to 1 to skip dashboard generation
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🌿 Green API Auto-Discover & Analyzer                     ║${NC}"
echo -e "${CYAN}║  Devoxx France 2026 — Green Architecture                   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Build arguments ──
ARGS=()

# Target URL
TARGET_URL="${TARGET_URL:-http://localhost:8081}"
ARGS+=(--target "$TARGET_URL")

# Swagger (optional)
if [ -n "${SWAGGER_URL:-}" ]; then
    ARGS+=(--swagger "$SWAGGER_URL")
fi

# Bearer token
if [ -n "${BEARER_TOKEN:-}" ]; then
    ARGS+=(--bearer "$BEARER_TOKEN")
fi

# Repeat
REPEAT="${REPEAT:-3}"
ARGS+=(--repeat "$REPEAT")

# Skip flags
if [ "${SKIP_SPECTRAL:-0}" = "1" ]; then
    ARGS+=(--skip-spectral)
fi
if [ "${SKIP_DASHBOARD:-0}" = "1" ]; then
    ARGS+=(--skip-dashboard)
fi

# Forward extra CLI args
ARGS+=("$@")

# ── Run ──
echo -e "${GREEN}Running:${NC} python3 $SCRIPT_DIR/green-api-auto-discover.py ${ARGS[*]}"
echo ""

python3 "$SCRIPT_DIR/green-api-auto-discover.py" "${ARGS[@]}"
EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Analysis complete. Open dashboard/index.html to view results.${NC}"
else
    echo -e "\033[0;31m✗ Analysis failed or score below threshold (exit code: $EXIT_CODE).${NC}"
fi

exit $EXIT_CODE

