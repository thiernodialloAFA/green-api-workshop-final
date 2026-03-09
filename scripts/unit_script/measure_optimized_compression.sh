#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8081}
PAGE=${1:-0}
SIZE=${2:-50}
FIELDS=${3:-id,title,author}

echo -e "GZIP - Affichage d'une liste de livres avec les champs suivants : $FIELDS (page=$PAGE, size=$SIZE)\n"
curl -s -w 'Code HTTP : %{http_code}, temps de la requete : %{time_total}s' -H 'Accept-Encoding: gzip' -I -D - "$BASE/books/select?fields=$FIELDS&page=$PAGE&size=$SIZE" -o /dev/null
