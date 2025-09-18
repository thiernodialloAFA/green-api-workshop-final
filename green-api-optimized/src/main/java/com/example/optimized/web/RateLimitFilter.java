package com.example.optimized.web;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class RateLimitFilter extends OncePerRequestFilter {
    static class Bucket { int tokens; long windowStart; }
    private final Map<String, Bucket> buckets = new ConcurrentHashMap<>();
    private final int capacity = 30; // tokens
    private final long windowMs = 10_000; // 10s

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
        throws ServletException, IOException {
        String key = request.getRemoteAddr();
        long now = Instant.now().toEpochMilli();
        Bucket b = buckets.computeIfAbsent(key, k -> { var x = new Bucket(); x.tokens = capacity; x.windowStart = now; return x; });
        synchronized (b) {
            if (now - b.windowStart > windowMs) { b.tokens = capacity; b.windowStart = now; }
            if (b.tokens <= 0) {
                response.setStatus(429);
                response.setHeader("Retry-After", "5");
                response.getWriter().write("Rate limit exceeded ");
                return;
            }
            b.tokens--;
        }
        filterChain.doFilter(request, response);
    }
}
