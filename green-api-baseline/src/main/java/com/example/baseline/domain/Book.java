package com.example.baseline.domain;

public record Book(
    long id,
    String title,
    String author,
    int published_date,
    int pages,
    String summary
) {}
