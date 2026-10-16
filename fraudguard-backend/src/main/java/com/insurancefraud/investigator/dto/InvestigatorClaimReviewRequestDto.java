package com.insurancefraud.investigator.dto;

import com.insurancefraud.enums.FraudStatus;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class InvestigatorClaimReviewRequestDto {
    @NotNull(message = "Review notes is required")
    private String reviewNotes;
    @NotNull(message = "Fraud status is required")
    private FraudStatus fraudStatus;

}
