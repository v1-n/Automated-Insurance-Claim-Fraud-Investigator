package com.insurancefraud.fraud.dto;

import java.util.List;

public record AiFlagDto(
        String code,
        String category,
        String severity,
        String explanation,
        List<String> benignExplanations,
        List<String> nextSteps,
        Double confidence
) {}
