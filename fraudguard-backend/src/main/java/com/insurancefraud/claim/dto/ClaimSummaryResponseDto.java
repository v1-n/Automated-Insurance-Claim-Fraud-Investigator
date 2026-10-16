package com.insurancefraud.claim.dto;

import com.insurancefraud.enums.ClaimStatus;
import com.insurancefraud.enums.ClaimType;
import com.insurancefraud.enums.FraudStatus;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDateTime;

@Getter
@Setter

public class ClaimSummaryResponseDto {

    private Long claimId;

    private String claimNumber;
    private String customerName;

    private String customerEmail;

    private String investigatorName;
    private ClaimType claimType;

    private BigDecimal claimAmount;

    private ClaimStatus claimStatus;

    private FraudStatus fraudStatus;

    private Instant incidentDate;

    private String incidentCity;

    private String decisionNotes;

    private Instant createdAt;
}