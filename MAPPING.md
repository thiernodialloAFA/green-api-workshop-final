# 🗺️ Mapping des pratiques → Règles API Green Score

> Correspondance entre les optimisations implémentées et les règles du référentiel
> [API Green Score](https://github.com/API-Green-Score/APIGreenScore).

## Data Exchange

| Pratique | Règle | Fichier(s) clé(s) | Points |
|----------|-------|--------------------|--------|
| **Pagination** (`page`, `size` bornés ≤100) | `DE11` | `BookController.page()` | 15 |
| **Filtrage de champs** (`fields=`) | `DE08` | `BookController.select()` | 15 |
| **Query params** (GET) | `US01` | `BookController` | — |
| **Compression Gzip** | `DE01` | `application.yml` (server.compression) | 15 |
| **Cache HTTP** (`ETag` + `Cache-Control`) | `DE02` / `DE03` | `WebConfig.etagFilter()`, `BookController.byId()` | 15 |
| **Delta** (`/changes?since=`) | `DE06` / `US04` | `BookController.changes()`, `BookRepository.findChangesSince()` | 10 |
| **206 Partial Content** (`Range: bytes=`) | Data Exchange | `BookController.summaryRange()` | 10 |
| **Format binaire** (CBOR) | `AR02` | `BookController.getBooksCbor()`, `jackson-dataformat-cbor` | 10 |

## Usage / Architecture / Logs

| Pratique | Règle | Fichier(s) clé(s) | Points |
|----------|-------|--------------------|--------|
| **Observabilité** (logs payload, latence, 304) | `LO01` | `PayloadLoggingFilter` | 5 |
| **Monitoring erreurs** (Actuator/metrics) | `US07` | `application.yml` (management.endpoints) | — |
| **Rate Limiting** | `US07` | `RateLimitFilter` | 5 |
| **Efficacité** (batch, keyset pagination) | `AR02` | — (exercice avancé) | — |

## Automatisation

| Outil | Rôle | Fichier |
|-------|------|---------|
| **Green Score Analyzer** | Mesure + calcul du score /100 | `scripts/green-score-analyzer.sh` |
| **Dashboard** | Visualisation et tracking | `dashboard/index.html` |
| **GitHub Actions** | CI : build + analyse + assertions + commentaire PR | `.github/workflows/pr-green-api.yml` |
| **Spectral** | Lint OpenAPI éco-conception | `.spectral.yml` |

## Score total : **100 points**
