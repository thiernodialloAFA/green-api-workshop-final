# Usage & Architecture: Building APIs That Consume Responsibly

*Part 4 of our [API Green Score series](./01-introduction-api-green-score.md). After [Data Exchange](./03-domain-data-exchange.md), we cover the remaining domains.*

---

## Overview: What This Article Covers

```
  ┌───────────────────────────────────────────────────────────────────┐
  │                                                                   │
  │  API LIFECYCLE        USAGE           ARCHITECTURE    OBSERV.     │
  │  ┌─────────────┐    ┌─────────────┐  ┌────────────┐  ┌────────┐ │
  │  │ US02 US03   │    │ US01 US06   │  │ AR01 AR02  │  │ LO01   │ │
  │  │ AR03        │    │ US07        │  │ AR04 AR05  │  │        │ │
  │  │             │    │             │  │            │  │        │ │
  │  │ Decommission│    │ Rate limit  │  │ EDA, CBOR  │  │ Payload│ │
  │  │ Deduplicate │    │ Query params│  │ Scalability│  │ logging│ │
  │  │ Max versions│    │ Good docs   │  │ Carbon dash│  │        │ │
  │  └─────────────┘    └─────────────┘  └────────────┘  └────────┘ │
  │                                                                   │
  └───────────────────────────────────────────────────────────────────┘
```

---

## API Lifecycle: The Forgotten Domain

```
  ┌──────────────────────────────────────────────────────────────────┐
  │                                                                  │
  │  US02: Unused API still running 24/7?                           │
  │  ┌─────────┐                                                    │
  │  │ API v1  │──── 0 calls/day ──── still consuming CPU/RAM ──🔴 │
  │  └─────────┘                      DECOMMISSION IT!              │
  │                                                                  │
  │  US03: Too many versions?                                       │
  │  ┌────┐ ┌────┐ ┌────┐                                          │
  │  │ v1 │ │ v2 │ │ v3 │  = 3x infra, 3x maintenance ──🔴        │
  │  └────┘ └────┘ └────┘                                           │
  │  ┌────┐ ┌────┐                                                  │
  │  │ v2 │ │ v3 │        = max 2 versions ──🟢                    │
  │  └────┘ └────┘                                                  │
  │                                                                  │
  │  AR03: Duplicate APIs?                                          │
  │  ┌──────────┐  ┌──────────┐                                     │
  │  │ /users   │  │ /people  │  = same data, 2x resources ──🔴    │
  │  └──────────┘  └──────────┘                                     │
  │  ┌──────────┐                                                   │
  │  │ /users   │              = one API per need ──🟢              │
  │  └──────────┘                                                   │
  └──────────────────────────────────────────────────────────────────┘
```

---

## US07 — Rate Limiting (+5 pts)

> *"Decrease the error rate to avoid over-processing."*

```
  Without rate limiting:                With rate limiting:
  ┌──────────────────────┐             ┌──────────────────────┐
  │  Client A: 500k req  │             │  Client A: 100 req   │
  │  Client B: 50k req   │             │  Client A: 429 ──────│──► 0 cost
  │  Client C: 50k req   │             │  Client B: 50k req   │
  │                      │             │  Client C: 50k req   │
  │  Total: 600k         │             │  Total: 200k         │
  │  ──────────────      │             │  ──────────────      │
  │  500k wasted! 🔴     │             │  0 wasted! 🟢        │
  └──────────────────────┘             └──────────────────────┘
```

```java
@Component
public class RateLimitFilter extends OncePerRequestFilter {
    // 100 requests/minute per client IP
    // Excess -> 429 Too Many Requests (no DB, no serialization, ~0 cost)
}
```

---

## US01 — Query Parameters for GET

```
  ┌──────────────────────────────────────────────────────────────┐
  │                                                              │
  │  GET /books?page=0&size=20&fields=id,title                  │
  │  ┌──────────────────────────────────────┐                   │
  │  │  ✅ Cacheable by CDN                 │                   │
  │  │  ✅ Cacheable by browser             │                   │
  │  │  ✅ Cacheable by proxy               │                   │
  │  │  ✅ Visible in access logs           │                   │
  │  │  ✅ Safe to retry (idempotent)       │                   │
  │  └──────────────────────────────────────┘                   │
  │                                                              │
  │  POST /books/search { "page": 0, "size": 20 }              │
  │  ┌──────────────────────────────────────┐                   │
  │  │  ❌ Never cached                     │                   │
  │  │  ❌ Opaque to proxies                │                   │
  │  │  ❌ Not idempotent by default        │                   │
  │  └──────────────────────────────────────┘                   │
  └──────────────────────────────────────────────────────────────┘
```

---

## AR01 — Event-Driven Architecture

> *"Applications make very frequent requests to APIs. The best practice is EDA — receive a notification when information is modified."*

```
  POLLING (anti-pattern)              EDA / SSE (green pattern)
  ┌──────────────────────┐           ┌──────────────────────┐
  │  Client ──► API      │           │  Client ◄── API      │
  │  every 5 seconds     │           │  push on change only │
  │                      │           │                      │
  │  17,280 req/day      │           │  ~10 req/day         │
  │  99.9% empty! 🔴     │           │  100% useful 🟢      │
  └──────────────────────┘           └──────────────────────┘
```

```java
@GetMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
public Flux<Book> stream() {
    return bookEventSink.asFlux();
}
```

---

## AR02 — Binary Formats (CBOR)

> *"Deploy APIs as close as possible to consumers."*

We also reduce bytes regardless of distance with binary formats:

```
  Same data, different formats (1M books):
  ┌──────────────────────────────────────────────────────┐
  │  JSON  ████████████████████████████████████  203 MB  │
  │  CBOR  ██████████████████████████████       153 MB   │
  │                                                      │
  │  CBOR saves 24.3% — on every single call             │
  └──────────────────────────────────────────────────────┘
```

---

## AR04/AR05 — Scalable Infra & Carbon Dashboard

```
  Over-provisioned (always-on):       Auto-scaled (demand-based):
  ┌──────────────────────┐           ┌──────────────────────┐
  │  ████████████████    │           │  █                   │  low
  │  ████████████████    │           │  ████                │  medium
  │  ████████████████    │           │  ████████████████    │  peak
  │  ████████████████    │           │  ██                  │  low
  │                      │           │                      │
  │  24/7 max power 🔴   │           │  Scales to demand 🟢 │
  └──────────────────────┘           └──────────────────────┘

  AR05: Measure it! Carbon footprint dashboard
  (This inspired our Green Score dashboard)
```

---

## LO01 — Observability (+5 pts)

> *"Collect only required data, define retention period."*

```
  PayloadLoggingFilter output:
  ┌──────────────────────────────────────────────────────────────────┐
  │  [GREEN] GET /books?page=0&size=20  ► 200 | 3,805 B  | 356ms  │
  │  [GREEN] GET /books/1               ► 304 |     0 B  |   4ms  │
  │  [GREEN] GET /books/select?fields=  ► 200 |   974 B  |  61ms  │
  │  [GREEN] GET /books                 ► 200 | 138 MB   | 1243ms │ 🚨
  └──────────────────────────────────────────────────────────────────┘
           │
           ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  ENERGY CALCULATION                                             │
  │                                                                 │
  │  Network Energy = Payload(GB) x 0.06 kWh/GB x 1000             │
  │  Server Energy  = ResponseTime(s) x ServerPower(W) / 3600      │
  │  CO2            = TotalEnergy(kWh) x CarbonIntensity(gCO2/kWh) │
  └──────────────────────────────────────────────────────────────────┘
```

---

## Complete Score Map

```
  ┌───────────────────────────────────────────────────────────────┐
  │  DOMAIN          RULE              PTS   IMPLEMENTATION      │
  ├───────────────────────────────────────────────────────────────┤
  │  Data Exchange   DE11 Pagination    15   BookController       │
  │  Data Exchange   DE08 Filtering     15   BookController       │
  │  Data Exchange   DE01 Compression   15   application.yml      │
  │  Data Exchange   DE02/03 Cache      15   WebConfig            │
  │  Data            DE06 Delta         10   BookController       │
  │  Data Exchange   Range 206          10   BookController       │
  │  Architecture    AR02 CBOR          10   BookController       │
  │  API Lifecycle   US07 Rate limit     5   RateLimitFilter      │
  │  Tools           LO01 Logging        5   PayloadLoggingFilter │
  ├───────────────────────────────────────────────────────────────┤
  │                  TOTAL             100                        │
  └───────────────────────────────────────────────────────────────┘
```

---

## What's Next?

```
  Article 1  ──►  Article 2  ──►  Article 3  ──►  Article 4  ──►  Article 5
  ┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐
  │ Intro  │     │ 7      │     │ Data   │     │ Usage &│     │ Auto-  │
  │ & Why  │     │ Domains│     │Exchange│     │ Archi  │     │ mation │
  │        │     │        │     │        │     │📍HERE  │     │ CI/CD  │
  └────────┘     └────────┘     └────────┘     └────────┘     └────────┘
```

5. **[Automation: CI/CD, Dashboard & Continuous Scoring](./05-automation-ci-cd-dashboard.md)**

*These domains make green practices sustainable over time. Less data, more impact.*
