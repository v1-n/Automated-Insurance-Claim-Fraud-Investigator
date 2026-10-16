package com.insurancefraud.policy.dto;

import com.insurancefraud.enums.PolicyType;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
public class PolicyPlanRequestDto {

    @NotBlank(message = "Plan name is required")
    private String planName;

    @NotNull(message = "Policy type is required")
    private PolicyType policyType;

    @NotNull(message = "Maximum IDV coverage is required")
    @DecimalMin(value = "1.0", message = "IDV coverage must be greater than 0")
    private BigDecimal maxIdvCoverage;

    @NotNull(message = "Annual premium is required")
    @DecimalMin(value = "1.0", message = "Annual premium must be greater than 0")
    private BigDecimal annualPremium;

    private String description;
}
