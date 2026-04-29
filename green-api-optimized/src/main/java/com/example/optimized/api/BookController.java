package com.example.optimized.api;

import com.example.optimized.domain.Book;
import com.example.optimized.repo.BookRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
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

    // ---- OpenAPI example payloads (visible directly in Swagger UI) ----
    static final String EX_BOOK = "{\n" +
        "  \"id\": 1,\n" +
        "  \"title\": \"Book 1\",\n" +
        "  \"author\": \"Author 1\",\n" +
        "  \"published_date\": 1921,\n" +
        "  \"pages\": 101,\n" +
        "  \"summary\": \"Auto-generated book 1.\",\n" +
        "  \"lastModified\": \"2025-01-01T12:00:00Z\",\n" +
        "  \"version\": 1\n" +
        "}";
    static final String EX_BOOK_LIST = "[\n" +
        "  {\n" +
        "    \"id\": 1, \"title\": \"Book 1\", \"author\": \"Author 1\",\n" +
        "    \"published_date\": 1921, \"pages\": 101,\n" +
        "    \"summary\": \"Auto-generated book 1.\",\n" +
        "    \"lastModified\": \"2025-01-01T12:00:00Z\", \"version\": 1\n" +
        "  },\n" +
        "  {\n" +
        "    \"id\": 2, \"title\": \"Book 2\", \"author\": \"Author 2\",\n" +
        "    \"published_date\": 1922, \"pages\": 202,\n" +
        "    \"summary\": \"Auto-generated book 2.\",\n" +
        "    \"lastModified\": \"2025-01-02T12:00:00Z\", \"version\": 1\n" +
        "  }\n" +
        "]";
    static final String EX_BOOK_SELECT = "[\n" +
        "  { \"id\": 1, \"title\": \"Book 1\", \"author\": \"Author 1\" },\n" +
        "  { \"id\": 2, \"title\": \"Book 2\", \"author\": \"Author 2\" }\n" +
        "]";
    static final String EX_SUMMARY_TEXT = "Auto-generated book 1.";

    // Full list (non-paginé — pour comparaison avec baseline)
    @Operation(summary = "List all books (non-paginated baseline)")
    @ApiResponses(@ApiResponse(responseCode = "200", description = "All books",
        content = @Content(mediaType = "application/json",
            examples = @ExampleObject(name = "books", value = EX_BOOK_LIST))))
    @GetMapping
    public List<Book> all() { return repo.findAll(); }

    // Ressource unitaire sans cache (pour comparaison)
    @Operation(summary = "Get a book by id (no cache)")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Book found",
            content = @Content(mediaType = "application/json",
                examples = @ExampleObject(name = "book", value = EX_BOOK))),
        @ApiResponse(responseCode = "404", description = "Book not found", content = @Content)
    })
    @GetMapping("noCache/{id}")
    public ResponseEntity<Book> byId(@PathVariable("id") @Parameter(description = "Book identifier", example = "1") long id) {
        return repo.findById(id)
            .map(ResponseEntity::ok)
            .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND).build());
    }

    // DE11 — Pagination simple (size borné ≤ 100)
    private static final int MAX_PAGE_SIZE = 100;

    @Operation(summary = "List books with pagination (DE11)")
    @ApiResponses(@ApiResponse(responseCode = "200", description = "Page of books",
        content = @Content(mediaType = "application/json",
            examples = @ExampleObject(name = "page", value = EX_BOOK_LIST))))
    @GetMapping(params = {"page","size"})
    public List<Book> page(
        @RequestParam("page") @Min(0) @Parameter(description = "Zero-based page index", example = "0") int page,
        @RequestParam("size") @Min(1) @Max(MAX_PAGE_SIZE) @Parameter(description = "Page size (max 100)", example = "20") int size
    ){
        size = Math.max(1, Math.min(size, MAX_PAGE_SIZE)); // Borne DE11
        var all = repo.findAll();
        int from = Math.max(0, Math.min(page * size, all.size()));
        int to   = Math.max(from, Math.min(from + size, all.size()));
        return all.subList(from, to);
    }

    // Batching — réduire N appels en 1 (AR02)
    @Operation(summary = "Batch fetch books by ids (AR02)")
    @ApiResponses(@ApiResponse(responseCode = "200", description = "Books found for the requested ids",
        content = @Content(mediaType = "application/json",
            examples = @ExampleObject(name = "batch", value = EX_BOOK_LIST))))
    @GetMapping("/batch")
    public List<Book> batch(@RequestParam("ids") @Size(min = 1, max = MAX_PAGE_SIZE) @Parameter(description = "Comma-separated list of book ids (1..100)", example = "1,2,3") List<Long> ids) {
        return ids.stream()
            .limit(MAX_PAGE_SIZE)
            .map(repo::findById)
            .flatMap(Optional::stream)
            .toList();
    }


    // DE08/US01 — Filtrage de champs (whitelist, summary exclu par défaut)
    @Operation(summary = "List books with field selection (DE08/US01)")
    @ApiResponses(@ApiResponse(responseCode = "200", description = "Books with only the selected fields",
        content = @Content(mediaType = "application/json",
            examples = @ExampleObject(name = "select", value = EX_BOOK_SELECT))))
    @GetMapping(value = "/select")
    public List<Map<String, Object>> select(
        @RequestParam(name = "fields", defaultValue = "id,title,author") @Parameter(description = "Whitelisted comma-separated fields (id,title,author,published_date,pages,summary)", example = "id,title,author") String fields,
        @RequestParam(name = "page", defaultValue = "0") @Min(0) @Parameter(description = "Zero-based page index", example = "0") int page,
        @RequestParam(name = "size", defaultValue = "20") @Min(1) @Max(MAX_PAGE_SIZE) @Parameter(description = "Page size (max 100)", example = "20") int size
    ){
        var wanted = FieldSelector.parse(fields);
        var slice = page(page, size);
        return slice.stream().map(b -> {
                    var m = new LinkedHashMap<String, Object>();
                    if (wanted.contains("id")) m.put("id", b.getId());
                    if (wanted.contains("title")) m.put("title", b.getTitle());
                    if (wanted.contains("author")) m.put("author", b.getAuthor());
                    if (wanted.contains("published_date")) m.put("published_date", b.getPublished_date());
                    if (wanted.contains("pages")) m.put("pages", b.getPages());
                    if (wanted.contains("summary")) m.put("summary", b.getSummary());
                    return (Map<String, Object>) m;
                }
        ).toList();
    }

    // Ressource unitaire avec ETag + Last-Modified
    @Operation(summary = "Get a book by id with ETag/Last-Modified (DE02/DE03)")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Book found",
            content = @Content(mediaType = "application/json",
                examples = @ExampleObject(name = "book", value = EX_BOOK))),
        @ApiResponse(responseCode = "304", description = "Not Modified (conditional GET)", content = @Content),
        @ApiResponse(responseCode = "404", description = "Book not found", content = @Content)
    })
    @GetMapping("/{id}")
    public ResponseEntity<Book> byId(
        @PathVariable("id") @Parameter(description = "Book identifier", example = "1") long id,
        @RequestHeader(value = "If-None-Match", required = false) @Parameter(description = "Conditional GET ETag", example = "\"1\"") String inm,
        @RequestHeader(value = "If-Modified-Since", required = false) @Parameter(description = "Conditional GET timestamp (RFC 1123)", example = "Wed, 01 Jan 2025 12:00:00 GMT") String ims
    ){
        var opt = repo.findById(id);
        if (opt.isEmpty()) return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        var b = opt.get();
        return getBookResponseEntity(inm, ims, b);
    }

    // Résumé avec support Range 206
    @Operation(summary = "Get book summary, supports Range requests (206 Partial Content)")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Full summary text",
            content = @Content(mediaType = "text/plain",
                examples = @ExampleObject(name = "summary", value = EX_SUMMARY_TEXT))),
        @ApiResponse(responseCode = "206", description = "Partial summary (Range satisfied)",
            content = @Content(mediaType = "text/plain",
                examples = @ExampleObject(name = "partial", value = "Auto-gener"))),
        @ApiResponse(responseCode = "404", description = "Book not found", content = @Content)
    })
    @GetMapping("/{id}/summary")
    public ResponseEntity<byte[]> summaryRange(
        @PathVariable("id") @Parameter(description = "Book identifier", example = "1") long id,
        @RequestHeader(value = "Range", required = false) @Parameter(description = "Byte range, e.g. bytes=0-9", example = "bytes=0-9") String range
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
    @Operation(summary = "List books changed since a given timestamp (DE06)")
    @ApiResponses(@ApiResponse(responseCode = "200", description = "Books modified after the given instant",
        content = @Content(mediaType = "application/json",
            examples = @ExampleObject(name = "changes", value = EX_BOOK_LIST))))
    @GetMapping("/changes")
    public ResponseEntity<List<Book>> changes(
      @RequestParam("since") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) @Parameter(description = "ISO-8601 timestamp; only books modified after this instant are returned", example = "2025-01-01T00:00:00Z") Instant since
    ){
        var list = repo.findChangesSince(since);
        return ResponseEntity.ok()
            .cacheControl(CacheControl.noCache())
            .body(list);
    }

    // Update de démo pour générer des deltas
    @Operation(summary = "Update only the summary field of a book")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Updated book",
            content = @Content(mediaType = "application/json",
                examples = @ExampleObject(name = "updated", value = EX_BOOK))),
        @ApiResponse(responseCode = "404", description = "Book not found", content = @Content)
    })
    @PostMapping("/{id}/summary")
    public ResponseEntity<Book> updateSummary(
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
        var updated = repo.updateSummary(id, body.getOrDefault("summary", ""));
        if (updated == null) return ResponseEntity.notFound().build();
        return ResponseEntity.ok(updated);
    }

    // Endpoint CBOR : retourne la liste des livres au format CBOR si demandé
    @Operation(summary = "List books encoded as CBOR (AR02 binary format)")
    @ApiResponses(@ApiResponse(responseCode = "200", description = "Books in CBOR binary format (decoded preview shown as JSON)",
        content = @Content(mediaType = "application/cbor",
            examples = @ExampleObject(name = "cborDecodedPreview", value = EX_BOOK_LIST))))
    @GetMapping(value = "/cbor", produces = "application/cbor")
    public ResponseEntity<List<Book>> getBooksCbor() {
        var all = repo.findAll();
        return ResponseEntity.ok().body(all);
    }

    // Endpoint asynchrone : liste des livres
    @Operation(summary = "List books asynchronously (CompletableFuture)")
    @ApiResponses(@ApiResponse(responseCode = "200", description = "All books (async)",
        content = @Content(mediaType = "application/json",
            examples = @ExampleObject(name = "books", value = EX_BOOK_LIST))))
    @Async
    @GetMapping("/async")
    public CompletableFuture<List<Book>> getBooksAsync() {
        return CompletableFuture.supplyAsync(() -> repo.findAll());
    }

    // Endpoint asynchrone : livre par ID
    @Operation(summary = "Get a book by id asynchronously")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Book found (async)",
            content = @Content(mediaType = "application/json",
                examples = @ExampleObject(name = "book", value = EX_BOOK))),
        @ApiResponse(responseCode = "404", description = "Book not found", content = @Content)
    })
    @Async
    @GetMapping("/async/{id}")
    public CompletableFuture<ResponseEntity<Book>> getBookByIdAsync(@PathVariable("id") @Parameter(description = "Book identifier", example = "1") long id) {
        return CompletableFuture.supplyAsync(() -> {
            var opt = repo.findById(id);
            return opt.map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.notFound().build());
        });
    }

    @Operation(summary = "Replace an existing book (full update)")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Book replaced",
            content = @Content(mediaType = "application/json",
                examples = @ExampleObject(name = "updated", value = EX_BOOK))),
        @ApiResponse(responseCode = "404", description = "Book not found", content = @Content)
    })
    @PutMapping("/{id}")
    public ResponseEntity<Book> updateBook(
            @PathVariable("id") @Parameter(description = "Book identifier", example = "1") long id,
            @io.swagger.v3.oas.annotations.parameters.RequestBody(
                description = "Full book payload to replace the existing resource",
                required = true,
                content = @Content(
                    mediaType = "application/json",
                    examples = @ExampleObject(name = "bookUpdate", value = "{\n" +
                        "  \"id\": 1,\n" +
                        "  \"title\": \"Updated Book Title\",\n" +
                        "  \"author\": \"Updated Author\",\n" +
                        "  \"published_date\": 2024,\n" +
                        "  \"pages\": 250,\n" +
                        "  \"summary\": \"Updated summary describing the book.\",\n" +
                        "  \"lastModified\": \"2025-01-01T12:00:00Z\",\n" +
                        "  \"version\": 2\n" +
                        "}")
                )
            )
            @RequestBody Book updatedBook
    ) {
        Book book = repo.updateBook(id, updatedBook);
        if (book == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(book);
    }
}
