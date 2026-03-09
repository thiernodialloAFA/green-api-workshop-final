package com.example.baseline.repo;

import com.example.baseline.domain.Book;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.LongStream;

@Repository
public class BookRepository {
    private final List<Book> data;

    public BookRepository(@Value("${app.dataset.size:1000000}") int size) {
        data = new ArrayList<>();
        int safeSize = Math.max(1, size);
        LongStream.rangeClosed(1, safeSize).forEach(i ->
            data.add(new Book(
                i,
                "Title " + i,
                "Author " + ((i % 20) + 1),
                1990 + (int)(i % 30),
                100 + (int)(i % 400),
                "Long summary to inflate payload " + "x".repeat(2)
            ))
        );
    }

    public List<Book> findAll() { return data; }
    public Book findById(long id) { return data.stream().filter(b -> b.id()==id).findFirst().orElse(null); }
}
