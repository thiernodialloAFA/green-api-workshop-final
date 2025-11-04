package com.example.optimized.repo;

import com.example.optimized.domain.Book;
import org.springframework.data.repository.reactive.ReactiveCrudRepository;
import org.springframework.stereotype.Repository;
import reactor.core.publisher.Flux;

import java.util.ArrayList;

@Repository
public interface BookReactiveRepository extends ReactiveCrudRepository<Book, Long> {
    // TODO : add custom queries
}

