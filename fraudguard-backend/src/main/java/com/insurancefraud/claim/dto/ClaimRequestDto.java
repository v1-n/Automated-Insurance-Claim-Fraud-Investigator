package com.insurancefraud.claim.dto;

import com.insurancefraud.enums.ClaimType;
import jakarta.validation.constraints.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;

@Getter
@Setter
public class ClaimRequestDto {

    @NotNull(message = "Claim type is required")
    private ClaimType claimType;

    @NotNull(message = "Claim amount is required")
    @DecimalMin(
            value = "1.0",
            message = "Claim amount must be greater than 0"
    )
    private BigDecimal claimAmount;

    @NotBlank(message = "Description is required")
    @Size(
            min = 10,
            max = 1000,
            message = "Description must be between 10 and 1000 characters"
    )
    private String description;

    @NotNull(message = "Incident date is required")
    private Instant incidentDate;

    @NotBlank(message = "Incident address is required")
    @Size(max = 500)
    private String incidentAddress;

    @NotBlank(message = "Incident city is required")
    @Size(max = 100)
    private String incidentCity;

    @NotBlank(message = "Incident state is required")
    @Size(max = 100)
    private String incidentState;
}