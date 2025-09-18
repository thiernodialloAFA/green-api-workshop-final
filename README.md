# Green API Workshop (Java Spring Boot)

Atelier pratique (50 min) pour réduire l'empreinte des API HTTP en appliquant les règles **API Green Score** :
- **DE11** Pagination, **DE08** Filtrage, **US01** Query params
- **DE01/USXX** Compression (Gzip), **DE02/DE03** Cache HTTP (ETag/304)
- **DE06/US04** Delta (changes since), **206** Partial Content (Range)
- Logs utiles (**LO01**) & monitoring erreurs (**US07**)

## Structure
- `baseline/` : API naïve (référence)
- `optimized/` : API optimisée (solutions + cas avancés)
- `scripts/` : scripts `curl` pour mesurer **avant/après**
- `docs/slides/Green-API-Workshop.pptx` : slide par règle avec emplacements de mesures
- `CHECKLIST.md` & `.github/pull_request_template.md` : checklist PR
- `WORKSHOP.md` : déroulé clé-en-main
- `.github/workflows/pr-green-api.yml` : CI PR (build + assertions payload & 304)

## Démarrage rapide
```bash
# Terminal 1
cd baseline && mvn spring-boot:run
# Terminal 2
cd optimized && mvn spring-boot:run
# Terminal 3
cd scripts && bash measure_baseline.sh && bash measure_optimized.sh
```

## Documents utiles
- [Checklist Green API (PR)](CHECKLIST.md)
- Slides atelier : `docs/slides/Green-API-Workshop.pptx`
- [Atelier clé‑en‑main](WORKSHOP.md)
