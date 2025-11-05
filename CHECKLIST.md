# Green API Review Checklist (API Green Score)

Please indicate **before/after measurements** (payload/latency).

## Data Exchange
- [ ] **DE11 – Pagination** (bounded size ≤100, validated)
- [ ] **DE08 – Filtering** via `fields=` (whitelist, expensive fields off by default)
- [ ] **DE01/USXX – Format & compression** (JSON/CBOR, Gzip enabled & tested)
- [ ] **DE02/DE03 – HTTP Cache** (`Cache-Control` + **ETag**/`Last-Modified` → **304** in test)
- [ ] **DE06/US04 – Delta** (`/changes?since=…` or `sinceVersion`)
- [ ] **206 Partial Content** (`Range: bytes=` for large resources)

## Usage / Architecture / Logs
- [ ] **US01 – Query params** for GET (page/size/fields)
- [ ] **US07 – Error monitoring** (Actuator/metrics)
- [ ] **AR02 – Efficiency** (batch, aggregation, keyset pagination)
- [ ] **LO01 – Useful logs** (bytes, timeMs, 304) & documented retention
- [ ] **Rate limiting** to avoid unnecessary bursts

## Security & Robustness
- [ ] Input validation (bounds for `size`, whitelist for `fields`)
- [ ] Idempotency‑Key for critical POSTs

## Measurements
```
curl -s -w 'size=%{size_download} time=%{time_total}\n' -o /dev/null <URL>
```
- Before: …
- After: …
- Gain: … %
