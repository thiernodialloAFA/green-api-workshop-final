# 🌿 Green Architecture : moins de gras, plus d'impact, plus d'efficacité !

[![Green API Score CI](https://github.com/thiernodialloAFA/green-api-workshop-final/actions/workflows/pr-green-api.yml/badge.svg)](https://github.com/thiernodialloAFA/green-api-workshop-final/actions/workflows/pr-green-api.yml)
![Green Score](badges/green-score.svg)

> **Devoxx France 2026 — Tools in Action**
>
> Vos APIs ont pris un peu de poids ? Elles consomment plus que nécessaire ?
> Pas de panique, on sort la boîte à outils pour leur faire un **Green relooking** !


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


## 🏗️ Pré-requis

- Java 17+
- Maven 3.9+
- `curl`
- Python 3 (pour le script d'analyse)
- Docker ou Podman & Docker/Podman Compose (optionnel) (en fonction il faudra adapter les commandes de démarrage du compose)
- Node.js (optionnel, pour Spectral)


### 🅰️ Option 0 : Script start (local)

> **🐧 Linux / macOS**
> ```bash
> # Dataset plus gros pour accentuer le contraste avant/après
> DATASET_SIZE=1000000 bash scripts/start.sh --analyze
> ```
---

### ──────────────────── OU ────────────────────

---
🅰️ Option 0-bis : Script start (Podman Compose 2 terminaux séparés)
> **🐧 Linux / macOS**
> ```bash
> # Terminal 1 — Démarrage des services (API + Dashboard)
> podman compose down --remove-orphans 2>/dev/null || true
> podman compose up --build --force-recreate
> 
> # Terminal 2 — Analyse automatisée
> # Dataset plus gros pour accentuer le contraste avant/après
> DATASET_SIZE=1000000 bash scripts/start_light.sh --analyze
> ```
> 
> **A la fin pour nettoyer les ressources, depuis un terminal utilisez : la commande `docker compose down --remove-orphans` ou `podman compose down --remove-orphans` selon votre choix de conteneurisation**.
---

### ──────────────────── OU ────────────────────

---
### 🅱️ Option 1 : Maven (local)

> **🐧 Linux / macOS: sur 3 terminaux en //**
> ```bash
> # Terminal 1 — Baseline (API naïve, port 8080)
> cd green-api-baseline && mvn spring-boot:run
> 
> **NB: Il faudra faire un Ctrl+C dans ce terminal pour arrêter l API à la fin.**
>
> # Terminal 2 — Optimized (API green, port 8081)
> cd green-api-optimized && mvn spring-boot:run
>
> **NB: Il faudra faire un `Ctrl+C` dans ce terminal pour arrêter l API à la fin.**
> # Terminal 3 — Analyse automatisée
> bash ./scripts/green-score-analyzer_withdiscovery.sh
> ```

---

### ──────────────────── OU ────────────────────

---

### 🅲 Option 2 : Docker Compose (2 terminaux séparés)

> **🐧 Linux / macOS**
> ```bash
> # Terminal 1 — Démarrage des services (API + Dashboard)
> docker compose up --build 
> # → Baseline:  http://localhost:8080
> # → Optimized: http://localhost:8081
> # → Dashboard: http://localhost:3000
> 
> # Terminal 2 — Analyse automatisée
> bash scripts/green-score-analyzer_withdiscovery.sh
> ```
> **NB: A la fin pour nettoyer les ressources, depuis terminal 1 utilisez : la commande  `ctrl + c` et ensuite une des commandes suivantes `docker compose down --remove-orphans` ou `podman compose down --remove-orphans` selon votre choix de conteneurisation**.

### 🅲 Option 2-bis : Podman Compose (2 terminaux separés)

> **🐧 Linux / macOS**
> ```bash
> # Terminal 1 — Démarrage des services (API + Dashboard)
> podman compose down --remove-orphans 2>/dev/null || true
> podman compose up --build 
> # → Baseline:  http://localhost:8080
> # → Optimized: http://localhost:8081
> # → Dashboard: http://localhost:3000
> 
> # Terminal 2 — Analyse automatisée
> bash scripts/green-score-analyzer_withdiscovery.sh
> ```
> 
> **NB: A la fin pour nettoyer les ressources, depuis terminal 1 utilisez : la commande  `ctrl + c` et ensuite une des commandes suivantes `docker compose down --remove-orphans` ou `podman compose down --remove-orphans` selon votre choix de conteneurisation**.

## 📊 Dashboard

Ouvrez  `http://localhost:3000` dans votre navigateur pour visualiser : (ou en fallback, ouvrez `dashboard/index.html` directement)

- 🌿 **Green Score /100** avec grade (A+ → E)
- 📋 **Détail par règle** API Green Score
- 📊 **Comparaison avant/après** (barres visuelles)
- 🔑 **Métriques clés** (payload, compression, 304)
- 📐 **Table de mesures** détaillée par endpoint
- 📈 **Historique des scores** (tracking dans le temps)

Le dashboard charge automatiquement `reports/latest-report.json` ou permet de charger manuellement un rapport.

## 🤖 Automatisation CI: vous avez un exemple de github action dans ce repo qui montre comment automatiser l'analyse du Green Score ./.github/workflows/pr-green-api.yml

Chaque PR déclenche automatiquement :

1. **Build** des deux modules
2. **Green Score Analysis** — démarre les 2 APIs, exécute l'analyseur, vérifie les assertions
3. **Spectral Lint** — valide l'OpenAPI spec contre les règles Green API
4. **Commentaire PR** — poste le score détaillé directement sur la PR

- `.github/workflows/pr-green-api.yml` : build, analyse, assertions, commentaire PR
- `.spectral.yml` : règles OpenAPI éco-conception
- Le score est posté automatiquement sur chaque PR

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

## 📄 Licence

MIT — Libre d'utilisation, de modification et de redistribution.
## Useful Documents
- [Green API Checklist (PR)](CHECKLIST.md)
- [Turnkey workshop guide](WORKSHOP.md)
