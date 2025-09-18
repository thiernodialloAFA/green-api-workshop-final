# Mapping des pratiques -> Règles API Green Score
- **Pagination** → `DE11`
- **Filtrage de champs** (`fields=`) → `DE08`
- **Query params** (GET) → `US01`
- **Compression** (Gzip) → `DE01` / `USXX`
- **Cache HTTP (ETag/Cache-Control)** → `DE02` / `DE03`
- **Delta (changes since)** → `DE06` / `US04`
- **206 Partial Content (Range)** → Data Exchange (réduction volume)
- **Observabilité & erreurs** → `LO01` / `US07`
- **Proximité/efficacité** (batch, keyset) → `AR02`
