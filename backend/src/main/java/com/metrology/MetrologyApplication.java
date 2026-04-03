package com.metrology;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class MetrologyApplication {
    public static void main(String[] args) {
        SpringApplication.run(MetrologyApplication.class, args);
    }
}
