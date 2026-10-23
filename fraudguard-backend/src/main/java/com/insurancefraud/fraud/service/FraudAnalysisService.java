package com.insurancefraud.fraud.service;


import com.insurancefraud.fraud.dto.AnalyzeClaimResponseDto;

public interface FraudAnalysisService {
   AnalyzeClaimResponseDto analyzeClaimAsync(Long claimId);
}
