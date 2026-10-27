package com.insurancefraud.admin.dto;

import com.insurancefraud.enums.ClaimStatus;
import com.insurancefraud.enums.ClaimType;
import com.insurancefraud.enums.FraudStatus;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class AdminClaimSummaryResponseDto {

    private Long claimId;
    private String claimNumber;
    private String customerName;
    private String customerEmail;
    private String investigatorName;
    private ClaimType claimType;
    private BigDecimal claimAmount;
    private ClaimStatus claimStatus;
    private FraudStatus fraudStatus;
    private BigDecimal fraudScore;
    private String aiRiskLevel;
    private Instant incidentDate;
    private String incidentCity;
    private String decisionNotes;
    private Instant createdAt;
}
