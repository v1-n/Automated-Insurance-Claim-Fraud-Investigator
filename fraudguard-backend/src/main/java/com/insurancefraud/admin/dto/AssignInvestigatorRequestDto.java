package com.insurancefraud.admin.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class AssignInvestigatorRequestDto {

    @NotNull(message = "Investigator ID is required")
    private Long investigatorId;
}