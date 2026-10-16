package com.insurancefraud.investigator.dto;

import com.insurancefraud.enums.ClaimStatus;
import com.insurancefraud.enums.FraudStatus;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@AllArgsConstructor
public class InvestigatorClaimReviewResponseDto {

    private Long claimId;
    private String claimNumber;
    private ClaimStatus claimStatus;
    private FraudStatus fraudStatus;
    private String reviewNotes;
    private String investigatorName;
    private Instant updatedAt;
}