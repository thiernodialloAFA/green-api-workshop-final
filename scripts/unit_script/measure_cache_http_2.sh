#!/usr/bin/env bash
set -euo pipefail
BASE=${BASE:-http://localhost:8081}
ID=${1:-1}

echo -e "ETag -> 304 | Affichage du livre avec l'identifiant $ID modifié\n"

# 1. Get initial ETag
echo -e "Etape 1 : Récupération de l'ETag initial\n"
ETAG1=$(curl -sI "$BASE/books/$ID" | awk -F': ' '/^ETag:/ {print $2}' | tr -d '\r')

# 2. Modify the resource (example: change title)
echo -e "Etape 2 : Modification de la ressource\n"
curl -s -X PUT -H "Content-Type: application/json" -d "{\"id\":$ID,\"title\":\"Title Modified\",\"author\":\"Author Modified\",\"published_date\":1991,\"pages\":101,\"summary\":\"Long summary to inflate payload xx\"}" "$BASE/books/$ID"
# 3. Get new ETag

echo -e "\n\nEtape 3 : Récupération du nouvel ETag\n"
ETAG2=$(curl -sI "$BASE/books/$ID" | awk -F': ' '/^ETag:/ {print $2}' | tr -d '\r')

# 4. Compare ETags
echo -e "Etape 4 : Comparaison des ETags\n"
echo "Old ETag: $ETAG1"
echo -e "New ETag: $ETAG2\n"

# 5. Check response with old ETag (should be 200)
echo -e "Etape 5 : checker si le HTTP = 200\n"
curl -s -o /dev/null -w 'Code HTTP : %{http_code}, size download: %{size_download}, temps de la requete : %{time_total}s\n' -H "If-None-Match: $ETAG1" "$BASE/books/$ID"