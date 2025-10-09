package com.example.optimized.api;

import com.example.optimized.domain.Book;
import com.example.optimized.repo.BookRepository;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.*;
import org.springframework.scheduling.annotation.Async;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.CompletableFuture;

import static com.example.optimized.api.BookReactiveController.getBookResponseEntity;

@RestController
@RequestMapping("/books")
public class BookController {
    private final BookRepository repo;
    public BookController(BookRepository repo) { this.repo = repo; }

    @GetMapping
    public List<Book> all() { return repo.findAll(); }





    @GetMapping("noCache/{id}")
    public Book byId(@PathVariable("id") long id) { return repo.findById(id).get(); }











    // Pagination simple
    @GetMapping(params = {"page","size"})
    public List<Book> page(@RequestParam("page") int page, @RequestParam("size") int size){
        var all = repo.findAll();
        int from = Math.max(0, Math.min(page * size, all.size()));
        int to   = Math.max(from, Math.min(from + size, all.size()));
        return all.subList(from, to);
    }





    // Filtrage de champs
    @GetMapping(value = "/select")
    public List<Object> select(
        @RequestParam(name = "fields", defaultValue = "id,title,author") String fields,
        @RequestParam(name = "page",defaultValue = "0") int page,
        @RequestParam(name = "size", defaultValue = "20") int size
    ){
        var wanted = new LinkedHashSet<>(Arrays.asList(fields.split(",")));
        var slice = page(page, size);
        return Collections.singletonList(slice.stream().map(b -> {
                    var m = new LinkedHashMap<String, Object>();
                    if (wanted.contains("id")) m.put("id", b.getId());
                    if (wanted.contains("title")) m.put("title", b.getTitle());
                    if (wanted.contains("author")) m.put("author", b.getAuthor());
                    if (wanted.contains("yea")) m.put("year", b.getYea());
                    if (wanted.contains("pages")) m.put("pages", b.getPages());
                    if (wanted.contains("summary")) m.put("summary", b.getSummary());
                    return m;
                }
        ).toList());
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
}
