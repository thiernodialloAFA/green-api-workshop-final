#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8081}

API_URL="http://localhost:8080/books"

echo "Test sélection de champs (fields=id,title,author,summary)..."
curl -s "$API_URL/select?fields=id,title,author,summary&page=0&size=5" | jq

echo "\nTest pagination (page=1, size=3)..."
curl -s "$API_URL?page=1&size=3" | jq

echo "\nTest ressource unitaire avec ETag et Last-Modified (id=1)..."
curl -i "$API_URL/1"

echo "\nTest résumé avec Range (id=1, bytes=0-19)..."
curl -i -H "Range: bytes=0-19" "$API_URL/1/summary"

echo "\nTest delta changes depuis une date (since=2024-01-01T00:00:00Z)..."
curl -s "$API_URL/changes?since=2024-01-01T00:00:00Z" | jq

echo "\nTest endpoint CBOR (Accept: application/cbor)..."
curl -s -H "Accept: application/cbor" "$API_URL/cbor" | hexdump -C
