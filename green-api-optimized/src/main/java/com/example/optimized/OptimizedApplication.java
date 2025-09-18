package com.example.optimized;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class OptimizedApplication {
  public static void main(String[] args) {
    SpringApplication.run(OptimizedApplication.class, args);
  }
}
