#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8081}

echo "== Optimized: delta since now (with 1 update) =="
# Capture timestamp now
SINCE=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
sleep 1
# Faire un update pour créer 1 delta entry
curl -s -X PUT "$BASE/books/1" \
  -H "Content-Type: application/json" \
  -d '{"title":"Title 1","author":"Author 1","published_date":1990,"pages":100,"summary":"Updated summary for delta test"}' \
  -o /dev/null 2>/dev/null || true
# Mesurer le delta (ne retourne que le livre modifié)
curl -s -w '
http_code=%{http_code}
size=%{size_download}
time=%{time_total}

' -o /dev/null "$BASE/books/changes?since=$SINCE"
