#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8081}

echo "== Optimized: delta since now-5m =="
SINCE=$(date -u -d '-5 minutes' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v -5M +%Y-%m-%dT%H:%M:%SZ)
curl -s -w '
http_code=%{http_code}
size=%{size_download}
time=%{time_total}

' -o /dev/null "$BASE/books/changes?since=$SINCE"
