# Exercices avancés & scénarios complexes (avec solutions succinctes)

1) **Batching** `GET /books/batch?ids=1,2,3` → éviter N appels.
2) **TTL adaptatif** : `Cache-Control` conditionnel (ex: `max-age` élevé si données stables).
3) **Delta par version** : `GET /books/changes?sinceVersion=1234`.
4) **Idempotency‑Key** pour POST → éviter doublons.
5) **SSE/Webhook** pour réduire le polling.
6) **Keyset pagination** (`afterId`) → éviter OFFSET profonds.
7) **Ranges multiples** `bytes=0-99,200-299` (bonus).
