package com.example.optimized.service;

import com.example.optimized.domain.Book;
import com.example.optimized.repo.BookRepository;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class BookService {
    private final BookRepository repo;

    public BookService(BookRepository repo) {
        this.repo = repo;
    }

    public List<Book> findAllCached() {
        return repo.findAll();
    }
}

