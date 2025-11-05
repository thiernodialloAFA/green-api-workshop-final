# Green API Workshop (Java Spring Boot)

Practical workshop (50 min) to reduce the footprint of HTTP APIs by applying the **API Green Score** rules:
- **DE11** Pagination, **DE08** Filtering, **US01** Query params
- **DE01/USXX** Compression (Gzip), **DE02/DE03** HTTP Cache (ETag/304)
- **DE06/US04** Delta (changes since), **206** Partial Content (Range)
- Useful logs (**LO01**) & error monitoring (**US07**)

## Structure
- `baseline/`: Naive API (reference)
- `optimized/`: Optimized API (solutions + advanced cases)
- `scripts/`: `curl` scripts to measure **before/after**
- `docs/slides/Green-API-Workshop.pptx`: slide per rule with measurement locations
- `CHECKLIST.md` & `.github/pull_request_template.md`: PR checklist
- `WORKSHOP.md`: turnkey workshop guide
- `.github/workflows/pr-green-api.yml`: PR CI (build + payload & 304 assertions)

## Quick Start
```bash
# Terminal 1
cd baseline && mvn spring-boot:run
# Terminal 2
cd optimized && mvn spring-boot:run
# Terminal 3
cd scripts && bash measure_baseline.sh && bash measure_optimized.sh
```

## Useful Documents
- [Green API Checklist (PR)](CHECKLIST.md)
- Workshop slides: `docs/slides/Green-API-Workshop.pptx`
- [Turnkey workshop guide](WORKSHOP.md)
