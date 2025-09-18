package com.example.baseline.api;

import com.example.baseline.domain.Book;
import com.example.baseline.repo.BookRepository;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/books")
public class BookController {
    private final BookRepository repo;
    public BookController(BookRepository repo) { this.repo = repo; }

    @GetMapping
    public List<Book> all() { return repo.findAll(); }

    @GetMapping("/{id}")
    public Book byId(@PathVariable("id") long id) { return repo.findById(id); }
}
