# Advanced Exercises & Complex Scenarios (with brief solutions)

1) **Batching** `GET /books/batch?ids=1,2,3` → avoid N separate calls.
2) **Adaptive TTL**: conditional `Cache-Control` (e.g., high `max-age` for stable data).
3) **Delta by version**: `GET /books/changes?sinceVersion=1234`.
4) **Idempotency‑Key** for POST → prevent duplicates.
5) **SSE/Webhook** to reduce polling.
6) **Keyset pagination** (`afterId`) → avoid deep OFFSETs.
7) **Multiple ranges** `bytes=0-99,200-299` (bonus).
