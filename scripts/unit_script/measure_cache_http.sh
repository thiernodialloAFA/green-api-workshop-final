#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8081}
ID=${1:-1}

echo "ETag -> 304 | Affichage du livre avec l'identifiant $ID non modifié"
# Get the ETag from the first request
ETAG=$(curl -sI http://localhost:8081/books/$ID | awk -F': ' '/^ETag:/ {print $2}' | tr -d '\r')

# Use the ETag in the If-None-Match header for the second request
curl -s -o /dev/null -w 'Code HTTP : %{http_code}, size download: %{size_download} (pas de transfert de données ehehehe), temps de la requete : %{time_total}s\n' -H "If-None-Match: $ETAG" http://localhost:8081/books/$ID