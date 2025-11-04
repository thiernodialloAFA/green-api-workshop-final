#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8081}
PAGE=${1:-0}
SIZE=${2:-20}
FIELDS=${3:-id,title,author}

echo "Affichage d'une liste de livres avec les champs suivants : $FIELDS (page=$PAGE, size=$SIZE)"
response=$(curl -s -w '%{http_code} %{size_download} %{time_total}' "$BASE/books/select?fields=$FIELDS&page=$PAGE&size=$SIZE" -o response_filtrage.json)
read http_code size_download time_total < <(tail -n1 <<< "$response")
echo "Code HTTP : $http_code, size download: $size_download, temps de la requête : ${time_total}s"