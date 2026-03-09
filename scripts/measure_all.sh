#!/usr/bin/env bash
set -euo pipefail
BASELINE=${BASELINE:-http://localhost:8080}
OPTIMIZED=${OPTIMIZED:-http://localhost:8081}

echo "══════════════════════════════════════════════════"
echo "  🌿 Green API — Mesures complètes avant/après"
echo "══════════════════════════════════════════════════"
echo ""

echo "━━━ 🔴 BASELINE (port 8080) ━━━"
echo ""

echo "Test GET /books (full payload, no pagination)..."
curl -s -w 'http_code=%{http_code} size=%{size_download} time=%{time_total}\n' \
  -o /dev/null "$BASELINE/books"

echo ""
echo "Test GET /books/1 (single resource, no cache)..."
curl -s -w 'http_code=%{http_code} size=%{size_download} time=%{time_total}\n' \
  -o /dev/null "$BASELINE/books/1"

echo ""
echo "━━━ 🟢 OPTIMIZED (port 8081) ━━━"
echo ""

echo "Test pagination (page=0, size=20)..."
curl -s -w 'http_code=%{http_code} size=%{size_download} time=%{time_total}\n' \
  -o /dev/null "$OPTIMIZED/books?page=0&size=20"

echo ""
echo "Test sélection de champs (fields=id,title,author)..."
curl -s -w 'http_code=%{http_code} size=%{size_download} time=%{time_total}\n' \
  -o /dev/null "$OPTIMIZED/books/select?fields=id,title,author&page=0&size=20"

echo ""
echo "Test compression gzip..."
curl -s -H 'Accept-Encoding: gzip' \
  -w 'http_code=%{http_code} size=%{size_download} time=%{time_total}\n' \
  -o /dev/null "$OPTIMIZED/books/select?fields=id,title,author&page=0&size=50"

echo ""
echo "Test ETag + 304..."
ETAG=$(curl -sI "$OPTIMIZED/books/1" | grep -i '^etag:' | awk -F': ' '{print $2}' | tr -d '\r\n')
echo "  ETag: $ETAG"
curl -s -o /dev/null -w 'http_code=%{http_code} size=%{size_download} time=%{time_total}\n' \
  -H "If-None-Match: $ETAG" "$OPTIMIZED/books/1"

echo ""
echo "Test delta changes (since=2024-01-01)..."
curl -s -w 'http_code=%{http_code} size=%{size_download} time=%{time_total}\n' \
  -o /dev/null "$OPTIMIZED/books/changes?since=2024-01-01T00:00:00Z"

echo ""
echo "Test Range 206 (bytes=0-199)..."
curl -s -o /dev/null -w 'http_code=%{http_code} size=%{size_download} time=%{time_total}\n' \
  -H 'Range: bytes=0-199' "$OPTIMIZED/books/1/summary"

echo ""
echo "Test CBOR format..."
curl -s -H 'Accept: application/cbor' \
  -w 'http_code=%{http_code} size=%{size_download} time=%{time_total}\n' \
  -o /dev/null "$OPTIMIZED/books/cbor"

echo ""
echo "══════════════════════════════════════════════════"
echo "  ✅ Mesures terminées"
echo "══════════════════════════════════════════════════"
