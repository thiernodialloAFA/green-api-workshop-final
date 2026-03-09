package com.example.optimized.api;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.stream.Collectors;

public final class FieldSelector {
    private static final Set<String> ALLOWED_FIELDS = Set.of(
        "id", "title", "author", "year", "pages", "summary"
    );

    private static final Set<String> DEFAULT_FIELDS = Set.of("id", "title", "author");

    private FieldSelector() {}

    public static LinkedHashSet<String> parse(String fields) {
        if (fields == null || fields.isBlank()) {
            return new LinkedHashSet<>(DEFAULT_FIELDS);
        }
        var wanted = Arrays.stream(fields.split(","))
            .map(String::trim)
            .filter(s -> !s.isEmpty())
            .map(String::toLowerCase)
            .collect(Collectors.toCollection(LinkedHashSet::new));

        if (wanted.isEmpty()) {
            return new LinkedHashSet<>(DEFAULT_FIELDS);
        }

        var unknown = wanted.stream()
            .filter(f -> !ALLOWED_FIELDS.contains(f))
            .toList();

        if (!unknown.isEmpty()) {
            throw new ResponseStatusException(
                HttpStatus.BAD_REQUEST,
                "Invalid fields: " + String.join(",", unknown)
            );
        }
        return wanted;
    }
}

