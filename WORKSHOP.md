# 🌿 Atelier clé-en-main — Green API (Spring Boot, 30 min Tools-in-Action)

> **Objectif** : appliquer le framework **API Green Score** sur une API réelle.
> Réduire le **payload**, les **transferts** et l'**empreinte** — mesures concrètes avant/après.

## Pré-requis
Java 17+, Maven 3.9+, `curl`, Python 3 (pour l'analyseur).

## Agenda (30')

| Temps  | Étape                                          | Règles                           |
|--------|------------------------------------------------|----------------------------------|
| 0-3'   | Contexte : pourquoi les APIs sont gourmandes ? | —                                |
| 3-5'   | Lancer baseline, mesurer le payload brut       | —                                |
| 5-10'  | Pagination + filtrage de champs                | **DE11**, **DE08**, **US01**     |
| 10-15' | Compression Gzip + ETag/304                    | **DE01**, **DE02/DE03**          |
| 15-20' | Delta + Range 206 + CBOR                       | **DE06/US04**, **206**, **AR02** |
| 20-25' | Observabilité + Rate Limiting                  | **LO01**, **US07**               |
| 25-28' | Analyse automatisée + Dashboard                | Green Score /100                 |
| 28-30' | Wrap-up, CI, Spectral, liens                   | —                                |

## Démarrage

> ⚠️ **Choisissez UNE SEULE des deux options ci-dessous.** Elles sont **exclusives** : utilisez soit le script automatique, soit le lancement manuel.

---

### 🅰️ Option 1 — Script automatique (recommandé)

Tout est lancé en une seule commande : build, démarrage des 2 APIs, mesures et analyse.

```bash
bash scripts/run-demo.sh
```

---

### ────────────── OU ──────────────

---

### 🅱️ Option 2 — Lancement manuel (3 terminaux)

Pour garder la main sur chaque étape et explorer à votre rythme.

```bash
# Terminal 1 — Baseline (port 8080)
cd green-api-baseline && mvn spring-boot:run

# Terminal 2 — Optimized (port 8081)
cd green-api-optimized && mvn spring-boot:run

# Terminal 3 — Mesures
cd scripts && bash scripts/run-demo_light.sh
```

---

## Live-coding : points clés

### 1. Baseline — le constat (3')
```bash
# 500 000 livres, pas de pagination → payload massif
curl -s -w '\nsize=%{size_download} time=%{time_total}\n' -o /dev/null http://localhost:8080/books
# → ~48 MB, 4+ secondes
```

### 2. Pagination + Filtrage (5')
```bash
# DE11 — Pagination : borner size ≤ 100
curl -s -w '\nsize=%{size_download}\n' -o /dev/null "http://localhost:8081/books?page=0&size=20"

# DE08/US01 — Filtrage de champs : exclure les champs coûteux
curl -s -w '\nsize=%{size_download}\n' -o /dev/null \
  "http://localhost:8081/books/select?fields=id,title,author&page=0&size=20"
```

### 3. Compression + Cache (5')
```bash
# DE01 — Gzip
curl -s -H 'Accept-Encoding: gzip' -w '\nsize=%{size_download}\n' -o /dev/null \
  "http://localhost:8081/books/select?fields=id,title,author&page=0&size=50"

# DE02/DE03 — ETag → 304
ETAG=$(curl -sI http://localhost:8081/books/1 | grep -i etag | awk '{print $2}' | tr -d '\r')
curl -s -o /dev/null -w 'http_code=%{http_code}\n' -H "If-None-Match: $ETAG" http://localhost:8081/books/1
# → 304 Not Modified, 0 bytes transférés
```

### 4. Delta + Range + CBOR (5')
```bash
# DE06/US04 — Delta (changes since)
curl -s -w '\nsize=%{size_download}\n' -o /dev/null \
  "http://localhost:8081/books/changes?since=2026-03-01T00:00:00Z"

# 206 — Partial Content
curl -s -o /dev/null -w 'http_code=%{http_code} size=%{size_download}\n' \
  -H 'Range: bytes=0-199' http://localhost:8081/books/1/summary

# AR02 — CBOR (binary format)
curl -s -H 'Accept: application/cbor' -w '\nsize=%{size_download}\n' -o /dev/null \
  http://localhost:8081/books/cbor
```

### 5. Analyse automatisée + Dashboard (3')
```bash
# Lancer l'analyseur complet
bash scripts/green-score-analyzer.sh

# Ouvrir le dashboard
# → dashboard/index.html (charger reports/latest-report.json)
```

### 6. CI & Spectral (2')
- `.github/workflows/pr-green-api.yml` : build, analyse, assertions, commentaire PR
- `.spectral.yml` : règles OpenAPI éco-conception
- Le score est posté automatiquement sur chaque PR

## Endpoints de l'API optimisée

| Endpoint | Méthode | Règle | Description |
|----------|---------|-------|-------------|
| `/books?page=&size=` | GET | DE11 | Pagination (size ≤ 100) |
| `/books/select?fields=&page=&size=` | GET | DE08/US01 | Filtrage de champs |
| `/books/{id}` | GET | DE02/DE03 | ETag + Last-Modified → 304 |
| `/books/{id}/summary` | GET | 206 | Range → Partial Content |
| `/books/changes?since=` | GET | DE06/US04 | Delta changes |
| `/books/cbor` | GET | AR02 | Format CBOR binaire |
| `/books/noCache/{id}` | GET | — | Ressource sans cache (comparaison) |
| `/books/async` | GET | — | Endpoint asynchrone |
| `/v3/api-docs` | GET | — | OpenAPI spec (Springdoc) |
| `/swagger-ui.html` | GET | — | Swagger UI |

## Résultats attendus

| Mesure | Baseline | Optimized | Gain |
|--------|----------|-----------|------|
| Payload (GET /books) | ~48 MB | ~800 B (paginé+filtré) | **99.99%** |
| Payload (gzip) | — | ~480 B | **compression 40%+** |
| ETag 2nd call | 200 (full) | 304 (0 bytes) | **100%** |
| Range summary | full | 200 bytes | **partial** |
| Green Score | 0/100 | **80+/100** | 🌿 |
