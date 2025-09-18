package com.example.baseline.domain;

public record Book(
    long id,
    String title,
    String author,
    int year,
    int pages,
    String summary
) {}
