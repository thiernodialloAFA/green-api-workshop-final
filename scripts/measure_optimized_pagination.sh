#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8081}

echo "== Optimized: pageination"
curl -s -w '
http_code=%{http_code}
size=%{size_download}
time=%{time_total}

' -o /dev/null   "$BASE/books/select?page=0&size=20"
