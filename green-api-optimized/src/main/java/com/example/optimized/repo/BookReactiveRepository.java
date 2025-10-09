package com.example.optimized.repo;

import com.example.optimized.domain.Book;
import org.springframework.data.repository.reactive.ReactiveCrudRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface BookReactiveRepository extends ReactiveCrudRepository<Book, Long> {
    // Tu peux ajouter ici des méthodes réactives personnalisées si besoin
}

