#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8080}

echo "Affichage de tous les livres sans optimisation (baseline)"
response=$(curl -s -w '%{http_code} %{size_download} %{time_total}' "$BASE/books" -o response_baseline.json)
read http_code size_download time_total < <(tail -n1 <<< "$response")
echo "Code HTTP : $http_code, size download: $size_download, temps de la requête : ${time_total}s"