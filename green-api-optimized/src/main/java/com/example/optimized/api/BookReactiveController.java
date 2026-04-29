package com.example.optimized.api;

import com.example.optimized.domain.Book;
import com.example.optimized.service.BookService;
import com.example.optimized.repo.BookReactiveRepository;
import com.example.optimized.service.BookServiceReactif;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import lombok.extern.slf4j.Slf4j;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.*;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import org.springframework.r2dbc.core.DatabaseClient;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

@RestController
@RequestMapping("/reactive/books")
@Slf4j
@Validated
public class BookReactiveController {
    private final BookServiceReactif bookService;
    private final BookReactiveRepository repo;

    public BookReactiveController(BookServiceReactif bookService, BookReactiveRepository repo) {
        this.bookService = bookService;
        this.repo = repo;
    }

    // Endpoint réactif : liste des livres (sans cache)
    @GetMapping
    public Flux<Book> allBooksWithoutCache() {
        log.info("Fetching all books without cache");
        return repo.findAll();
    }

    // Endpoint réactif : liste des livres (cache)
    @GetMapping("/cacheable")
    public Mono<List<Book>> allBooks() {
        log.info("Fetching all books with cache");
        return Mono.justOrEmpty(bookService.findAllCachedList());
    }



    // Pagination simple (réactif)
    @GetMapping(params = {"page","size"})
    public Flux<Book> page(
        @RequestParam("page") @Min(0) @Parameter(description = "Zero-based page index", example = "0") int page,
        @RequestParam("size") @Min(1) @Max(100) @Parameter(description = "Page size (max 100)", example = "20") int size
    ){
        return repo.findAll()
            .skip((long) page * size)
            .take(size);
    }

    // Filtrage de champs (réactif)
    @GetMapping(value = "/select")
    public Flux<Object> select(
        @RequestParam(name = "fields", defaultValue = "id,title,author") @Parameter(description = "Whitelisted comma-separated fields (id,title,author,published_date,pages,summary)", example = "id,title,author") String fields,
        @RequestParam(name = "page",defaultValue = "0") @Min(0) @Parameter(description = "Zero-based page index", example = "0") int page,
        @RequestParam(name = "size", defaultValue = "20") @Min(1) @Max(100) @Parameter(description = "Page size (max 100)", example = "20") int size
    ){
        var wanted = FieldSelector.parse(fields);
        return repo.findAll()
            .skip((long) page * size)
            .take(size)
            .map(b -> {
                var m = new LinkedHashMap<String, Object>();
                if (wanted.contains("id")) m.put("id", b.getId());
                if (wanted.contains("title")) m.put("title", b.getTitle());
                if (wanted.contains("author")) m.put("author", b.getAuthor());
                if (wanted.contains("published_date")) m.put("published_date", b.getPublished_date());
                if (wanted.contains("pages")) m.put("pages", b.getPages());
                if (wanted.contains("summary")) m.put("summary", b.getSummary());
                return m;
            });
    }

    // Ressource unitaire avec ETag + Last-Modified (réactif)
    @GetMapping("/{id}")
    public Mono<ResponseEntity<Book>> byId(
        @PathVariable("id") @Parameter(description = "Book identifier", example = "1") long id,
        @RequestHeader(value = "If-None-Match", required = false) @Parameter(description = "Conditional GET ETag", example = "\"1\"") String inm,
        @RequestHeader(value = "If-Modified-Since", required = false) @Parameter(description = "Conditional GET timestamp (RFC 1123)", example = "Wed, 01 Jan 2025 12:00:00 GMT") String ims
    ){
        return repo.findById(id).map(b -> {
            return getBookResponseEntity(inm, ims, b);
        });
    }

    static ResponseEntity<Book> getBookResponseEntity(@RequestHeader(value = "If-None-Match", required = false) String inm, @RequestHeader(value = "If-Modified-Since", required = false) String ims, Book b) {
        var etag = '"' + Long.toHexString(b.getVersion()) + '"';
        var lastModMillis = b.getLastModified().toEpochMilli();
        if (inm != null && inm.equals(etag)) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED)
                .eTag(etag)
                .lastModified(lastModMillis)
                .build();
        }
        if (ims != null) {
            try {
                long imsMillis = ZonedDateTime.parse(ims, DateTimeFormatter.RFC_1123_DATE_TIME).toInstant().toEpochMilli();
                if (lastModMillis/1000*1000 <= imsMillis) {
                    return ResponseEntity.status(HttpStatus.NOT_MODIFIED)
                        .eTag(etag)
                        .lastModified(lastModMillis)
                        .build();
                }
            } catch (IllegalArgumentException ignored) {}
        }
        return ResponseEntity.ok()
            .cacheControl(CacheControl.maxAge(java.time.Duration.ofMinutes(5)).cachePublic())
            .eTag(etag)
            .lastModified(lastModMillis)
            .body(b);
    }

    // Résumé avec support Range 206 (réactif)
    @GetMapping("/{id}/summary")
    public Mono<ResponseEntity<byte[]>> summaryRange(
        @PathVariable("id") @Parameter(description = "Book identifier", example = "1") long id,
        @RequestHeader(value = "Range", required = false) @Parameter(description = "Byte range, e.g. bytes=0-9", example = "bytes=0-9") String range
    ){
        return repo.findById(id).map(b -> {
            var summary = b.getSummary();
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
        }).defaultIfEmpty(ResponseEntity.status(HttpStatus.NOT_FOUND).build());
    }

    // Delta changes since timestamp (réactif)
    @GetMapping("/changes")
    public Flux<Book> changes(
      @RequestParam("since") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) @Parameter(description = "ISO-8601 timestamp; only books modified after this instant are returned", example = "2025-01-01T00:00:00Z") Instant since
    ){
        return repo.findAll().filter(b -> b.getLastModified().isAfter(since));
    }

    // Update de démo pour générer des deltas (réactif)
    @PostMapping("/{id}/summary")
    public Mono<ResponseEntity<Book>> updateSummary(
            @PathVariable("id") @Parameter(description = "Book identifier", example = "1") long id,
            @io.swagger.v3.oas.annotations.parameters.RequestBody(
                description = "Object containing the new summary text",
                required = true,
                content = @Content(
                    mediaType = "application/json",
                    examples = @ExampleObject(name = "summaryUpdate", value = "{\n  \"summary\": \"Updated summary text for the book.\"\n}")
                )
            )
            @RequestBody Map<String, String> body){
        return repo.findById(id).flatMap(old -> {
            var updated = new Book(
                old.getId(),
                old.getTitle(),
                old.getAuthor(),
                old.getPublished_date(),
                old.getPages(),
                body.getOrDefault("summary", ""),
                Instant.now(),
                old.getVersion() + 1
            );
            return repo.save(updated).map(b -> ResponseEntity.ok(b));
        }).defaultIfEmpty(ResponseEntity.notFound().build());
    }

    // Endpoint CBOR : retourne la liste des livres au format CBOR (réactif)
    @GetMapping(value = "/cbor", produces = "application/cbor")
    public Flux<Book> getBooksCbor() {
        return repo.findAll();
    }
}
