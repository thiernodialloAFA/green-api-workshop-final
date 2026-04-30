# AGENTS.md — AI Coding Agent Guide for Green Analyzer

## What is Green Analyzer?

**Green Analyzer** (`greenanalyzer/`) is a **standalone, API-agnostic** toolkit that measures the eco-design quality of any REST API exposing an OpenAPI/Swagger spec. It produces a **Green Score out of 100**, JSON reports, an HTML dashboard, SVG badges, and optional Creedengo static-analysis results.

It works with **any technology stack** (Spring Boot, .NET, Express, Flask, Django…) — the only requirement is a reachable API with an OpenAPI endpoint.

## Directory Structure

```
greenanalyzer/
├── scripts/
│   ├── green-api-auto-discover.py      # Core engine: discovery, measurement, scoring, reporting
│   ├── green-score-analyzer_withdiscovery.sh  # Bash wrapper around the Python engine
│   ├── start.sh                        # Orchestrator: containers + analysis
│   ├── start_light.sh                  # Lightweight start (no containers)
│   ├── _container-runtime.sh           # Auto-detect Docker / Podman
│   ├── creedengo-analyzer.sh           # Creedengo eco-design static analysis
│   ├── creedengo-detect-stack.py       # Detect project language/stack for Creedengo
│   ├── creedengo-extract-results.py    # Extract Creedengo results into JSON
│   ├── generate-badge.sh               # Generate SVG score badge
│   ├── generate-dashboard.sh           # Generate/update the HTML dashboard
│   ├── generate-dashboard.py           # Python helper for dashboard generation
│   ├── setup-sonar-quality.sh          # Setup SonarQube quality profiles
│   └── requirements.txt                # Python deps (pyyaml)
├── dashboard/
│   ├── index.html                      # Self-contained HTML dashboard (~3000 lines, inline CSS/JS/Chart.js)
│   ├── index.md                        # Dashboard documentation
│   ├── README.md                       # Dashboard readme
│   ├── sample-swagger.json             # Example OpenAPI spec for testing
│   └── sample-swagger.yaml             # Same in YAML
├── reports/                            # Generated reports (timestamped JSON + latest-report.json)
│   ├── latest-report.json              # Symlink/copy of most recent report
│   ├── analysis/                       # Per-endpoint detailed analysis
│   │   ├── endpoints/                  # One JSON per endpoint measured
│   │   ├── latest-summary.json         # Latest analysis summary
│   │   └── rule-resource-mapping.json  # Mapping rules → endpoints
│   └── spectral-results.json           # Spectral OpenAPI lint output
├── badges/
│   └── green-score.svg                 # Generated score badge
├── .spectral.yml                       # Spectral OpenAPI eco-design lint rules
├── .github/
│   └── workflows/pr-green-api.yml      # Reference CI pipeline
├── green-score-threshold.json          # CI gate threshold (default: {"minScore": 50})
└── installer.sh                        # Install greenanalyzer into any git repo
```

## Quick Start — Analyze Any API

```bash
# 1. Point to your running API (auto-discovers OpenAPI spec)
python3 greenanalyzer/scripts/green-api-auto-discover.py \
  --target http://your-api:8080

# 2. Or provide the swagger URL explicitly
python3 greenanalyzer/scripts/green-api-auto-discover.py \
  --target http://your-api:8080 \
  --swagger http://your-api:8080/v3/api-docs

# 3. With auth + repeat measurements for accuracy
python3 greenanalyzer/scripts/green-api-auto-discover.py \
  --target http://your-api:8080 \
  --swagger http://your-api:8080/v3/api-docs \
  --bearer "your-token" \
  --repeat 3

# 4. Dry-run (lint spec only, no HTTP calls)
python3 greenanalyzer/scripts/green-api-auto-discover.py \
  --swagger ./my-spec.yaml --dry-run

# 5. Via the bash wrapper (reads env vars)
TARGET_URL=http://your-api:8080 bash greenanalyzer/scripts/green-score-analyzer_withdiscovery.sh

# 6. Install into another project
bash greenanalyzer/installer.sh https://github.com/org/other-project.git
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TARGET_URL` | `http://localhost:8081` | Base URL of the API to analyze |
| `SWAGGER_URL` | (auto-discovered) | Explicit OpenAPI/Swagger endpoint URL |
| `BEARER_TOKEN` | (empty) | Bearer token for authenticated APIs |
| `REPEAT` | `3` | Number of measurement repetitions per endpoint |
| `APPNAME` | parent folder name | Application name in reports |
| `SKIP_SPECTRAL` | `true` | Skip Spectral linting step |
| `OPTIMIZED_PORT` | `8081` | Port override for target API |

## Scoring Rules (100 points total)

| Rule ID | Rule | Points | What is measured |
|---------|------|--------|------------------|
| DE11 | Pagination | 15 | Collection endpoints support `?page=&size=` — payload reduction vs full response |
| DE08 | Field filtering | 15 | `?fields=id,title` parameter reduces payload |
| DE01 | Compression | 15 | `Accept-Encoding: gzip` reduces wire size |
| DE02/DE03 | Cache (ETag) | 15 | ETag header present → conditional GET returns 304 (0 bytes) |
| DE06 | Delta | 10 | `/changes?since=` endpoint returns only recent changes |
| — | Range (206) | 10 | `Range: bytes=0-199` header returns 206 Partial Content |
| LO01 | Observability | 5 | Logging filter logs bytes + ms per request |
| US07 | Rate Limit | 5 | Rate limiting returns 429 on excess requests |
| AR02 | CBOR | 10 | Binary CBOR endpoint vs JSON reduces payload |

## Key Files — When to Edit What

| To do this… | Edit this file |
|-------------|----------------|
| Add/change a scoring rule | `scripts/green-api-auto-discover.py` (GREEN_RULES dict + measurement logic) |
| Change the dashboard | `dashboard/index.html` (single self-contained HTML file, inline CSS/JS/Chart.js) |
| Change CI gate threshold | `green-score-threshold.json` |
| Add OpenAPI lint rules | `.spectral.yml` |
| Change CI pipeline | `.github/workflows/pr-green-api.yml` |
| Change startup/orchestration | `scripts/start.sh` |
| Change badge generation | `scripts/generate-badge.sh` |
| Change Creedengo analysis | `scripts/creedengo-analyzer.sh` |

## How the Analyzer Works (Flow)

```
1. Discover   → Try known OpenAPI paths (/v3/api-docs, /swagger.json, etc.)
                 or use explicit --swagger URL/file
2. Lint       → Run Spectral against .spectral.yml eco-design rules (optional)
3. Measure    → For each discovered endpoint, run curl:
                 - Full response (baseline size + time)
                 - With pagination params
                 - With field filtering
                 - With gzip compression
                 - Conditional GET (ETag → 304?)
                 - Range request (206?)
                 - CBOR variant
                 - Delta/changes endpoint
4. Score      → Compute points per rule based on measurements
5. Report     → Write timestamped JSON report + update latest-report.json
6. Dashboard  → Optionally refresh dashboard/index.html with new data
7. Badge      → Optionally generate badges/green-score.svg
```

## OpenAPI Auto-Discovery

The analyzer tries these paths in order until one returns a valid spec:

```
/api/v3/api-docs          (springdoc with /api/ prefix)
/v3/api-docs              (springdoc — Spring Boot)
/v3/api-docs.yaml         (springdoc YAML)
/v2/api-docs              (springfox legacy)
/openapi.json             (generic)
/openapi.yaml             (generic)
/swagger/v1/swagger.json  (.NET Swashbuckle)
/swagger.json             (generic)
/swagger.yaml             (generic)
```

You can also pass a **local file** (`--swagger ./my-spec.yaml`).

## Reports Format

Reports are JSON files: `reports/green-score-report-YYYYMMDD_HHMMSS.json`

`latest-report.json` always points to the most recent report.

Per-endpoint analysis is stored in `reports/analysis/endpoints/`.

## Conventions

- Python 3.8+ (only stdlib + pyyaml)
- Bash scripts are POSIX-compatible, auto-detect Docker/Podman
- Dashboard is **self-contained HTML** — no build step, no npm, just open in browser
- Reports are timestamped; `latest-report.json` = copy/symlink of newest
- The installer (`installer.sh`) copies greenanalyzer/ into any git repo on a feature branch
- All scripts resolve paths relative to their own location (`$SCRIPT_DIR`, `$GREEN_DIR`)

## Adding a New Green Score Rule

1. **Define** the rule in `GREEN_RULES` dict in `scripts/green-api-auto-discover.py`
2. **Implement** the measurement logic in the same file (curl-based or response inspection)
3. **Add scoring** in the score computation section
4. **Add visualization** in `dashboard/index.html` (chart + detail section)
5. **Update** this AGENTS.md scoring table

