package com.example.optimized.repo;

import com.example.optimized.domain.Book;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.LongStream;

@Repository
public class BookRepository {
    private final Map<Long, Book> data = new ConcurrentHashMap<>();
    private final AtomicLong version = new AtomicLong(0);

    public BookRepository() {
        LongStream.rangeClosed(1, 500000).forEach(i -> {
            var b = new Book(
                i,
                "Title " + i,
                "Author " + ((i % 20) + 1),
                1990 + (int)(i % 30),
                100 + (int)(i % 400),
                "Long summary to inflate payload " + "x".repeat(2),
                Instant.now(),
                version.incrementAndGet()
            );
            data.put(i, b);
        });
    }

    public List<Book> findAll() { return new ArrayList<>(data.values()); }

    public Optional<Book> findById(long id) { return Optional.ofNullable(data.get(id)); }

    public List<Book> findChangesSince(Instant since) {
        return data.values().stream()
            .filter(b -> b.getLastModified().isAfter(since))
            .sorted(Comparator.comparing(Book::getLastModified))
            .toList();
    }

    public Book updateSummary(long id, String newSummary) {
        var now = Instant.now();
        var ver = version.incrementAndGet();
        var old = data.get(id);
        if (old == null) return null;
        var updated = new Book(old.getId(), old.getTitle(), old.getAuthor(), old.getPublished_date(), old.getPages(), newSummary, now, ver);
        data.put(id, updated);
        return updated;
    }

    public Book updateBook(long id, Book updatedBook) {
        var old = data.get(id);
        if (old == null) return null;
        var now = Instant.now();
        var ver = version.incrementAndGet();
        var book = new Book(
                id,
                updatedBook.getTitle(),
                updatedBook.getAuthor(),
                updatedBook.getPublished_date(),
                updatedBook.getPages(),
                updatedBook.getSummary(),
                now,
                ver
        );
        data.put(id, book);
        return book;
    }


}
