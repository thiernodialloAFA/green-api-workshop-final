# 🗺️ API Green Score ↔ RGESN Mapping

> Correspondance entre les règles du [API Green Score](https://github.com/API-Green-Score/APIGreenScore) et le [RGESN](https://ecoresponsable.numerique.gouv.fr/publications/referentiel-general-ecoconception/) (Référentiel Général d'Écoconception de Services Numériques).

---

## À propos des deux référentiels

| | API Green Score | RGESN |
|---|---|---|
| **Portée** | REST APIs uniquement | Services numériques (web, mobile, APIs, infra…) |
| **Origine** | Collectif API Green Score (communauté) | DINUM / MiNumEco / INR / ADEME (institutionnel FR) |
| **Granularité** | 9 règles techniques mesurables, score /100 | 79 critères répartis en 8 thématiques |
| **Approche** | Mesure automatisée (curl, bytes, ms) | Audit / checklist déclarative |

---

## Vue synthétique

```
┌─────────────────────────────────────────────────────────────────────┐
│                        API GREEN SCORE                              │
│                       (9 règles, /100 pts)                          │
├──────────┬──────────┬──────────┬──────────┬──────────┬──────────────┤
│  DE11    │  DE08    │  DE01    │ DE02/03  │  DE06    │  Range 206   │
│ Paginat° │ Fields  │ Compress │ Cache    │ Delta    │ Partial      │
│  15 pts  │  15 pts │  15 pts  │  15 pts  │  10 pts  │  10 pts     │
├──────────┴──────────┴──────────┴──────────┴──────────┴──────────────┤
│  AR02 CBOR (10 pts)  │  LO01 Observ. (5 pts) │ US07 Rate Lim (5pt)│
└──────────────────────┴────────────────────────┴────────────────────┘
                              ↕ mapping ↕
┌─────────────────────────────────────────────────────────────────────┐
│                            RGESN                                    │
│                    (79 critères, 8 thématiques)                      │
├─────────┬───────────┬──────────┬──────────┬───────────┬─────────────┤
│Stratégie│Spécific.  │Architect.│  UX/UI   │ Contenus  │ Frontend    │
├─────────┴───────────┴──────────┴──────────┴───────────┼─────────────┤
│               Backend                                  │Hébergement  │
└────────────────────────────────────────────────────────┴─────────────┘
```

---

## Mapping détaillé

### DE11 — Pagination (15 pts)

| | |
|---|---|
| **Green Score** | Les endpoints de collection supportent `?page=&size=` — réduction du payload vs réponse complète |
| **Mesure** | `payload_paginated / payload_full < seuil` |

```
RGESN mappé :
┌──────────────┬───────────────────────────────────────────────────────┐
│ 🔵 5.5       │ Le service numérique a-t-il été conçu avec des      │
│ (Backend)    │ mécanismes de modération de la volumétrie des        │
│              │ données échangées ?                                   │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🔵 4.5       │ Le service numérique évite-t-il les téléchargements  │
│ (Architecture)│ de données inutiles ?                                │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🟢 4.2       │ Le service numérique utilise-t-il un mécanisme de    │
│ (Architecture)│ pagination ?                                         │
└──────────────┴───────────────────────────────────────────────────────┘
```

**Pourquoi ce mapping ?** La pagination est le levier n°1 de réduction du volume de données échangées. Le RGESN 5.5 cible exactement la modération de la volumétrie côté backend. Le critère 4.2 mentionne explicitement la pagination comme pattern architectural. Le critère 4.5 complète en visant l'élimination des données inutiles.

---

### DE08 — Filtrage de champs (15 pts)

| | |
|---|---|
| **Green Score** | `?fields=id,title` réduit le payload en ne retournant que les champs demandés |
| **Mesure** | `payload_filtered / payload_full < seuil` |

```
RGESN mappé :
┌──────────────┬───────────────────────────────────────────────────────┐
│ 🔵 5.5       │ Modération de la volumétrie des données échangées    │
│ (Backend)    │                                                       │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🔵 4.5       │ Éviter les téléchargements de données inutiles       │
│ (Architecture)│                                                      │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🟢 5.1       │ Le service numérique utilise-t-il un mécanisme       │
│ (Backend)    │ permettant de ne transmettre que les données          │
│              │ strictement nécessaires ?                              │
└──────────────┴───────────────────────────────────────────────────────┘
```

**Pourquoi ce mapping ?** Le filtrage de champs (`fields=`) est l'implémentation technique directe du principe RGESN 5.1 : ne transmettre que les données strictement nécessaires. C'est aussi une déclinaison concrète de la modération volumétrique (5.5) et de l'évitement des données inutiles (4.5).

---

### DE01 — Compression Gzip (15 pts)

| | |
|---|---|
| **Green Score** | `Accept-Encoding: gzip` réduit la taille sur le réseau |
| **Mesure** | `payload_gzip / payload_raw < seuil` |

```
RGESN mappé :
┌──────────────┬───────────────────────────────────────────────────────┐
│ 🔵 5.5       │ Modération de la volumétrie des données échangées    │
│ (Backend)    │                                                       │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🔵 5.4       │ Le service numérique utilise-t-il un mécanisme de    │
│ (Backend)    │ compression des données échangées ?                   │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🔵 8.4       │ Le service numérique optimise-t-il la consommation   │
│ (Hébergement)│ de bande passante ?                                   │
└──────────────┴───────────────────────────────────────────────────────┘
```

**Pourquoi ce mapping ?** Le RGESN 5.4 cible explicitement la compression des données échangées — c'est un mapping 1:1 direct. Le 8.4 élargit au niveau hébergement : la compression réduit la bande passante consommée par l'infrastructure.

---

### DE02/DE03 — Cache HTTP / ETag / 304 (15 pts)

| | |
|---|---|
| **Green Score** | Présence de `ETag` → `If-None-Match` → réponse `304 Not Modified` (0 bytes utiles) |
| **Mesure** | Le serveur retourne un 304 quand la ressource n'a pas changé |

```
RGESN mappé :
┌──────────────┬───────────────────────────────────────────────────────┐
│ 🔵 5.3       │ Le service numérique utilise-t-il un mécanisme de    │
│ (Backend)    │ cache serveur pour les données les plus utilisées ?   │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🔵 6.3       │ Le service numérique met-il en œuvre des mécanismes  │
│ (Frontend)   │ de cache HTTP côté client ?                           │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🔵 5.5       │ Modération de la volumétrie des données échangées    │
│ (Backend)    │                                                       │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🔵 4.3       │ Le service numérique a-t-il une stratégie de cache ? │
│ (Architecture)│                                                      │
└──────────────┴───────────────────────────────────────────────────────┘
```

**Pourquoi ce mapping ?** ETag/304 combine cache serveur (RGESN 5.3), cache client HTTP (6.3) et stratégie de cache architecturale (4.3). Un 304 = 0 bytes transférés = réduction maximale de volumétrie (5.5). C'est le mécanisme de cache le plus pertinent pour les APIs REST.

---

### DE06 — Delta / Changes (10 pts)

| | |
|---|---|
| **Green Score** | Endpoint `/changes?since=` retourne uniquement les modifications récentes |
| **Mesure** | Existence d'un endpoint delta fonctionnel |

```
RGESN mappé :
┌──────────────┬───────────────────────────────────────────────────────┐
│ 🔵 5.1       │ Ne transmettre que les données strictement            │
│ (Backend)    │ nécessaires                                           │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🔵 5.5       │ Modération de la volumétrie des données échangées    │
│ (Backend)    │                                                       │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🔵 4.5       │ Éviter les téléchargements de données inutiles       │
│ (Architecture)│                                                      │
└──────────────┴───────────────────────────────────────────────────────┘
```

**Pourquoi ce mapping ?** Le pattern delta est une forme avancée de réduction : au lieu de re-télécharger toute la collection, on ne récupère que les changements. C'est l'incarnation du principe "données strictement nécessaires" (5.1) appliqué à la dimension temporelle.

---

### Range 206 — Partial Content (10 pts)

| | |
|---|---|
| **Green Score** | `Range: bytes=0-199` → réponse `206 Partial Content` |
| **Mesure** | Le serveur retourne un 206 avec le segment demandé |

```
RGESN mappé :
┌──────────────┬───────────────────────────────────────────────────────┐
│ 🔵 5.5       │ Modération de la volumétrie des données échangées    │
│ (Backend)    │                                                       │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🔵 5.1       │ Ne transmettre que les données strictement            │
│ (Backend)    │ nécessaires                                           │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🟢 4.10      │ Le service numérique optimise-t-il le téléchargement │
│ (Architecture)│ de fichiers ou de données volumineuses ?             │
└──────────────┴───────────────────────────────────────────────────────┘
```

**Pourquoi ce mapping ?** Le Range request est le mécanisme HTTP natif pour le téléchargement partiel (RGESN 4.10). Il permet de ne transférer qu'un fragment précis, aligné avec 5.1 (données strictement nécessaires) et 5.5 (modération volumétrique).

---

### AR02 — Format binaire CBOR (10 pts)

| | |
|---|---|
| **Green Score** | Endpoint CBOR vs JSON — réduction du payload par sérialisation binaire |
| **Mesure** | `payload_cbor / payload_json < seuil` |

```
RGESN mappé :
┌──────────────┬───────────────────────────────────────────────────────┐
│ 🔵 5.2       │ Le service numérique utilise-t-il des formats de     │
│ (Backend)    │ données adaptés au contexte d'utilisation ?           │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🔵 5.5       │ Modération de la volumétrie des données échangées    │
│ (Backend)    │                                                       │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🔵 4.1       │ Le service numérique a-t-il évalué les formats de    │
│ (Architecture)│ données les plus adaptés ?                           │
└──────────────┴───────────────────────────────────────────────────────┘
```

**Pourquoi ce mapping ?** CBOR est un format binaire compact (~30-50% plus petit que JSON). Le RGESN 5.2 et 4.1 demandent explicitement d'évaluer et choisir les formats les plus adaptés au contexte. Pour des échanges machine-to-machine, un format binaire est le choix éco-responsable.

---

### LO01 — Observabilité (5 pts)

| | |
|---|---|
| **Green Score** | Logging filter qui trace bytes + ms par requête ; endpoints health/metrics exposés |
| **Mesure** | Présence d'un endpoint actuator/health/metrics |

```
RGESN mappé :
┌──────────────┬───────────────────────────────────────────────────────┐
│ 🔵 8.5       │ Le service numérique utilise-t-il un outil de        │
│ (Hébergement)│ monitoring pour mesurer sa consommation de ressources?│
├──────────────┼───────────────────────────────────────────────────────┤
│ 🔵 8.6       │ Le service numérique met-il en place des indicateurs │
│ (Hébergement)│ de performance environnementale ?                     │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🔵 1.6       │ Le service numérique comporte-t-il un plan de        │
│ (Stratégie)  │ mesure de son empreinte environnementale ?            │
└──────────────┴───────────────────────────────────────────────────────┘
```

**Pourquoi ce mapping ?** Sans observabilité, pas de mesure. Le RGESN 8.5 et 8.6 exigent un monitoring des ressources et des indicateurs environnementaux. L'observabilité API (bytes, latence, codes retour) est le socle de toute démarche de mesure (1.6).

---

### US07 — Rate Limiting (5 pts)

| | |
|---|---|
| **Green Score** | Mécanisme de rate limiting → 429 Too Many Requests |
| **Mesure** | Le serveur retourne 429 en cas d'excès de requêtes |

```
RGESN mappé :
┌──────────────┬───────────────────────────────────────────────────────┐
│ 🔵 5.6       │ Le service numérique se protège-t-il contre les      │
│ (Backend)    │ utilisations abusives ?                               │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🔵 4.8       │ Le service numérique utilise-t-il des mécanismes de  │
│ (Architecture)│ régulation de la charge ?                            │
├──────────────┼───────────────────────────────────────────────────────┤
│ 🔵 8.3       │ Le service numérique dimensionne-t-il son            │
│ (Hébergement)│ infrastructure en fonction de l'usage réel ?          │
└──────────────┴───────────────────────────────────────────────────────┘
```

**Pourquoi ce mapping ?** Le rate limiting protège contre les abus (5.6), régule la charge (4.8) et évite le surdimensionnement défensif de l'infrastructure (8.3). Sans rate limiting, un pic de trafic abusif force un autoscaling coûteux en ressources.

---

## Matrice de couverture croisée

```
                    │ RGESN thématiques couvertes par API Green Score
                    │
                    │ Stratégie  Spécif.  Archi.  UX  Backend  Front.  Héberg.
────────────────────┼──────────────────────────────────────────────────────────
DE11 Pagination     │                      4.2         5.5
                    │                      4.5         5.1
DE08 Fields         │                      4.5         5.1
                    │                                   5.5
DE01 Compression    │                                   5.4            8.4
                    │                                   5.5
DE02/03 Cache       │                      4.3         5.3     6.3
                    │                                   5.5
DE06 Delta          │                      4.5         5.1
                    │                                   5.5
Range 206           │                      4.10        5.1
                    │                                   5.5
AR02 CBOR           │                      4.1         5.2
                    │                                   5.5
LO01 Observabilité  │    1.6                                           8.5
                    │                                                   8.6
US07 Rate Limit     │                      4.8         5.6            8.3
────────────────────┼──────────────────────────────────────────────────────────
Couverture          │    ✓                  ✓           ✓       ✓      ✓
```

---

## Zones RGESN non couvertes par API Green Score

Le Green Score se concentre sur l'**échange de données API**. Les thématiques RGESN suivantes restent hors périmètre :

| Thématique RGESN | Exemples de critères | Pourquoi hors périmètre |
|---|---|---|
| **Spécifications** (2.x) | Besoins utilisateur, fonctionnalités essentielles | Niveau product/business, pas mesurable sur une API |
| **UX/UI** (3.x) | Accessibilité, sobriété des interfaces | APIs n'ont pas d'interface utilisateur directe |
| **Contenus** (7.x) | Optimisation images, vidéos, polices | Concerne le frontend, pas les APIs REST |
| **Hébergement partiel** (8.1, 8.2) | PUE datacenter, énergie renouvelable | Niveau infrastructure, hors contrôle du développeur API |

---

## Conclusion

```
┌───────────────────────────────────────────────────────────────────┐
│                                                                   │
│   API Green Score = sous-ensemble MESURABLE et AUTOMATISABLE     │
│   du RGESN appliqué aux APIs REST                                │
│                                                                   │
│   RGESN   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  (79 critères)     │
│   Green Score  ━━━━━━━━━━━  (9 règles)                           │
│                ↑                                                  │
│   Focus : Backend + Architecture + Hébergement                   │
│   Force : Automatisation, mesure continue, CI/CD                 │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

> **L'API Green Score n'est pas un concurrent du RGESN** — c'est une **implémentation opérationnelle automatisée** d'un sous-ensemble du RGESN, focalisée sur ce qui est mesurable par des outils sur les APIs REST. Le RGESN reste le cadre de référence global pour l'écoconception des services numériques.

