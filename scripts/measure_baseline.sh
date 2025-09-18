#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8080}

echo "== Baseline: /books (full) =="
curl -s -w '
        http_code=%{http_code}
        size=%{size_download}
        time=%{time_total}

        ' -o /dev/null "$BASE/books"

echo "== Baseline: /books/1 =="
curl -s -w '
        http_code=%{http_code}
        size=%{size_download}
        time=%{time_total}


' -o /dev/null "$BASE/books/1"
