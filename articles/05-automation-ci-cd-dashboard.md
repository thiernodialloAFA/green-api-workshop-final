# Automation: CI/CD, Dashboard & Continuous Green Scoring

*Part 5 — the final article. You know the rules. Now let's make it automatic, continuous, and visible.*

---

## The Goal

```
  ┌──────────────────────────────────────────────────────────────┐
  │  GREEN SCORE = FIRST-CLASS DEVOPS METRIC                     │
  │                                                              │
  │  ✅ Measured automatically      on every build               │
  │  ✅ Visible                     in a dashboard               │
  │  ✅ Enforced                    CI gate (min score)          │
  │  ✅ Reported                    on every pull request        │
  │  ✅ Tracked                     historical trends            │
  └──────────────────────────────────────────────────────────────┘
```

---

## The Full Architecture

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │                                                                     │
  │  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐     │
  │  │ Baseline │    │Optimized │    │ Analyzer │    │Dashboard │     │
  │  │ API      │    │ API      │    │ Script   │    │ (HTML)   │     │
  │  │ :8080    │    │ :8081    │    │ (bash)   │    │ :3000    │     │
  │  └────┬─────┘    └────┬─────┘    └────┬─────┘    └────┬─────┘     │
  │       │               │               │               │           │
  │       │   curl ◄──────┘───────────────┘               │           │
  │       │   measurements                                │           │
  │       │               │                               │           │
  │       │               ▼                               │           │
  │       │    ┌────────────────────┐                     │           │
  │       │    │   JSON Report      │─────────────────────┘           │
  │       │    │   (reports/)       │                                  │
  │       │    └─────────┬──────────┘                                  │
  │       │              │                                             │
  │       │         ┌────┴────┐                                        │
  │       │         │ CI/CD   │                                        │
  │       │         │ GitHub  │                                        │
  │       │         │ Actions │                                        │
  │       │         └────┬────┘                                        │
  │       │              │                                             │
  │       │    ┌─────────┴─────────┐                                   │
  │       │    │  Score >= 50?     │                                   │
  │       │    │  YES → ✅ Pass    │                                   │
  │       │    │  NO  → ❌ Fail    │                                   │
  │       │    └───────────────────┘                                   │
  │       │                                                            │
  └───────┴────────────────────────────────────────────────────────────┘
```

---

## Step 1: The Analyzer

```
  ┌────────────────────────────────────────────────────────────────┐
  │  green-score-analyzer.sh                                       │
  │                                                                │
  │  1. Discover    /v3/api-docs ──► list all endpoints            │
  │       │                                                        │
  │       ▼                                                        │
  │  2. Measure     curl each endpoint                             │
  │       │         ├── DE11: paginated vs full payload             │
  │       │         ├── DE08: filtered vs paginated                 │
  │       │         ├── DE01: with Accept-Encoding: gzip           │
  │       │         ├── DE02: 1st call → ETag, 2nd → 304?         │
  │       │         ├── DE06: /changes?since= → bytes?             │
  │       │         ├── 206:  Range: bytes=0-199 → 206?            │
  │       │         ├── LO01: PayloadLoggingFilter detected?       │
  │       │         ├── US07: RateLimitFilter detected?            │
  │       │         └── AR02: /books/cbor → bytes vs JSON?         │
  │       │                                                        │
  │       ▼                                                        │
  │  3. Score       Calculate points per rule                      │
  │       │                                                        │
  │       ▼                                                        │
  │  4. Report      Generate JSON → reports/latest-report.json     │
  └────────────────────────────────────────────────────────────────┘
```

```bash
# Run it
bash greenanalyzer/scripts/green-score-analyzer_withdiscovery.sh
bash greenanalyzer/scripts/green-score-analyzer_withdiscovery.sh --debug
```

---

## Step 2: The JSON Report

```json
{
  "timestamp": "2026-03-26T14:01:00Z",
  "green_score": {
    "total": 90.4,  "max": 100,  "grade": "A+",
    "breakdown": {
      "DE11_pagination": 15,  "DE08_fields": 15,
      "DE01_compression": 8,  "DE02_DE03_cache": 15,
      "DE06_delta": 10,       "range_206": 10,
      "LO01_observability": 5,"US07_rate_limit": 5,
      "AR02_format_cbor": 7.4
    }
  },
  "measurements": {
    "baseline":  { "full_payload": { "size_download": 138327793 } },
    "optimized": { "pagination":   { "size_download": 3805 } }
  },
  "spectral": { "issues_count": 0 }
}
```

---

## Step 3: The Dashboard

Inspired by **AR05** (*"Carbon footprint dashboard"*):

```
  ┌──────────────────────────────────────────────────────────────────┐
  │                    GREEN SCORE DASHBOARD                         │
  │                                                                  │
  │  ┌────────────┐  ┌────────────────┐  ┌────────────────────────┐ │
  │  │            │  │  Rule Detail   │  │  Before / After        │ │
  │  │   90.4     │  │  DE11 ██ 15/15 │  │  Baseline  ████ 138MB │ │
  │  │   /100     │  │  DE08 ██ 15/15 │  │  Optimized █    3.8KB │ │
  │  │   A+  🌿   │  │  DE01 █░  8/15 │  │                       │ │
  │  │            │  │  DE02 ██ 15/15 │  │  Response Times        │ │
  │  │   Score    │  │  DE06 ██ 10/10 │  │  Baseline  ████ 1.24s │ │
  │  │   Gauge    │  │  206  ██ 10/10 │  │  Optimized █    0.06s │ │
  │  └────────────┘  └────────────────┘  └────────────────────────┘ │
  │                                                                  │
  │  ┌────────────────┐  ┌─────────────────┐  ┌──────────────────┐ │
  │  │ Key Metrics    │  │ Energy Summary  │  │ CO2 Emissions    │ │
  │  │                │  │                 │  │                  │ │
  │  │ Payload: 974B  │  │ Network: 0.003W │  │ Per call: 0.01g │ │
  │  │ Gzip: -50%     │  │ Server:  0.001W │  │ Annual:  36.5g  │ │
  │  │ Cache: 100%    │  │ Total:   0.004W │  │ (vs 151 kg)     │ │
  │  └────────────────┘  └─────────────────┘  └──────────────────┘ │
  │                                                                  │
  │  ┌──────────────────────────────────────────────────────────┐   │
  │  │  Historical Timeline                                     │   │
  │  │  Score                                                   │   │
  │  │  100│         ·  · ·  ·                                  │   │
  │  │   80│    ·  ·                                            │   │
  │  │   60│  ·                                                 │   │
  │  │   40│·                                                   │   │
  │  │     └──────────────────────────────────────► Time        │   │
  │  └──────────────────────────────────────────────────────────┘   │
  └──────────────────────────────────────────────────────────────────┘
```

### Energy Parameters

```
  ┌───────────────────────────────────────────────────────┐
  │  Parameter              Default        Source         │
  ├───────────────────────────────────────────────────────┤
  │  Network factor         0.06 kWh/GB    Shift Project  │
  │  Server power           25W            Light VM est.  │
  │  Carbon intensity       53 gCO2/kWh    Elec Maps (FR)│
  │  Requests/day           10,000         Configurable   │
  │  Days/year              365            Configurable   │
  └───────────────────────────────────────────────────────┘
```

---

## Step 4: Spectral — Lint the Contract

```
  ┌────────────────────────────────────────────────────────────────┐
  │  .spectral.yml — OpenAPI eco-design rules                      │
  │                                                                │
  │  ┌──────────────────────────────┐                              │
  │  │ GET /books                   │                              │
  │  │   parameters:                │                              │
  │  │     - page ✅                │   green-pagination-required  │
  │  │     - size ✅                │   ──► PASS                   │
  │  └──────────────────────────────┘                              │
  │                                                                │
  │  ┌──────────────────────────────┐                              │
  │  │ GET /users                   │                              │
  │  │   parameters:                │                              │
  │  │     (none)                   │   green-pagination-required  │
  │  └──────────────────────────────┘   ──► FAIL ⚠️                │
  └────────────────────────────────────────────────────────────────┘
```

```bash
npx @stoplight/spectral-cli lint http://localhost:8081/v3/api-docs \
  --ruleset .spectral.yml --format json --output reports/spectral-results.json
```

---

## Step 5: CI/CD — GitHub Actions

```
  ┌────────────────────────────────────────────────────────────────┐
  │  .github/workflows/pr-green-api.yml                            │
  │                                                                │
  │  on: pull_request                                              │
  │                                                                │
  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
  │  │ Checkout │─►│ Build    │─►│ Start    │─►│ Analyze  │     │
  │  │ + JDK 17 │  │ mvn pkg  │  │ both APIs│  │ Green    │     │
  │  └──────────┘  └──────────┘  │ :8080    │  │ Score    │     │
  │                               │ :8081    │  └─────┬────┘     │
  │                               └──────────┘        │          │
  │                                                    ▼          │
  │                              ┌──────────┐  ┌──────────┐      │
  │                              │ Comment  │◄─│ Check    │      │
  │                              │ on PR    │  │ threshold│      │
  │                              │ "90.4/100│  │ >= 50?   │      │
  │                              │  A+"     │  │ YES ✅   │      │
  │                              └──────────┘  │ NO  ❌   │      │
  │                                            └──────────┘      │
  └────────────────────────────────────────────────────────────────┘
```

### Threshold

```json
{ "minScore": 50, "note": "Minimum Green Score to prevent regressions" }
```

> PR drops below 50 → **build fails** → regression blocked.

---

## Step 6: Docker Compose — One Command

```
  ┌────────────────────────────────────────────────────────────────┐
  │  docker compose up --build                                     │
  │                                                                │
  │  ┌────────────┐   ┌────────────┐   ┌────────────┐            │
  │  │  baseline   │   │ optimized  │   │ dashboard  │            │
  │  │  :8080      │   │  :8081     │   │  :3000     │            │
  │  │  Spring Boot│   │ Spring Boot│   │  nginx     │            │
  │  └────────────┘   └────────────┘   └────────────┘            │
  │                                                                │
  │  Then: bash greenanalyzer/scripts/green-score-analyzer.sh      │
  │  Open: http://localhost:3000                                   │
  └────────────────────────────────────────────────────────────────┘
```

---

## The Complete CI Workflow

```
  Developer
     │
     ▼
  git push / PR
     │
     ▼
  ┌────────────┐
  │ CI Trigger │
  └─────┬──────┘
        │
   ┌────┴────┐
   │         │
   ▼         ▼
  Build    Spectral
  APIs     Lint OpenAPI
   │         │
   ▼         │
  Start      │
  :8080      │
  :8081      │
   │         │
   └────┬────┘
        │
        ▼
  ┌──────────────┐
  │ Green Score  │
  │ Analysis     │
  │ (curl)       │
  └──────┬───────┘
         │
         ▼
  ┌──────────────┐
  │ JSON Report  │
  └──────┬───────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
  Score     Comment
  >= 50?    on PR
    │       "90.4 A+"
    │
    ▼
  ✅ Pass
  ❌ Fail
```

---

## Key Takeaways

```
  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │  1. AUTOMATE EARLY    Don't wait for production         │
  │  2. SET THRESHOLDS    Min score prevents regressions    │
  │  3. MAKE IT VISIBLE   Dashboard for all stakeholders    │
  │  4. TRACK OVER TIME   Historical trends reveal impact   │
  │  5. LINT THE CONTRACT Catch issues at design time       │
  │                                                         │
  └─────────────────────────────────────────────────────────┘
```

---

## Series Recap

```
  ┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐
  │ Art. 1 │     │ Art. 2 │     │ Art. 3 │     │ Art. 4 │     │ Art. 5 │
  │ Intro  │     │Domains │     │  Data  │     │Usage & │     │ Auto-  │
  │        │     │        │     │Exchange│     │ Archi  │     │ mation │
  │ WHY    │     │ WHAT   │     │ HOW    │     │ HOW    │     │ WHEN   │
  │        │     │(rules) │     │(DE*)   │     │(US/AR) │     │(CI/CD) │
  │        │     │        │     │        │     │        │     │📍HERE  │
  └────────┘     └────────┘     └────────┘     └────────┘     └────────┘
     │               │               │               │               │
     ▼               ▼               ▼               ▼               ▼
  APIs have a    25+ rules       99.99%          EDA, rate       Measure
  hidden cost    across 7        payload         limiting,       continuously,
                 domains         reduction       CBOR, logs      enforce gates
```

---

## Get Started

```bash
git clone https://github.com/thiernodialloAFA/green-api-workshop-final.git
cd green-api-workshop-final
DATASET_SIZE=1000000 bash scripts/start.sh --analyze --appname "my-api" --creedengo
open http://localhost:3000
```

**Resources:**
- [API Green Score Framework](https://github.com/API-Green-Score/APIGreenScore)
- [Collectif API Thinking](https://www.collectif-api-thinking.com/)
- [Best Practices Guide (PDF)](https://www.collectif-api-thinking.com/assets/deliverables/worksites/50_CAT_API_Sustainable_IT.pdf)
- [Evaluation Grid (Excel)](https://www.collectif-api-thinking.com/assets/deliverables/worksites/48_CAT_Sustainable_API_GreenScore_V1-2.xlsx)

---

*Green APIs aren't a destination — they're a practice. Measure, improve, repeat.*

*The Excel grid gets you started. Automation keeps you accountable.*

*Less data, more impact.*
