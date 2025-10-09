#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8081}

echo "== Optimized: compression (gzip) =="
curl -s -H 'Accept-Encoding: gzip' -w '
http_code=%{http_code}
size=%{size_download}
time=%{time_total}

' -o /dev/null   "$BASE/books/select?fields=id,title,author&page=0&size=50"