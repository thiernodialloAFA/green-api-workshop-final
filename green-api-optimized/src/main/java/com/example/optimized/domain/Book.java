package com.example.optimized.domain;

import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Table;
import java.time.Instant;

@Table("book")
@Data
public class Book {
    @Id
    private Long id;
    private String title;
    private String author;
    private Integer yea;
    private Integer pages;
    private String summary;
    private Instant lastModified;
    private Long version;

    public Book() {}

    public Book(Long id, String title, String author, int year, int pages, String summary, Instant lastModified, long version) {
        this.id = id;
        this.title = title;
        this.author = author;
        this.yea = year;
        this.pages = pages;
        this.summary = summary;
        this.lastModified = lastModified;
        this.version = version;
    }
}
