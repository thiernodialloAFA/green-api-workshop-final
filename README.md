# 🌿 Green Architecture : moins de gras, plus d'impact, plus d'efficacité !

![Green Score](badges/green-score.svg)

> **Devoxx France 2026 — Tools in Action**
>
> Vos APIs ont pris un peu de poids ? Elles consomment plus que nécessaire ?
> Pas de panique, on sort la boîte à outils pour leur faire un **Green relooking** !

[![Green API Score CI](https://github.com/thiernodialloAFA/green-api-workshop-final/actions/workflows/pr-green-api.yml/badge.svg)](https://github.com/thiernodialloAFA/green-api-workshop-final/actions)

---

## 🎯 Objectif

Appliquer pas à pas le framework **[API Green Score](https://github.com/API-Green-Score/APIGreenScore)** sur une API réelle, avec des **outils open-source** et des **métriques concrètes**, pour obtenir une API plus légère, plus rapide, et un impact environnemental réduit.

## 📐 Règles API Green Score couvertes dans cette demo
- **DE11** Pagination, **DE08** Filtering, **US01** Query params
- **DE01/USXX** Compression (Gzip), **DE02/DE03** HTTP Cache (ETag/304)

| Catégorie | Règle | Description | Points  |
|-----------|-------|-------------|---------|
| Data Exchange | **DE11** | Pagination obligatoire | 15      |
| Data Exchange | **DE08** | Filtrage de champs (`fields=`) | 25      |
| Data Exchange | **DE01** | Compression (Gzip/Brotli) | 30      |
| Usage | **LO01** | Observabilité (logs payload/latence) | 15      |
| Usage | **US07** | Rate Limiting | 15      |
| | | **Total** | **100** |

## 📁 Structure du projet

```
green-api-workshop-devoxx/
├── green-api-baseline/        # 🔴 API naïve (AVANT) — port 8080
│   ├── src/main/java/         #    Pas de pagination, pas de cache, pas de compression
│   └── pom.xml
├── green-api-optimized/       # 🟢 API optimisée (APRÈS) — port 8081
│   ├── src/main/java/         #    Pagination, fields, gzip, ETag, delta, range, CBOR
│   └── pom.xml
├── scripts/                   # 📊 Scripts de mesure curl
│   ├── green-score-analyzer.sh  # 🌿 Analyseur automatisé + calcul Green Score
│   ├── measure_baseline.sh
│   ├── measure_optimized.sh
│   └── ...
├── dashboard/                 # 📈 Dashboard HTML de restitution
│   └── index.html             #    Scores, graphiques avant/après, historique
├── reports/                   # 📄 Rapports JSON générés
├── docs/slides/               # 🎤 Slides de présentation
├── .github/workflows/         # 🤖 CI GitHub Actions
│   └── pr-green-api.yml       #    Build + Green Score + Spectral lint
├── .spectral.yml              # 🔬 Règles Spectral OpenAPI (éco-conception)
├── docker-compose.yml         # 🐳 Orchestration Docker
├── WORKSHOP.md                # 📝 Déroulé clé-en-main (50 min)
├── CHECKLIST.md               # ✅ Checklist de review
├── MAPPING.md                 # 🗺️ Mapping pratiques → règles
└── ADVANCED.md                # 🚀 Exercices avancés
```

## 🚀 Démarrage rapide

> ⚠️ **ATTENTION — Les options ci-dessous sont EXCLUSIVES.**
> Choisissez **une seule** option de démarrage. Ne les lancez **pas** en parallèle : chaque option démarre les mêmes services sur les mêmes ports.

---

### 🅰️ Option 0 : Script start (local)

> **🐧 Linux / macOS**
> ```bash
> # Dataset plus gros pour accentuer le contraste avant/après
> DATASET_SIZE=1000000 bash scripts/start.sh --analyze
> ```

> **🪟 Windows (PowerShell)**
> ```powershell
> $env:DATASET_SIZE=1000000
> .\scripts\start.ps1 -Analyze
> ```

---

### ──────────────────── OU ────────────────────

---

### 🅱️ Option 1 : Maven (local)

> **🐧 Linux / macOS: sur 3 terminaux en //**
> ```bash
> # Terminal 1 — Baseline (API naïve, port 8080)
> cd green-api-baseline && mvn spring-boot:run
>
> # Terminal 2 — Optimized (API green, port 8081)
> cd green-api-optimized && mvn spring-boot:run
>
> # Terminal 3 — Analyse automatisée
> cd scripts && bash green-score-analyzer.sh
> ```

> **🪟 Windows (PowerShell): sur 3 terminaux en //**
> ```powershell
> # Terminal 1 — Baseline (API naïve, port 8080)
> cd green-api-baseline ; mvn spring-boot:run
>
> # Terminal 2 — Optimized (API green, port 8081)
> cd green-api-optimized ; mvn spring-boot:run
>
> # Terminal 3 — Analyse automatisée
> cd scripts ; .\green-score-analyzer.ps1
> ```

---

### ──────────────────── OU ────────────────────

---

### 🅲 Option 2 : Docker Compose

> **🐧 Linux / macOS**
> ```bash
> docker-compose up --build
> # → Baseline:  http://localhost:8080
> # → Optimized: http://localhost:8081
> # → Dashboard: http://localhost:3000
> ```

> **🪟 Windows (PowerShell)**
> ```powershell
> docker-compose up --build
> # → Baseline:  http://localhost:8080
> # → Optimized: http://localhost:8081
> # → Dashboard: http://localhost:3000
> ```

---

### ──────────────────── OU ────────────────────

---

### 🅳 Option 3 : Script de démo (présentation live)

> **🐧 Linux / macOS**
> ```bash
> DATASET_SIZE=1000000 bash scripts/run-demo_light.sh
> ```

> **🪟 Windows (PowerShell)**
> ```powershell
> $env:DATASET_SIZE=1000000
> .\scripts\run-demo_light.ps1
> ```

## 📊 Dashboard

Ouvrez `dashboard/index.html` dans votre navigateur pour visualiser :

- 🌿 **Green Score /100** avec grade (A+ → E)
- 📋 **Détail par règle** API Green Score
- 📊 **Comparaison avant/après** (barres visuelles)
- 🔑 **Métriques clés** (payload, compression, 304)
- 📐 **Table de mesures** détaillée par endpoint
- 📈 **Historique des scores** (tracking dans le temps)

Le dashboard charge automatiquement `reports/latest-report.json` ou permet de charger manuellement un rapport.

## 🤖 Automatisation CI

Chaque PR déclenche automatiquement :

1. **Build** des deux modules
2. **Green Score Analysis** — démarre les 2 APIs, exécute l'analyseur, vérifie les assertions
3. **Spectral Lint** — valide l'OpenAPI spec contre les règles Green API
4. **Commentaire PR** — poste le score détaillé directement sur la PR

## 📏 Mesurer en live


## 📚 Liens utiles

- [API Green Score — Référentiel de règles](https://github.com/API-Green-Score/APIGreenScore)
- [API Green Score — Backend](https://github.com/API-Green-Score/API-Green-Score-Backend)
- [API Green Score — Training](https://github.com/API-Green-Score/training-student)
- [Spectral — OpenAPI Linter](https://stoplight.io/open-source/spectral)
- [Devoxx France](https://www.devoxx.fr/)

## 📝 Documents de l'atelier

- [Déroulé clé-en-main (50 min)](WORKSHOP.md)
- [Checklist de review](CHECKLIST.md)
- [Mapping pratiques → règles](MAPPING.md)
- [Exercices avancés](ADVANCED.md)
- Slides : `docs/slides/`

## 🏗️ Pré-requis

- Java 17+
- Maven 3.9+
- `curl`
- Python 3 (pour le script d'analyse)
- Docker & Docker Compose (optionnel)
- Node.js (optionnel, pour Spectral)

## 📄 Licence

MIT — Libre d'utilisation, de modification et de redistribution.
## Useful Documents
- [Green API Checklist (PR)](CHECKLIST.md)
- Workshop slides: `docs/slides/Green-API-Workshop.pptx`
- [Turnkey workshop guide](WORKSHOP.md)
