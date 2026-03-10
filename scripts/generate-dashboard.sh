#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_FILE=${1:-"$ROOT_DIR/reports/latest-report.json"}
TEMPLATE_FILE=${2:-"$ROOT_DIR/dashboard/index.save.html"}
OUT_FILE=${3:-"$ROOT_DIR/dashboard/index.html"}

python3 "$ROOT_DIR/scripts/generate-dashboard.py" --report "$REPORT_FILE" --template "$TEMPLATE_FILE" --output "$OUT_FILE"

