# ✅ Green API Review Checklist (API Green Score)

> Utilisez cette checklist lors de chaque review de code.
> Le CI calcule automatiquement le **Green Score /100** et le poste sur la PR.

Merci d'indiquer les **mesures avant/après** (payload/latence).

## Data Exchange (80 pts)

- [ ] **DE11 – Pagination** (15 pts)
  - `size` borné ≤ 100, paramètres `page` et `size` validés
  - Testé : `GET /books?page=0&size=20`
- [ ] **DE08 – Filtrage de champs** (15 pts)
  - `fields=` whitelist, champs coûteux (`summary`) exclus par défaut
  - Testé : `GET /books/select?fields=id,title,author&page=0&size=20`
- [ ] **DE01 – Compression** (15 pts)
  - Gzip activé (`server.compression.enabled=true`), min-response-size configuré
  - Testé avec `Accept-Encoding: gzip`
- [ ] **DE02/DE03 – Cache HTTP** (15 pts)
  - `Cache-Control` + `ETag` + `Last-Modified` → **304** en test
  - `ShallowEtagHeaderFilter` configuré
  - Testé : 2 requêtes consécutives, 2ème → 304
- [ ] **DE06/US04 – Delta** (10 pts)
  - `/changes?since=…` endpoint fonctionnel
  - Testé : delta vide quand pas de changement récent
- [ ] **206 Partial Content** (10 pts)
  - `Range: bytes=` supporté pour ressources volumineuses
  - Testé : `GET /books/1/summary` avec `Range: bytes=0-199` → 206

## Usage / Archi / Logs (20 pts)

- [ ] **LO01 – Observabilité** (5 pts)
  - `PayloadLoggingFilter` actif (logs: method, path, status, bytes, timeMs)
  - Rétention documentée
- [ ] **US07 – Rate Limiting** (5 pts)
  - `RateLimitFilter` actif (429 quand limite atteinte)
- [ ] **AR02 – Format binaire** (10 pts)
  - CBOR supporté (`/books/cbor` avec `Accept: application/cbor`)
- [ ] **US01 – Query params** pour GET (page/size/fields)
- [ ] **US07 – Monitoring erreurs** (Actuator/metrics exposés)

## Sécurité & robustesse

- [ ] Validation inputs (bornes `size`, whitelist `fields`)
- [ ] Idempotency-Key sur POST critiques

## Mesures avant/après

```bash
# Commande de mesure :
curl -s -w 'size=%{size_download} time=%{time_total}\n' -o /dev/null <URL>
```

| Métrique | Avant | Après | Gain % |
|----------|-------|-------|--------|
| Payload full | _____ bytes | _____ bytes | _____ % |
| Payload paginé+filtré | — | _____ bytes | — |
| Payload gzip | — | _____ bytes | _____ % |
| ETag 2nd call | 200 | 304 | 100% |

## 🌿 Green Score (automatique)

> Le CI génère un rapport JSON dans `reports/` et poste le score sur la PR.
> Dashboard : `dashboard/index.html`
