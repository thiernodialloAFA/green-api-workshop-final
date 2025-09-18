# Atelier clé‑en‑main — Green API (Spring Boot, 50 min)

> **Objectif** : ancrer des pratiques d’éco‑conception d’API (API Green Score) :
> réduire le **payload** et les **transferts** sans dégrader l’expérience.

## Pré‑requis
Java 17+, Maven 3.9+, `curl`.

## Agenda (50')
- (5') Contexte & KPI (règles visées)
- (10') Baseline & mesures (payload massif)
- (12') Pagination + filtrage (**DE11**, **DE08**, **US01**)
- (13') Compression + ETag (**DE01/DE02/DE03**)
- (7') Delta & 206 (**DE06/US04**, **206**)
- (3') Wrap‑up (logs, %304, bytes)

## Démarrage
```bash
cd baseline && mvn spring-boot:run
cd optimized && mvn spring-boot:run
cd scripts && bash measure_baseline.sh && bash measure_optimized.sh
```

## Live‑coding (points clés)
- `GET /books?page=&size=` (**DE11**) — borner `size` (≤100)
- `GET /books/select?fields=` (**DE08/US01**) — whitelist & champs coûteux exclus par défaut
- Gzip + `ShallowEtagHeaderFilter` + `Cache-Control` (**DE01/02/03**)
- `GET /books/changes?since=` (**DE06/US04**)
- `GET /books/{id}/summary` + `Range` → **206**

## CI PR
Workflow `.github/workflows/pr-green-api.yml` :
- build (`baseline/`, `optimized/`)
- lance services, exécute scripts `curl`
- asserte : **payload optimisé < baseline/10** & **304** avec ETag
