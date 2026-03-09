package com.example.baseline.database.api;

import com.example.baseline.database.domain.Book;
import com.example.baseline.database.repo.BookRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.cache.annotation.Cacheable;
import java.util.List;
import java.util.Optional;


@RestController
@RequestMapping("/books")
public class BookController {
    private final BookRepository repo;
    public BookController(BookRepository repo) { this.repo = repo; }

    @GetMapping
    public List<Book> all() { return repo.findAll().stream().toList(); }

    @Cacheable("books")
    @GetMapping("/cacheable")
    public List<Book> allWithCache() { return repo.findAll().stream().toList(); }

    @GetMapping("/{id}")
    public Optional<Book> byId(@PathVariable("id") long id) { return repo.findById(id); }

}