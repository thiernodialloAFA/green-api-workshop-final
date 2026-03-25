#!/usr/bin/env bash
###############################################################################
#  Start baseline + optimized (local dev)
#  Usage: bash scripts/start.sh [--analyze]
###############################################################################
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

ANALYZE=false
if [[ "${1:-}" == "--analyze" ]]; then
  ANALYZE=true
fi

echo "Starting baseline (8080)..."
(cd "$ROOT/green-api-baseline" && mvn -q spring-boot:run) &
BASE_PID=$!

echo "Starting optimized (8081)..."
(cd "$ROOT/green-api-optimized" && mvn -q spring-boot:run) &
OPT_PID=$!

echo "Baseline PID: $BASE_PID"
echo "Optimized PID: $OPT_PID"

if $ANALYZE; then
  echo "Running Green Score analyzer..."
  bash "$ROOT/scripts/green-score-analyzer_withdiscovery.sh" || true
fi

echo "Press Ctrl+C to stop."
wait

