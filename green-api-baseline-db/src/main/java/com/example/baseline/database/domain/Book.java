package com.example.baseline.database.domain;
import jakarta.persistence.Id;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Data;
import java.time.Instant;

@Entity
@Data
@Table(name = "book")
public class Book {
    @Id
    private Long id;
    private String title;
    private String author;
    private Integer published_date;
    private Integer pages;
    private String summary;
    private Instant lastModified;
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
