#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8081}
PAGE=${1:-0}
SIZE=${2:-20}

echo "Affichage d'une liste de livres (page=$PAGE, size=$SIZE)"
response=$(curl -s -w '%{http_code} %{size_download} %{time_total}' "$BASE/books/select?page=$PAGE&size=$SIZE" -o response_pagination.json)
read http_code size_download time_total < <(tail -n1 <<< "$response")
echo "Code HTTP : $http_code, size download: $size_download, temps de la requête : ${time_total}s"