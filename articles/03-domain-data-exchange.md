# Data Exchange: The Biggest Lever for Greener APIs

*Part 3 of our [API Green Score series](./01-introduction-api-green-score.md). Data Exchange = ~70% of the score — and ~99% of the real impact.*

---

## The Problem

```
  GET /books (no optimization)
  ┌──────────────────────────────────────────────────────────────┐
  │ ████████████████████████████████████████████████████████████ │
  │                    138,327,793 bytes (138 MB)                │
  │                    Time: 1.24s                               │
  └──────────────────────────────────────────────────────────────┘
```

---

## DE11 — Pagination (+15 pts)

> *"Implement pagination to limit which data are returned — send just what the consumer needs."*

```java
@GetMapping
public Page<Book> page(@RequestParam(defaultValue = "0") int page,
                       @RequestParam(defaultValue = "20") int size) {
    size = Math.min(size, 100); // Hard cap
    return repository.findAll(PageRequest.of(page, size));
}
```

```
  BEFORE                              AFTER
  ██████████████████████████████████  █
  138,327,793 B (138 MB)             3,805 B (3.8 KB)

  Reduction: 99.997%
```

---

## DE08 — Field Filtering (+15 pts)

> *"Implement filtering mechanism to limit payload size."*

```java
@GetMapping("/select")
public Page<Map<String, Object>> select(
    @RequestParam(defaultValue = "id,title,author") String fields, ...) {
    Set<String> allowed = Set.of("id", "title", "author", "year", "isbn");
    // ... filter and return only requested fields
}
```

```
  Paginated                Paginated + Filtered
  ████                     █
  3,805 B                  974 B

  Reduction: 74.4% further
```

---

## DE01 — Smallest Format & Compression (+15 pts)

> *"JSON is smaller than XML. The heavier format has a stronger impact on network, compute and storage."*

```
  Same data, different formats:
  ┌──────────────────────────────────────────┐
  │  JSON  ████████████████████  40 KB       │
  │  XML   ████████████████████████████ 58 KB│
  │                                          │
  │  XML is 43% heavier!                     │
  │  On 1M calls/day = 18 GB wasted daily    │
  └──────────────────────────────────────────┘
```

Enable Gzip compression in 2 lines:

```yaml
server:
  compression:
    enabled: true
    min-response-size: 1024
```

```
  Filtered                 Filtered + Gzip
  ██                       █
  974 B                    ~480 B

  Reduction: ~50% further
```

---

## DE02/DE03 — HTTP Cache / ETag (+15 pts)

> *"Cache saves computational resources by avoiding executing the same query on the same data multiple times."*

```
  1st call                          2nd call (with ETag)
  ┌──────────────────────┐         ┌──────────────────────┐
  │  GET /books/1        │         │  GET /books/1        │
  │                      │         │  If-None-Match: "abc"│
  │  ◄── 200 OK         │         │  ◄── 304 Not Modified│
  │      187 bytes       │         │      0 bytes         │
  │      22ms            │         │      4ms             │
  └──────────────────────┘         └──────────────────────┘

  2nd call: 0 bytes transferred, 82% faster
```

```java
@Bean
public FilterRegistrationBean<ShallowEtagHeaderFilter> etagFilter() {
    var reg = new FilterRegistrationBean<>(new ShallowEtagHeaderFilter());
    reg.addUrlPatterns("/books/*");
    return reg;
}
```

---

## DE06 — Delta Endpoint (+10 pts)

> *"Allow partial cache refresh aligned to data lifecycle."*

```
  Full collection vs Delta:
  ┌──────────────────────────────────────────┐
  │  GET /books           ████████ 203 MB    │
  │  GET /changes?since=  .        178 B     │
  │                                          │
  │  Reduction: ~100%                        │
  └──────────────────────────────────────────┘
```

```java
@GetMapping("/changes")
public List<Book> changes(@RequestParam("since") Instant since) {
    return repository.findByUpdatedAtAfter(since);
}
```

---

## DE04 — Opaque Tokens over JWT

```
  Every API call includes an auth token:
  ┌──────────────────────────────────────────┐
  │  JWT token:     ████████████  ~800 bytes │
  │  Opaque token:  █              ~40 bytes │
  │                                          │
  │  x 1M calls/day = 760 MB saved daily    │
  └──────────────────────────────────────────┘
```

---

## Range / 206 Partial Content (+10 pts)

```
  Full resource vs Partial:
  ┌──────────────────────────────────────────┐
  │  GET /books/1/summary          full body │
  │  GET /books/1/summary           ██ 200 B │
  │    + Range: bytes=0-199                  │
  │    ◄── 206 Partial Content               │
  └──────────────────────────────────────────┘
```

---

## The Compound Effect — Stacking All Optimizations

```
  ┌────────────────────────────────────────────────────────────┐
  │                                                            │
  │  Baseline      ████████████████████████████  138,327,793 B │
  │  + Pagination  █                                 3,805 B  │
  │  + Filtering   .                                   974 B  │
  │  + Gzip        .                                  ~480 B  │
  │  + ETag (2nd)                                        0 B  │
  │                                                            │
  │  Total reduction: 99.9999%                                 │
  └────────────────────────────────────────────────────────────┘
```

### Energy Impact

```
  ┌──────────────────────────────────────────────────────────┐
  │                                                          │
  │  Baseline:   138 MB/call × 50k calls = 6.9 TB/day       │
  │              Energy: 414 Wh/day                          │
  │                                                          │
  │  Optimized:  974 B/call × 50k calls = 48.7 MB/day       │
  │              Energy: 0.003 Wh/day                        │
  │                                                          │
  │  ──────────────────────────────────────────              │
  │  138,000x less energy for the same business value        │
  └──────────────────────────────────────────────────────────┘
```

---

## What's Next?

```
  Article 1  ──►  Article 2  ──►  Article 3  ──►  Article 4  ──►  Article 5
  ┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐
  │ Intro  │     │ 7      │     │ Data   │     │ Usage &│     │ Auto-  │
  │ & Why  │     │ Domains│     │Exchange│     │ Archi  │     │ mation │
  │        │     │        │     │📍HERE  │     │ US/AR  │     │ CI/CD  │
  └────────┘     └────────┘     └────────┘     └────────┘     └────────┘
```

4. **[Usage & Architecture: Smart Consumption](./04-domain-usage-architecture.md)**
5. **[Automation: CI/CD, Dashboard & Continuous Scoring](./05-automation-ci-cd-dashboard.md)**

*Data Exchange is the 80/20 of green APIs: 70% of the score, 99% of the real impact. Start here.*
