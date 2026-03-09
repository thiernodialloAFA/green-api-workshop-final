package com.example.optimized.api;

import com.example.optimized.domain.Book;
import com.example.optimized.repo.BookRepository;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.*;
import org.springframework.scheduling.annotation.Async;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.CompletableFuture;

import static com.example.optimized.api.BookReactiveController.getBookResponseEntity;

@RestController
@RequestMapping("/books")
@Validated
public class BookController {
    private final BookRepository repo;
    public BookController(BookRepository repo) { this.repo = repo; }

    // Full list (non-paginé — pour comparaison avec baseline)
    @GetMapping
    public List<Book> all() { return repo.findAll(); }

    // Ressource unitaire sans cache (pour comparaison)
    @GetMapping("noCache/{id}")
    public ResponseEntity<Book> byId(@PathVariable("id") long id) {
        return repo.findById(id)
            .map(ResponseEntity::ok)
            .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND).build());
    }

    // DE11 — Pagination simple (size borné ≤ 100)
    private static final int MAX_PAGE_SIZE = 100;

    @GetMapping(params = {"page","size"})
    public List<Book> page(
        @RequestParam("page") @Min(0) int page,
        @RequestParam("size") @Min(1) @Max(MAX_PAGE_SIZE) int size
    ){
        size = Math.max(1, Math.min(size, MAX_PAGE_SIZE)); // Borne DE11
        var all = repo.findAll();
        int from = Math.max(0, Math.min(page * size, all.size()));
        int to   = Math.max(from, Math.min(from + size, all.size()));
        return all.subList(from, to);
    }

    // Batching — réduire N appels en 1 (AR02)
    @GetMapping("/batch")
    public List<Book> batch(@RequestParam("ids") @Size(min = 1, max = MAX_PAGE_SIZE) List<Long> ids) {
        return ids.stream()
            .limit(MAX_PAGE_SIZE)
            .map(repo::findById)
            .flatMap(Optional::stream)
            .toList();
    }


    // DE08/US01 — Filtrage de champs (whitelist, summary exclu par défaut)
    @GetMapping(value = "/select")
    public List<Map<String, Object>> select(
        @RequestParam(name = "fields", defaultValue = "id,title,author") String fields,
        @RequestParam(name = "page", defaultValue = "0") @Min(0) int page,
        @RequestParam(name = "size", defaultValue = "20") @Min(1) @Max(MAX_PAGE_SIZE) int size
    ){
        var wanted = FieldSelector.parse(fields);
        var slice = page(page, size);
        return slice.stream().map(b -> {
                    var m = new LinkedHashMap<String, Object>();
                    if (wanted.contains("id")) m.put("id", b.getId());
                    if (wanted.contains("title")) m.put("title", b.getTitle());
                    if (wanted.contains("author")) m.put("author", b.getAuthor());
                    if (wanted.contains("published_date")) m.put("published_date", b.getPublished_date());
                    if (wanted.contains("year")) m.put("year", b.getYea());
                    if (wanted.contains("pages")) m.put("pages", b.getPages());
                    if (wanted.contains("summary")) m.put("summary", b.getSummary());
                    return (Map<String, Object>) m;
                }
        ).toList();
    }

    // Ressource unitaire avec ETag + Last-Modified
    @GetMapping("/{id}")
    public ResponseEntity<Book> byId(
        @PathVariable("id") long id,
        @RequestHeader(value = "If-None-Match", required = false) String inm,
        @RequestHeader(value = "If-Modified-Since", required = false) String ims
    ){
        var opt = repo.findById(id);
        if (opt.isEmpty()) return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        var b = opt.get();
        return getBookResponseEntity(inm, ims, b);
    }

    // Résumé avec support Range 206
    @GetMapping("/{id}/summary")
    public ResponseEntity<byte[]> summaryRange(
        @PathVariable("id") long id,
        @RequestHeader(value = "Range", required = false) String range
    ){
        var opt = repo.findById(id);
        if (opt.isEmpty()) return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        var summary = opt.get().getSummary();
        var bytes = summary.getBytes(StandardCharsets.UTF_8);
        int len = bytes.length;
        if (range == null || !range.startsWith("bytes=")) {
            return ResponseEntity.ok()
                .contentType(MediaType.TEXT_PLAIN)
                .contentLength(len)
                .body(bytes);
        }
        String spec = range.substring("bytes=".length());
        String[] parts = spec.split("-");
        int start = parts[0].isEmpty()?0:Integer.parseInt(parts[0]);
        int end = parts.length>1 && !parts[1].isEmpty()?Integer.parseInt(parts[1]):len-1;
        start = Math.max(0, Math.min(start, len-1));
        end   = Math.max(start, Math.min(end, len-1));
        byte[] slice = java.util.Arrays.copyOfRange(bytes, start, end+1);
        return ResponseEntity.status(HttpStatus.PARTIAL_CONTENT)
            .header(HttpHeaders.CONTENT_RANGE, "bytes "+start+"-"+end+"/"+len)
            .contentType(MediaType.TEXT_PLAIN)
            .contentLength(slice.length)
            .body(slice);
    }

    // Delta changes since timestamp
    @GetMapping("/changes")
    public ResponseEntity<List<Book>> changes(
      @RequestParam("since") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant since
    ){
        var list = repo.findChangesSince(since);
        return ResponseEntity.ok()
            .cacheControl(CacheControl.noCache())
            .body(list);
    }

    // Update de démo pour générer des deltas
    @PostMapping("/{id}/summary")
    public ResponseEntity<Book> updateSummary(@PathVariable("id") long id, @RequestBody Map<String, String> body){
        var updated = repo.updateSummary(id, body.getOrDefault("summary", ""));
        if (updated == null) return ResponseEntity.notFound().build();
        return ResponseEntity.ok(updated);
    }

    // Endpoint CBOR : retourne la liste des livres au format CBOR si demandé
    @GetMapping(value = "/cbor", produces = "application/cbor")
    public ResponseEntity<List<Book>> getBooksCbor() {
        var all = repo.findAll();
        return ResponseEntity.ok().body(all);
    }

    // Endpoint asynchrone : liste des livres
    @Async
    @GetMapping("/async")
    public CompletableFuture<List<Book>> getBooksAsync() {
        return CompletableFuture.supplyAsync(() -> repo.findAll());
    }

    // Endpoint asynchrone : livre par ID
    @Async
    @GetMapping("/async/{id}")
    public CompletableFuture<ResponseEntity<Book>> getBookByIdAsync(@PathVariable("id") long id) {
        return CompletableFuture.supplyAsync(() -> {
            var opt = repo.findById(id);
            return opt.map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.notFound().build());
        });
    }

    @PutMapping("/{id}")
    public ResponseEntity<Book> updateBook(
            @PathVariable("id") long id,
            @RequestBody Book updatedBook
    ) {
        Book book = repo.updateBook(id, updatedBook);
        if (book == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(book);
    }
}
