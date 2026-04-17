# The 7 Domains of API Green Score: A Complete Map of Green API Practices

*In the [first article](./01-introduction-api-green-score.md), we introduced API Green Score. Now let's explore all 7 domains and the 25+ rules.*

---

## The Big Picture

```
                    ┌─────────────────────────┐
                    │   API GREEN SCORE /100   │
                    └────────────┬────────────┘
                                 │
            ┌────────────────────┼────────────────────┐
            │                    │                    │
            ▼                    ▼                    ▼
   ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
   │  7 DOMAINS      │ │  4 CATEGORIES   │ │  25+ RULES      │
   │                 │ │                 │ │                 │
   │  What to        │ │  How rules are  │ │  Concrete       │
   │  evaluate       │ │  classified     │ │  checks         │
   └─────────────────┘ └─────────────────┘ └─────────────────┘
```

> A single rule can appear in multiple domains (e.g. DE02 Cache belongs to both Data Exchange and Data).

---

## Domain Map

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │                                                                     │
  │   1. API LIFECYCLE         2. DATA EXCHANGE        3. DATA          │
  │   ┌───────────────┐       ┌───────────────┐       ┌──────────────┐ │
  │   │ AR03 US02     │       │ DE01 DE02 DE03│       │ DE02 DE03    │ │
  │   │ US03 US05     │       │ DE05 DE07 DE08│       │ DE06 DE09    │ │
  │   │ US06 US07     │       │ DE11 US01     │       │ DE10 US04    │ │
  │   │               │       │               │       │ US05         │ │
  │   │ 6 rules       │       │ 8 rules       │       │ 7 rules      │ │
  │   └───────────────┘       └───────────────┘       └──────────────┘ │
  │                                                                     │
  │   4. ARCHITECTURE          5. TOOLS               6. INFRA         │
  │   ┌───────────────┐       ┌───────────────┐       ┌──────────────┐ │
  │   │ AR01 AR02     │       │ LO01          │       │ AR04 AR05    │ │
  │   │ AR03          │       │               │       │              │ │
  │   │               │       │ 1 rule        │       │ 2 rules      │ │
  │   │ 3 rules       │       │               │       │              │ │
  │   └───────────────┘       └───────────────┘       └──────────────┘ │
  │                                                                     │
  │   7. COMMUNICATION                                                  │
  │   ┌───────────────┐                                                 │
  │   │ US06          │                                                 │
  │   │               │                                                 │
  │   │ 1 rule        │                                                 │
  │   └───────────────┘                                                 │
  └─────────────────────────────────────────────────────────────────────┘
```

---

## Domain 1: API Lifecycle

```
  WHO uses my API?  WHAT version?  WHEN was the last call?

  ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐
  │ AR03   │   │ US02   │   │ US03   │   │ US05   │   │ US06   │   │ US07   │
  │        │   │        │   │        │   │        │   │        │   │        │
  │ One API│   │Decom-  │   │Max 2   │   │Right   │   │Good    │   │Monitor │
  │per need│   │mission │   │versions│   │API for │   │docs =  │   │error   │
  │        │   │unused  │   │in prod │   │use case│   │reuse   │   │rate    │
  └────────┘   └────────┘   └────────┘   └────────┘   └────────┘   └────────┘

  Impact:
  ┌──────────────────────────────────────────────────────────────────┐
  │  Duplicate API = 2x compute    Unused API = 24/7 waste          │
  │  3 versions = 3x maintenance   Poor docs = gets duplicated      │
  └──────────────────────────────────────────────────────────────────┘
```

---

## Domain 2: Data Exchange — The Biggest Lever (~70% of score)

```
  HOW do we exchange data?  WHAT is the payload size?

  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
  │  DE01   │ │  DE02   │ │  DE03   │ │  DE05   │
  │ Smallest│ │ Use     │ │ Cache   │ │ Align   │
  │ format  │ │ cache   │ │ effici- │ │ cache   │
  │JSON>XML │ │ (ETag)  │ │ ently   │ │ to data │
  └─────────┘ └─────────┘ └─────────┘ └─────────┘
  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
  │  DE07   │ │  DE08   │ │  DE11   │ │  US01   │
  │Customer │ │Filtering│ │Pagina-  │ │ Query   │
  │centric  │ │mechanism│ │tion     │ │ params  │
  │ design  │ │(fields=)│ │available│ │ for GET │
  └─────────┘ └─────────┘ └─────────┘ └─────────┘

  Key insight (DE01 official example):
  ┌──────────────────────────────────────────────────────┐
  │  Same API response:                                  │
  │  JSON = 40 KB    XML = 58 KB    (+43% waste!)       │
  │  On 1M calls/day = 18 GB wasted daily               │
  └──────────────────────────────────────────────────────┘
```

---

## Domain 3: Data

```
  Do we expose ONLY necessary data?  Single point of truth?

  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
  │  DE06   │ │  DE09   │ │  DE10   │ │  US04   │
  │ Partial │ │ OData / │ │ No data │ │Optimize │
  │ cache   │ │ GraphQL │ │ dupli-  │ │queries: │
  │ refresh │ │ when    │ │ cation  │ │only     │
  │         │ │ relevant│ │ in resp │ │necessary│
  └─────────┘ └─────────┘ └─────────┘ └─────────┘

  Key insight (DE10):
  ┌──────────────────────────────────────────────────────┐
  │  "Duplicate data inflates payload, increases         │
  │   processing time. Each piece of data should be      │
  │   essential and distinct." — Redundant = wasted bytes│
  └──────────────────────────────────────────────────────┘
```

---

## Domain 4: Architecture

```
  EDA or REST?  Proximity?  Right model for use case?

  ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
  │      AR01        │   │      AR02        │   │      AR03        │
  │                  │   │                  │   │                  │
  │  Event-Driven    │   │  API close to    │   │  One API per     │
  │  Architecture    │   │  consumer        │   │  need            │
  │                  │   │                  │   │                  │
  │  Polling = waste │   │  Less distance   │   │  Duplicates =    │
  │  EDA = push only │   │  = less energy   │   │  2x resources    │
  └──────────────────┘   └──────────────────┘   └──────────────────┘

  Polling vs EDA:
  ┌──────────────────────────────────────────────────────┐
  │  Polling every 5s = 17,280 useless requests/day     │
  │  EDA (SSE/Webhook) = 0 useless requests             │
  └──────────────────────────────────────────────────────┘
```

---

## Domains 5, 6, 7

```
  5. TOOLS                6. INFRASTRUCTURE         7. COMMUNICATION
  ┌──────────────────┐   ┌──────────────────┐      ┌──────────────────┐
  │  LO01            │   │  AR04            │      │  US06            │
  │                  │   │                  │      │                  │
  │  Log retention   │   │  Scalable infra  │      │  Good docs =    │
  │  policy: collect │   │  (K8s, auto-     │      │  reuse, not     │
  │  only needed     │   │  scaling) to     │      │  duplication    │
  │  data, define    │   │  avoid over-     │      │                  │
  │  TTL             │   │  provisioning    │      │                  │
  │                  │   │                  │      │                  │
  │                  │   │  AR05            │      │                  │
  │                  │   │  Carbon footprint│      │                  │
  │                  │   │  dashboard       │      │                  │
  └──────────────────┘   └──────────────────┘      └──────────────────┘
```

---

## Complete Rule Catalog — At a Glance

```
  ARCHITECTURE (AR)                    DESIGN (DE)
  ─────────────────                    ───────────
  AR01  Event-Driven Architecture      DE01  Smallest format (JSON>XML)
  AR02  Close to consumer              DE02  Use cache
  AR03  One API per need               DE03  Cache efficiently
  AR04  Scalable infra                 DE04  Opaque token > JWT
  AR05  Carbon dashboard               DE05  Cache aligned to data
                                       DE06  Partial cache refresh
  USAGE (US)                           DE07  Customer-centric design
  ──────────                           DE08  Filtering mechanism
  US01  Query params for GET           DE09  OData/GraphQL
  US02  Decommission unused APIs       DE10  No data duplication
  US03  Max 2 versions                 DE11  Pagination
  US04  Return only necessary
  US05  Right API for use case         LOG (LO)
  US06  Good docs = reuse              ────────
  US07  Monitor error rate             LO01  Log retention policy
```

---

## Scoring Progression: From 0 to 90.4

```
  Score
  100 ┤
      │                                              ┌───── 90.4 A+
   90 ┤                                         ┌────┘
      │                                    ┌────┘  +5 US07
   80 ┤                               ┌────┘  +5 LO01
      │                          ┌────┘  +10 Range/206
   70 ┤                     ┌────┘  +10 DE06
      │                ┌────┘
   60 ┤           ┌────┘  +15 DE02/DE03
      │      ┌────┘
   45 ┤ ┌────┘  +15 DE01 compression
      │ │  +15 DE08 filtering
   30 ┤ │
      │ │  +15 DE11 pagination
   15 ┤─┘
      │
    0 ┤── Baseline (no optimization)
      └───┬───┬───┬───┬───┬───┬───┬───┬───►
          1   2   3   4   5   6   7   8   Steps
```

---

## What's Next?

```
  Article 1  ──►  Article 2  ──►  Article 3  ──►  Article 4  ──►  Article 5
  ┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐
  │ Intro  │     │ 7      │     │ Data   │     │ Usage &│     │ Auto-  │
  │ & Why  │     │ Domains│     │Exchange│     │ Archi  │     │ mation │
  │        │     │📍HERE  │     │ DE*    │     │ US/AR  │     │ CI/CD  │
  └────────┘     └────────┘     └────────┘     └────────┘     └────────┘
```

3. **[Data Exchange: The Biggest Lever](./03-domain-data-exchange.md)**
4. **[Usage & Architecture: Smart Consumption](./04-domain-usage-architecture.md)**
5. **[Automation: CI/CD, Dashboard & Continuous Scoring](./05-automation-ci-cd-dashboard.md)**

---

*Each domain is a tool in your toolkit. Apply them systematically, measure, iterate.*

*Less data, more impact.*
