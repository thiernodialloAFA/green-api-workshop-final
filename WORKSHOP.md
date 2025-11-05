# Turnkey Workshop — Green API (Spring Boot, 50 min)

> **Goal**: Anchor eco-design practices for APIs (API Green Score):
> reduce **payload** and **transfers** without degrading user experience.

## Prerequisites
Java 17+, Maven 3.9+, `curl`.

## Agenda (50')
- (5') Context & KPIs (targeted rules)
- (10') Baseline & measurements (large payload)
- (12') Pagination + filtering (**DE11**, **DE08**, **US01**)
- (13') Compression + ETag (**DE01/DE02/DE03**)
- (7') Delta & 206 (**DE06/US04**, **206**)
- (3') Wrap-up (logs, %304, bytes)

## Quick Start
```bash
cd baseline && mvn spring-boot:run
cd optimized && mvn spring-boot:run
cd scripts && bash measure_baseline.sh && bash measure_optimized.sh
```

## Live-coding (key points)
- `GET /books?page=&size=` (**DE11**) — limit `size` (≤100)
- `GET /books/select?fields=` (**DE08/US01**) — whitelist & expensive fields excluded by default
- Gzip + `ShallowEtagHeaderFilter` + `Cache-Control` (**DE01/02/03**)
- `GET /books/changes?since=` (**DE06/US04**)
- `GET /books/{id}/summary` + `Range` → **206**

## CI PR
Workflow `.github/workflows/pr-green-api.yml`:
- build (`baseline/`, `optimized/`)
- start services, run `curl` scripts
- assert: **optimized payload < baseline/10** & **304** with ETag
