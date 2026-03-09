# 🚀 Exercices avancés & scénarios complexes

> Pour aller plus loin après l'atelier. Chaque exercice inclut une solution succincte.

## 1. Batching — réduire les appels réseau

**Problème** : le client fait N appels `GET /books/1`, `GET /books/2`, etc.

**Solution** : `GET /books/batch?ids=1,2,3` → un seul appel, un seul payload.

```java
@GetMapping("/batch")
public List<Book> batch(@RequestParam("ids") List<Long> ids) {
    return ids.stream().map(repo::findById).flatMap(Optional::stream).toList();
}
```

## 2. TTL adaptatif — `Cache-Control` conditionnel

**Problème** : même TTL pour données stables et volatiles.

**Solution** : `max-age` élevé si la donnée est stable, court si volatile.

```java
var maxAge = book.isStable() ? Duration.ofHours(24) : Duration.ofMinutes(5);
return ResponseEntity.ok()
    .cacheControl(CacheControl.maxAge(maxAge).cachePublic())
    .body(book);
```

## 3. Delta par version — éviter les timestamps

**Problème** : `since=` dépend des horloges (fuseaux, drift).

**Solution** : `GET /books/changes?sinceVersion=1234` → version monotonique.

```java
@GetMapping("/changes")
public List<Book> changesByVersion(@RequestParam("sinceVersion") long sinceVersion) {
    return repo.findAll().stream()
        .filter(b -> b.getVersion() > sinceVersion)
        .sorted(Comparator.comparing(Book::getVersion))
        .toList();
}
```

## 4. Idempotency-Key — éviter les doublons POST

**Problème** : retry d'un POST → création en double.

**Solution** : header `Idempotency-Key` + cache côté serveur.

```java
@PostMapping
public ResponseEntity<Book> create(
    @RequestHeader("Idempotency-Key") String key,
    @RequestBody Book book) {
    return idempotencyCache.computeIfAbsent(key, k -> {
        var saved = repo.save(book);
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    });
}
```

## 5. SSE / Webhook — réduire le polling

**Problème** : le client poll toutes les 5 secondes `GET /books/changes`.

**Solution** : Server-Sent Events (SSE) → le serveur push quand il y a du nouveau.

```java
@GetMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
public Flux<Book> stream() {
    return bookEventSink.asFlux();
}
```

## 6. Keyset pagination — éviter OFFSET profonds

**Problème** : `OFFSET 100000` est coûteux en base.

**Solution** : `GET /books?afterId=1000&size=20` → seek par clé.

```java
@GetMapping(params = {"afterId", "size"})
public List<Book> keyset(@RequestParam("afterId") long afterId, @RequestParam("size") int size) {
    return repo.findAll().stream()
        .filter(b -> b.getId() > afterId)
        .sorted(Comparator.comparing(Book::getId))
        .limit(Math.min(size, 100))
        .toList();
}
```

## 7. Ranges multiples — téléchargement partiel avancé

**Problème** : on veut les bytes 0-99 ET 200-299 d'une ressource.

**Solution** : `Range: bytes=0-99,200-299` → multipart response.

## 8. Brotli compression — meilleur que Gzip

**Problème** : Gzip est bon, mais Brotli compresse ~20% mieux.

**Solution** : activer Brotli dans le serveur embarqué (nécessite Jetty ou un reverse proxy).

## 9. GraphQL — filtrage ultime

**Problème** : même avec `fields=`, on ne contrôle pas les sous-objets.

**Solution** : GraphQL permet au client de demander exactement ce dont il a besoin.

> ⚠️ Attention au coût de parsing des requêtes GraphQL — à utiliser judicieusement.

## 10. Automatisation du Green Score en CI

**Déjà implémenté** dans ce repo :
- `scripts/green-score-analyzer.sh` — mesure + calcul
- `dashboard/index.html` — visualisation + historique
- `.github/workflows/pr-green-api.yml` — CI avec assertions + commentaire PR
- `.spectral.yml` — lint OpenAPI éco-conception
