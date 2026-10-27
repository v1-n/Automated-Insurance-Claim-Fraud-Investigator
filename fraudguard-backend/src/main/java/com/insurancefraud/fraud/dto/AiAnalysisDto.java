package com.insurancefraud.fraud.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

public record AiAnalysisDto(
        String status,
        BigDecimal riskScore,
        String riskLevel,
        String recommendation,
        String summary,
        Instant analyzedAt,
        List<AiFlagDto> flags
) {}
