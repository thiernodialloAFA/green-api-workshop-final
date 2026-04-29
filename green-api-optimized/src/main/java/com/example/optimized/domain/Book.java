package com.example.optimized.domain;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Table;
import java.time.Instant;

@Table("book")
@Data
@Schema(description = "Book resource", example = "{\n" +
    "  \"id\": 1,\n" +
    "  \"title\": \"Book 1\",\n" +
    "  \"author\": \"Author 1\",\n" +
    "  \"published_date\": 1921,\n" +
    "  \"pages\": 101,\n" +
    "  \"summary\": \"Auto-generated book 1.\",\n" +
    "  \"lastModified\": \"2025-01-01T12:00:00Z\",\n" +
    "  \"version\": 1\n" +
    "}")
public class Book {
    @Id
    @Schema(description = "Unique identifier of the book", example = "1")
    private Long id;
    @Schema(description = "Title of the book", example = "Book 1")
    private String title;
    @Schema(description = "Author of the book", example = "Author 1")
    private String author;
    @Schema(description = "Year the book was published", example = "1921")
    private Integer published_date;
    @Schema(description = "Number of pages", example = "101")
    private Integer pages;
    @Schema(description = "Summary of the book", example = "Auto-generated book 1.")
    private String summary;
    @Schema(description = "Last modification timestamp (ISO-8601)", example = "2025-01-01T12:00:00Z")
    private Instant lastModified;
    @Schema(description = "Optimistic locking version, used for ETag", example = "1")
    private Long version;

    public Book() {}

    public Book(Long id, String title, String author, int published_date, int pages, String summary, Instant lastModified, long version) {
        this.id = id;
        this.title = title;
        this.author = author;
        this.published_date = published_date;
        this.pages = pages;
        this.summary = summary;
        this.lastModified = lastModified;
        this.version = version;
    }
}
