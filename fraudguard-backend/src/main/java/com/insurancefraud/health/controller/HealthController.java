
package com.insurancefraud.health.controller;

import com.insurancefraud.common.payload.ApiResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;

@Slf4j
@RestController
@RequestMapping("/api/v1/health")
public class HealthController {

    @GetMapping
    public ResponseEntity<ApiResponse<String>> health() {
        ApiResponse<String> response = new ApiResponse<>(
                true,
                "FraudGuard backend is running!",
                200,
                Instant.now(),
                "OK"
        );
        return ResponseEntity.ok(response);
    }
}