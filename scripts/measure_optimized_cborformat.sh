#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8081}

echo "== Optimized: cbor =="
curl -s -H 'Accept: application/cbor' -w '
http_code=%{http_code}
size=%{size_download}
time=%{time_total}

' -o /dev/null   "$BASE/books/cbor"

echo "== Optimized: compression (gzip) =="
curl -s -H 'Accept-Encoding: gzip' -w '
http_code=%{http_code}
size=%{size_download}
time=%{time_total}

' -o /dev/null   "$BASE/books/select?fields=id,title,author&page=0&size=50"

echo "== Optimized: ETag -> 304 =="
ETAG=$(curl -sI -w '
http_code=%{http_code}
size=%{size_download}
time=%{time_total}

' "$BASE/books/select?fields=id,title,author&page=0&size=20" | awk -F': ' '/^ETag:/ {print $2}' | tr -d '
')
curl -s -o /dev/null -w '
http_code=%{http_code}
size=%{size_download}
time=%{time_total}

' -H "If-None-Match: $ETAG"   "$BASE/books/select?fields=id,title,author&page=0&size=20"

echo "== Optimized: delta since now (with 1 update) =="
SINCE=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
sleep 1
curl -s -X PUT "$BASE/books/1" \
  -H "Content-Type: application/json" \
  -d '{"title":"Title 1","author":"Author 1","published_date":1990,"pages":100,"summary":"Updated summary for delta test"}' \
  -o /dev/null 2>/dev/null || true
curl -s -w '
http_code=%{http_code}
size=%{size_download}
time=%{time_total}

' -o /dev/null "$BASE/books/changes?since=$SINCE"

echo "== Optimized: Range 206 on summary =="
curl -s -i -w '
http_code=%{http_code}
size=%{size_download}
time=%{time_total}
' -H 'Range: bytes=0-199' "$BASE/books/1/summary" | sed -n '1,10p'
