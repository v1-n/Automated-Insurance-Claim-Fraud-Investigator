package com.insurancefraud;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@EnableScheduling
@SpringBootApplication
public class FraudGuardBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(FraudGuardBackendApplication.class, args);
    }

}
