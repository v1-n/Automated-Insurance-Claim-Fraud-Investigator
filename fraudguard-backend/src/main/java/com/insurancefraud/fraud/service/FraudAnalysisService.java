package com.insurancefraud.fraud.service;

import com.insurancefraud.fraud.dto.AnalyzeClaimResponseDto;

public interface FraudAnalysisService {

    AnalyzeClaimResponseDto analyzeClaimAsync(Long claimId);

    AnalyzeClaimResponseDto analyzeClaimAsync(Long claimId, Long outboxEventId, String triggerType);
}
