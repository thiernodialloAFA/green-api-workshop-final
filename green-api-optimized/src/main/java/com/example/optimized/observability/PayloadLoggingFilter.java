package com.example.optimized.observability;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingResponseWrapper;

import java.io.IOException;

@Component
@Slf4j
public class PayloadLoggingFilter extends OncePerRequestFilter {
    @Override protected void doFilterInternal(
        HttpServletRequest request,
        jakarta.servlet.http.HttpServletResponse response,
        FilterChain chain) throws ServletException, IOException {

        var wrapper = new ContentCachingResponseWrapper(response);
        long start = System.nanoTime();
        try {
            chain.doFilter(request, wrapper);
        } finally {
            wrapper.copyBodyToResponse();
            int status = wrapper.getStatus();
            int size = wrapper.getContentSize();
            long ms = (System.nanoTime() - start)/1_000_000;
            log.info("method={} path={} status={} bytes={} timeMs={}",
                request.getMethod(), request.getRequestURI(), status, size, ms);
        }
    }
}
