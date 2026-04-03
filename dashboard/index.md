# 🌿 Green API Score Dashboard

> **Devoxx France 2026 — Green Architecture : moins de gras, plus d'impact !**

📅 *Dernière analyse : 2026-04-03T12:53:00Z*

---

## 🟢 Green Score : **90.4/100** — Grade **A+** 🏆

### 📋 Détail par règle

| Statut | Règle | Score | Max | Détail |
|:------:|-------|------:|----:|--------|
| ✅ | DE11 Pagination | 15 | 15 | -100.0% |
| ✅ | DE08 Filtrage champs | 15 | 15 | -74.4% |
| ⚠️ | DE01 Compression | 8 | 15 | gzip active |
| ✅ | DE02/03 Cache ETag | 15 | 15 | perfect 304 |
| ✅ | DE06 Delta | 10 | 10 | -100.0% |
| ✅ | 206 Range | 10 | 10 | partial content supported |
| ✅ | LO01 Observabilité | 5 | 5 | PayloadLoggingFilter detected |
| ✅ | US07 Rate Limit | 5 | 5 | RateLimitFilter detected |
| ⚠️ | AR02 CBOR | 7.4 | 10 | -24.3% |

### 📊 Comparaison Avant / Après

| Mesure | Taille | Temps | HTTP |
|--------|-------:|------:|-----:|
| 🔴 Baseline `/books` (full) | 138.3 MB | 1.373s | 200 |
| 🟢 Pagination (`?page&size`) | 3.8 KB | 0.388s | 200 |
| 🟢 Fields filter (`fields=`) | 974 B | 0.293s | 200 |
| 🟢 Gzip compression | 2.5 KB | 0.260s | 200 |
| 🟢 ETag / 304 | 0 B | 0.235s | 304 |
| 🟢 Delta changes | 178 B | 0.268s | 200 |
| 🟢 Range 206 | 17 B | 0.218s | 206 |
| 🟢 CBOR binary | 153.8 MB | 1.777s | 200 |
| 🟢 Full payload (optimized) | 203.2 MB | 1.896s | 200 |

### 🔑 Métriques clés

- **Réduction payload** : 138.3 MB → 3.8 KB (**-100.0%**)
- **Cache ETag** : ✅ 304 (zéro transfert)
- **Compression gzip** : 3.8 KB → 2.5 KB (**-35.4%**)

### 🔍 Auto-Discovery (20 endpoints)

Swagger : `http://localhost:8081/v3/api-docs`

---

🌿 *API Green Score — [Framework](https://github.com/API-Green-Score/APIGreenScore) | [Training](https://github.com/API-Green-Score/training-student) | Devoxx France 2026*

> 📊 Pour le dashboard interactif complet, ouvrez [`dashboard/index.html`](index.html)
