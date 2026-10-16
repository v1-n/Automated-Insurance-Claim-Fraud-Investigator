package com.insurancefraud.admin.dto;

import com.insurancefraud.enums.ClaimStatus;
import com.insurancefraud.enums.FraudStatus;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@AllArgsConstructor
public class ClaimDecisionResponseDto {
    private Long claimId;
    private String decisionNotes;
    private ClaimStatus claimStatus;
    private String claimNumber;
    private FraudStatus fraudStatus;
    private String decidedBy;
    private Instant updatedAt;
}
