#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8081}
MINUTES=${1:-5}

echo -e "Delta - Affichage d'une liste de livres dans les ${MINUTES} dernières minutes\n"
SINCE=$(date -u -d "-${MINUTES} minutes" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v -"${MINUTES}"M +%Y-%m-%dT%H:%M:%SZ)

response=$(curl -s -w 'Code HTTP : %{http_code}, size download: %{size_download}, temps de la requete : %{time_total}s' "$BASE/books/changes?since=$SINCE" -o response_delta.json)
read http_code size_download time_total < <(tail -n1 <<< "$response")
echo "Code HTTP : $http_code, size download: $size_download, temps de la requête : ${time_total}s"