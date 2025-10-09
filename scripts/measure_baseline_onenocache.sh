#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8081}

echo "== Baseline: /books/nocache/1 =="
curl -s -w '
        http_code=%{http_code}
        size=%{size_download}
        time=%{time_total}


' -o /dev/null "$BASE/books/1"
