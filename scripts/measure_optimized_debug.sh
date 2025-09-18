#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8081}

echo "== Optimized: ETag -> 304 =="
ETAG=$(curl -sI "$BASE/books/select?fields=id,title,author&page=0&size=20" | awk -F': ' '/^ETag:/ {print $2}' | tr -d '
')
curl -s -o /dev/null -w 'http_code=%{http_code}
' -H "If-None-Match: $ETAG"   "$BASE/books/select?fields=id,title,author&page=0&size=20"
