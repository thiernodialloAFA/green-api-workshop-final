package com.example.optimized.domain;

import java.time.Instant;

public record Book(
    long id,
    String title,
    String author,
    int year,
    int pages,
    String summary,
    Instant lastModified,
    long version
) {}
