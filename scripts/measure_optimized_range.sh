#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8081}

echo "== Optimized: Range 206 on summary =="
curl -s -i -w '
http_code=%{http_code}
size=%{size_download}
time=%{time_total}
' -H 'Range: bytes=0-199' "$BASE/books/1/summary" | sed -n '1,10p'
