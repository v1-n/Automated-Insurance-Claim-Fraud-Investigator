package com.insurancefraud.admin.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class ClaimDecisionRequestDto {

    @NotNull(message = "decision notes is required")
    private String decisionNotes;
}
