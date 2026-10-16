package com.insurancefraud.investigator.dto;

import com.insurancefraud.enums.ClaimStatus;
import com.insurancefraud.enums.ClaimType;
import com.insurancefraud.enums.FraudStatus;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;

@Setter
@Getter
@AllArgsConstructor
public class InvestigatorClaimResponseDto {
        private Long claimId;
        private String claimNumber;
        private ClaimType claimType;
        private BigDecimal claimAmount;
        private ClaimStatus claimStatus;
        private FraudStatus fraudStatus;
        private Instant createdAt;
        private Instant incidentDate;
        private String incidentCity;
        private String customerName;
}
