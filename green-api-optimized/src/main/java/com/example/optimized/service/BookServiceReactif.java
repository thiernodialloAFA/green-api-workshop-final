package com.example.optimized.service;

import com.example.optimized.domain.Book;
import com.example.optimized.repo.BookReactiveRepository;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class BookServiceReactif {
    private final BookReactiveRepository repo;

    public BookServiceReactif(BookReactiveRepository repo) {
        this.repo = repo;
    }

    // Cache la LISTE complète des livres sous le cache "books" (valeur concrète)
    @Cacheable(cacheNames = "books")
    public List<Book> findAllCachedList() {
        return repo.findAll().collectList().block();
    }
}

