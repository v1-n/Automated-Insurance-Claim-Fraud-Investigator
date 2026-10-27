package com.insurancefraud.admin.dto;

import com.insurancefraud.enums.ClaimStatus;
import com.insurancefraud.enums.ClaimType;
import com.insurancefraud.enums.FraudStatus;
import com.insurancefraud.fraud.dto.AiAnalysisDto;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;

@Getter
@Setter
public class AdminClaimDetailResponseDto {

    private Long claimId;
    private String claimNumber;
    private ClaimType claimType;
    private BigDecimal claimAmount;
    private ClaimStatus claimStatus;
    private FraudStatus fraudStatus;
    private BigDecimal fraudScore;

    // AI Analysis Details
    private String aiStatus;
    private String aiRiskLevel;
    private String aiRecommendation;
    private String aiSummary;
    private AiAnalysisDto aiAnalysis;

    private String description;
    private Instant incidentDate;
    private String incidentAddress;
    private String incidentCity;
    private String incidentState;

    private String reviewNotes;
    private String decisionNotes;

    private String customerName;
    private String customerEmail;
    private String investigatorName;
    private String tenantCode;

    // Policy Information
    private String policyNumber;
    private String planName;
    private String vehicleNumber;
    private String vehicleMakeModel;
    private BigDecimal insuredDeclaredValue;
    private Instant policyStartDate;
    private Instant policyEndDate;
    private String policyStatus;

    private Instant createdAt;
    private Instant updatedAt;
}
